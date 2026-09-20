import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/Utils/app_theme_extension.dart';
import 'package:point/Utils/text_input_bidi.dart';
import 'package:point/View/Shared/responsive.dart';

/// Compact search field used by OS list filter bars.
class OsSearchField extends StatefulWidget {
  const OsSearchField({
    super.key,
    required this.controller,
    required this.hint,
    this.width = double.infinity,
    this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final double width;
  final ValueChanged<String>? onChanged;

  @override
  State<OsSearchField> createState() => _OsSearchFieldState();
}

class _OsSearchFieldState extends State<OsSearchField> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_rebuild);
  }

  @override
  void didUpdateWidget(covariant OsSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_rebuild);
      widget.controller.addListener(_rebuild);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    final textDirection = typedInputTextDirection(widget.controller.text);
    final hintTextDirection = typedInputHintTextDirection(widget.hint);
    final field = TextField(
      controller: widget.controller,
      onChanged: widget.onChanged,
      textDirection: textDirection,
      style: TextStyle(fontSize: 13, color: theme.primaryText),
      decoration: InputDecoration(
        hintText: widget.hint,
        hintTextDirection: hintTextDirection,
        hintMaxLines: 1,
        prefixIcon: Icon(Icons.search, size: 18, color: theme.mutedText),
        suffixIcon: widget.controller.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close, size: 16),
                onPressed: () {
                  widget.controller.clear();
                  widget.onChanged?.call('');
                },
              ),
        filled: true,
        fillColor: theme.inputFill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        isDense: true,
      ),
    );
    if (!widget.width.isFinite) return field;
    return SizedBox(width: widget.width, child: field);
  }
}

class OsFilterChipOption {
  const OsFilterChipOption({
    required this.value,
    required this.label,
    this.color,
  });

  final String value;
  final String label;
  final Color? color;
}

/// Horizontal ChoiceChip row (ALL + page options), same pattern as vouchers.
class OsFilterChips extends StatelessWidget {
  const OsFilterChips({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final List<OsFilterChipOption> options;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final opt in options)
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: Builder(
              builder: (context) {
                final selected = value == opt.value;
                final accent = opt.color ?? AppColors.primary;
                return FilterChip(
                  label: Text(
                    opt.label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                      color: selected ? Colors.white : theme.secondaryText,
                    ),
                  ),
                  selected: selected,
                  showCheckmark: false,
                  selectedColor: accent,
                  backgroundColor: theme.inputFill,
                  side: BorderSide(
                    color: selected ? accent : theme.border,
                    width: selected ? 1.5 : 1,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onSelected: (_) => onChanged(opt.value),
                );
              },
            ),
          ),
      ],
    );
  }
}

/// Filter bar layout:
/// 1) leading (context) + chips (filters) on one row; actions isolated at the end
/// 2) full-width search on the next row with optional inline match count
class OsListFilterBar extends StatelessWidget {
  const OsListFilterBar({
    super.key,
    this.leading,
    this.chips,
    this.search,
    this.actions = const [],
    this.matchCount,
    this.dense = false,
    this.stacked,
  });

  final Widget? leading;
  final Widget? chips;
  final Widget? search;
  final List<Widget> actions;
  final int? matchCount;

  /// Tighter horizontal padding for mobile OS pages.
  final bool dense;

  /// Vertical layout: actions, chips, then search (avoids overlap on narrow widths).
  /// Defaults to true when [dense] is true and width is below the mobile breakpoint.
  final bool? stacked;

  Widget _divider(AppThemeExtension theme) {
    return Container(
      width: 1,
      height: 28,
      margin: const EdgeInsetsDirectional.symmetric(horizontal: 12),
      color: theme.border,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    final useStacked =
        stacked ?? (dense && Responsive.isMobile(context));
    final hasTopRow = leading != null || chips != null || actions.isNotEmpty;
    final hasSearchRow = search != null || matchCount != null;

    Widget? topRow;
    if (hasTopRow && useStacked) {
      topRow = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (actions.isNotEmpty) ...[
            if (actions.length == 2)
              Row(
                children: [
                  Expanded(child: actions[0]),
                  const SizedBox(width: 8),
                  Expanded(child: actions[1]),
                ],
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < actions.length; i++) ...[
                    if (i > 0) const SizedBox(height: 8),
                    actions[i],
                  ],
                ],
              ),
            if (leading != null || chips != null) const SizedBox(height: 10),
          ],
          if (leading != null) leading!,
          if (leading != null && chips != null) ...[
            const SizedBox(height: 10),
          ],
          if (chips != null)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.hardEdge,
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: chips!,
            ),
        ],
      );
    } else if (hasTopRow) {
      topRow = Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (leading != null) leading!,
          if (leading != null && chips != null) _divider(theme),
          if (chips != null)
            Expanded(
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  clipBehavior: Clip.none,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: chips!,
                ),
              ),
            ),
          if (actions.isNotEmpty) ...[
            if (leading != null || chips != null) const SizedBox(width: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: actions,
            ),
          ],
        ],
      );
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(
        dense ? 12 : 20,
        8,
        dense ? 12 : 20,
        8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (topRow != null) topRow,
          if (hasSearchRow) ...[
            if (topRow != null) const SizedBox(height: 10),
            if (useStacked) ...[
              if (search != null) search!,
              if (matchCount != null) ...[
                if (search != null) const SizedBox(height: 6),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    AppLocaleKeys.osCommonMatchCount.trParams({
                      'count': '$matchCount',
                    }),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: theme.mutedText,
                    ),
                  ),
                ),
              ],
            ] else
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (search != null) Expanded(child: search!),
                  if (matchCount != null) ...[
                    if (search != null) const SizedBox(width: 12),
                    Text(
                      AppLocaleKeys.osCommonMatchCount.trParams({
                        'count': '$matchCount',
                      }),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: theme.mutedText,
                      ),
                    ),
                  ],
                ],
              ),
          ],
        ],
      ),
    );
  }
}
