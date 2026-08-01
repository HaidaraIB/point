import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/Utils/app_theme_extension.dart';

/// Opens a Publish-style multi-select bottom sheet. Returns saved selection or null.
Future<List<String>?> showAppMultiFilterSheet({
  required BuildContext context,
  required String title,
  required List<String> items,
  required List<String> selected,
  required String Function(String) itemLabel,
}) {
  final temp = List<String>.from(selected);
  return showModalBottomSheet<List<String>>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setModalState) {
          final theme = context.appTheme;
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                height: MediaQuery.sizeOf(context).height * 0.65,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: theme.primaryText,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    Expanded(
                      child: items.isEmpty
                          ? Center(
                              child: Text(
                                'history.empty_data'.tr,
                                style: TextStyle(color: theme.mutedText),
                              ),
                            )
                          : ListView.builder(
                              itemCount: items.length,
                              itemBuilder: (context, index) {
                                final item = items[index];
                                final isSelected = temp.contains(item);
                                return InkWell(
                                  onTap: () {
                                    setModalState(() {
                                      if (isSelected) {
                                        temp.remove(item);
                                      } else {
                                        temp.add(item);
                                      }
                                    });
                                  },
                                  child: Container(
                                    margin: const EdgeInsets.all(5),
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(10),
                                      color:
                                          isSelected ? theme.unselected : null,
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            itemLabel(item),
                                            style: TextStyle(
                                              color: theme.secondaryText,
                                            ),
                                          ),
                                        ),
                                        if (isSelected)
                                          const Icon(
                                            Icons.check,
                                            color: Colors.green,
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                      ),
                      onPressed: () =>
                          Navigator.pop(context, List<String>.from(temp)),
                      child: Text(
                        'common.save'.tr,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

/// Chip that opens [showAppMultiFilterSheet] and shows a count badge when active.
class AppMultiFilterTrigger extends StatelessWidget {
  const AppMultiFilterTrigger({
    super.key,
    required this.hint,
    required this.items,
    required this.selected,
    required this.itemLabel,
    required this.onChanged,
  });

  final String hint;
  final List<String> items;
  final List<String> selected;
  final String Function(String) itemLabel;
  final void Function(List<String>) onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = resolveAppTheme();
    final active = selected.isNotEmpty;
    return Material(
      color: theme.inputFill,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: active
              ? AppColors.primary.withValues(alpha: 0.55)
              : theme.border,
        ),
      ),
      child: InkWell(
        onTap: () async {
          final result = await showAppMultiFilterSheet(
            context: context,
            title: hint,
            items: items,
            selected: selected,
            itemLabel: itemLabel,
          );
          if (result != null) onChanged(result);
        },
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          height: 40,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  hint,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: theme.primaryText,
                  ),
                ),
                if (active) ...[
                  const SizedBox(width: 8),
                  Container(
                    constraints: const BoxConstraints(minWidth: 20),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${selected.length}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: 2),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: theme.mutedText,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Removable active filter pill: `Dimension: value`.
class AppActiveFilterTag extends StatelessWidget {
  const AppActiveFilterTag({
    super.key,
    required this.dimension,
    required this.label,
    required this.onRemove,
  });

  final String dimension;
  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = resolveAppTheme();
    return Material(
      color: theme.cardSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: BorderSide(color: theme.border),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.only(start: 10, end: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$dimension: ',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: theme.secondaryText,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: theme.primaryText,
              ),
            ),
            InkWell(
              onTap: onRemove,
              borderRadius: BorderRadius.circular(999),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(
                  Icons.close_rounded,
                  size: 15,
                  color: theme.mutedText,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Appends [AppActiveFilterTag]s for each selected value into [out].
void appendAppActiveFilterTags({
  required List<Widget> out,
  required String dimension,
  required List<String> selected,
  required String Function(String) itemLabel,
  required void Function(String value) onRemove,
}) {
  for (final value in selected) {
    out.add(
      AppActiveFilterTag(
        dimension: dimension,
        label: itemLabel(value),
        onRemove: () => onRemove(value),
      ),
    );
  }
}

/// Date chip matching Publish filter styling (pick + clear).
class AppDateFilterChip extends StatelessWidget {
  const AppDateFilterChip({
    super.key,
    required this.hint,
    required this.value,
    required this.onPick,
    required this.onClear,
  });

  final String hint;
  final DateTime? value;
  final Future<void> Function() onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = resolveAppTheme();
    final hasValue = value != null;
    final label = hasValue ? DateFormat('yyyy-MM-dd').format(value!) : hint;
    return Material(
      color: theme.inputFill,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: hasValue
              ? AppColors.primary.withValues(alpha: 0.55)
              : theme.border,
        ),
      ),
      child: InkWell(
        onTap: () => unawaited(onPick()),
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          height: 40,
          child: Padding(
            padding: const EdgeInsetsDirectional.only(start: 10, end: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  size: 15,
                  color: theme.mutedText,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: hasValue ? theme.primaryText : theme.mutedText,
                  ),
                ),
                if (hasValue)
                  InkWell(
                    onTap: onClear,
                    borderRadius: BorderRadius.circular(999),
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: theme.mutedText,
                      ),
                    ),
                  )
                else
                  const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
