import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

DateTime _clampDateTimeToRange(DateTime d, DateTime first, DateTime last) {
  if (d.isBefore(first)) return first;
  if (d.isAfter(last)) return last;
  return d;
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Picks date (calendar) then time (Cupertino scroll wheel + hour/minute fields).
///
/// [initialDateTime] is clamped to [[firstDate], [lastDate]]. Canceling the time
/// step returns to the date step without completing the flow.
Future<DateTime?> pickAppDateTime(
  BuildContext context, {
  DateTime? initialDateTime,
  required DateTime firstDate,
  required DateTime lastDate,
}) async {
  final first = _dateOnly(firstDate);
  final last = _dateOnly(lastDate);
  var seed = initialDateTime ?? DateTime.now();
  seed = _clampDateTimeToRange(seed, first, last);

  var selectedCalendarDate = _dateOnly(seed);
  final initialWallTime = TimeOfDay(hour: seed.hour, minute: seed.minute);

  final picked = await showDialog<DateTime>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: SizedBox(
          height: 400,
          width: 350,
          child: CalendarDatePicker(
            initialDate: selectedCalendarDate,
            firstDate: first,
            lastDate: last,
            onDateChanged: (date) {
              selectedCalendarDate = _dateOnly(date);
            },
          ),
        ),
        actions: [
          _AppPickerDialogActionsRow(
            confirmLabel: 'common.confirm'.tr,
            cancelLabel: 'common.cancel'.tr,
            onConfirm: () async {
                final pickedTime = await showDialog<TimeOfDay>(
                  context: dialogContext,
                  builder: (timeContext) {
                    final timePanelKey = GlobalKey<_AppTimePickerPanelState>();
                    return AlertDialog(
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      content: SizedBox(
                        width: 320,
                        child: _AppTimePickerPanel(
                          key: timePanelKey,
                          initialTime: initialWallTime,
                        ),
                      ),
                      actions: [
                        _AppPickerDialogActionsRow(
                          confirmLabel: 'common.confirm'.tr,
                          cancelLabel: 'common.cancel'.tr,
                          onConfirm: () {
                            timePanelKey.currentState?.commitFieldEdits();
                            final tod =
                                timePanelKey.currentState?.currentTimeOfDay();
                            if (tod != null) {
                              Navigator.pop(timeContext, tod);
                            }
                          },
                          onCancel: () => Navigator.pop(timeContext),
                        ),
                      ],
                    );
                  },
                );

                if (pickedTime == null) return;

                final result = DateTime(
                  selectedCalendarDate.year,
                  selectedCalendarDate.month,
                  selectedCalendarDate.day,
                  pickedTime.hour,
                  pickedTime.minute,
                );
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext, result);
                }
              },
            onCancel: () => Navigator.pop(dialogContext),
          ),
        ],
      );
    },
  );

  return picked;
}

/// Single action row so [AlertDialog] does not stack wide [SizedBox] children vertically.
class _AppPickerDialogActionsRow extends StatelessWidget {
  const _AppPickerDialogActionsRow({
    required this.confirmLabel,
    required this.cancelLabel,
    required this.onConfirm,
    required this.onCancel,
  });

  final String confirmLabel;
  final String cancelLabel;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
            onPressed: onCancel,
            child: Text(cancelLabel),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
            onPressed: onConfirm,
            child: Text(
              confirmLabel,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

int _hour12From24Hour(int h24) {
  final m = h24 % 12;
  return m == 0 ? 12 : m;
}

/// [h12] is 1–12, [isPm] selects م/PM vs ص/AM.
int _to24From12Hour(int h12, bool isPm) {
  final h = h12.clamp(1, 12);
  if (isPm) {
    if (h == 12) return 12;
    return h + 12;
  }
  if (h == 12) return 0;
  return h;
}

class _AppTimePickerPanel extends StatefulWidget {
  const _AppTimePickerPanel({
    super.key,
    required this.initialTime,
  });

  final TimeOfDay initialTime;

  @override
  State<_AppTimePickerPanel> createState() => _AppTimePickerPanelState();
}

class _AppTimePickerPanelState extends State<_AppTimePickerPanel> {
  late int _hour;
  late int _minute;
  /// Tracks ص/AM vs م/PM for typed hour + segmented control (kept in sync with the wheel).
  late bool _isPm;
  late final TextEditingController _hourController;
  late final TextEditingController _minuteController;
  bool _updatingControllersFromWheel = false;

  /// Drives [ValueListenableBuilder] for the manual row + ص/م so they update while
  /// scrolling without calling [setState] on this panel (which would rebuild the wheel).
  final ValueNotifier<int> _wheelUiTick = ValueNotifier<int>(0);

  /// Bumped only when hour/minute are set from text fields so the wheel rebuilds
  /// to the new time. Must not change on every scroll tick (that recreates
  /// [CupertinoDatePicker] and triggers FixedExtentScrollController assertions on web).
  int _wheelResyncToken = 0;

  static final DateTime _wheelEpoch = DateTime(2000, 1, 1);

  @override
  void initState() {
    super.initState();
    _hour = widget.initialTime.hour.clamp(0, 23);
    _minute = widget.initialTime.minute.clamp(0, 59);
    _isPm = _hour >= 12;
    _hourController = TextEditingController(
      text: '${_hour12From24Hour(_hour)}',
    );
    _minuteController = TextEditingController(
      text: _minute.toString().padLeft(2, '0'),
    );
  }

  @override
  void dispose() {
    _wheelUiTick.dispose();
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
  }

  TimeOfDay currentTimeOfDay() => TimeOfDay(hour: _hour, minute: _minute);

  /// Applies typed hour/minute so Confirm works without leaving the fields.
  void commitFieldEdits() {
    _applyHourFromField();
    _applyMinuteFromField();
  }

  void _setControllersFromWheel() {
    _updatingControllersFromWheel = true;
    _isPm = _hour >= 12;
    _hourController.text = '${_hour12From24Hour(_hour)}';
    _minuteController.text = _minute.toString().padLeft(2, '0');
    _updatingControllersFromWheel = false;
  }

  void _onWheelChanged(DateTime dt) {
    // No setState on this State: rebuilding the column would rebuild
    // [CupertinoDatePicker] with a new [initialDateTime] and break the wheel on web.
    _hour = dt.hour;
    _minute = dt.minute;
    _isPm = _hour >= 12;
    _setControllersFromWheel();
    _wheelUiTick.value++;
  }

  void _onMeridiemChanged(bool isPm) {
    if (isPm == _isPm) return;
    final h12 = _hour12From24Hour(_hour);
    final newH = _to24From12Hour(h12, isPm);
    setState(() {
      _hour = newH;
      _isPm = isPm;
      _wheelResyncToken++;
    });
    _setControllersFromWheel();
  }

  void _applyHourFromField() {
    if (_updatingControllersFromWheel) return;
    final parsed = int.tryParse(_hourController.text.trim());
    if (parsed == null) return;
    final h12 = parsed.clamp(1, 12);
    final newH = _to24From12Hour(h12, _isPm);
    if (newH == _hour) {
      _hourController.text = '$h12';
      return;
    }
    setState(() {
      _hour = newH;
      _isPm = _hour >= 12;
      _wheelResyncToken++;
    });
    _hourController.text = '$h12';
  }

  void _applyMinuteFromField() {
    if (_updatingControllersFromWheel) return;
    final parsed = int.tryParse(_minuteController.text.trim());
    if (parsed == null) return;
    final m = parsed.clamp(0, 59);
    if (m == _minute) {
      _minuteController.text = m.toString().padLeft(2, '0');
      return;
    }
    setState(() {
      _minute = m;
      _wheelResyncToken++;
    });
    _minuteController.text = m.toString().padLeft(2, '0');
  }

  (String am, String pm) _meridiemLabels(BuildContext context) {
    final lang = Localizations.localeOf(context).languageCode;
    if (lang == 'ar') {
      return ('ص', 'م');
    }
    final mat = MaterialLocalizations.of(context);
    return (mat.anteMeridiemAbbreviation, mat.postMeridiemAbbreviation);
  }

  @override
  Widget build(BuildContext context) {
    final mer = _meridiemLabels(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 216,
          child: CupertinoTheme(
            data: const CupertinoThemeData(brightness: Brightness.light),
            child: CupertinoDatePicker(
              key: ValueKey<int>(_wheelResyncToken),
              mode: CupertinoDatePickerMode.time,
              use24hFormat: false,
              initialDateTime: _wheelEpoch
                  .add(Duration(hours: _hour, minutes: _minute)),
              onDateTimeChanged: _onWheelChanged,
            ),
          ),
        ),
        const SizedBox(height: 12),
        ValueListenableBuilder<int>(
          valueListenable: _wheelUiTick,
          builder: (context, _, __) {
            return FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.center,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 72,
                    child: TextField(
                      controller: _hourController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      maxLength: 2,
                      decoration: InputDecoration(
                        counterText: '',
                        labelText: MaterialLocalizations.of(context)
                            .timePickerHourLabel,
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      onEditingComplete: _applyHourFromField,
                      onSubmitted: (_) => _applyHourFromField(),
                    ),
                  ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Text(':', style: TextStyle(fontSize: 22)),
                ),
                SizedBox(
                  width: 72,
                  child: TextField(
                    controller: _minuteController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    maxLength: 2,
                    decoration: InputDecoration(
                      counterText: '',
                      labelText: MaterialLocalizations.of(context)
                          .timePickerMinuteLabel,
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    onEditingComplete: _applyMinuteFromField,
                    onSubmitted: (_) => _applyMinuteFromField(),
                  ),
                ),
                const SizedBox(width: 6),
                SegmentedButton<bool>(
                  showSelectedIcon: false,
                  style: SegmentedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  segments: [
                    ButtonSegment<bool>(
                      value: false,
                      label: Text(mer.$1, textAlign: TextAlign.center),
                    ),
                    ButtonSegment<bool>(
                      value: true,
                      label: Text(mer.$2, textAlign: TextAlign.center),
                    ),
                  ],
                  emptySelectionAllowed: false,
                  selected: {_isPm},
                  onSelectionChanged: (Set<bool> next) {
                    if (next.isEmpty) return;
                    _onMeridiemChanged(next.single);
                  },
                ),
              ],
            ),
            );
          },
        ),
      ],
    );
  }
}
