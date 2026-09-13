import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/Utils/app_theme_extension.dart';

/// Compact search field used by OS list filter bars.
class OsSearchField extends StatelessWidget {
  const OsSearchField({
    super.key,
    required this.controller,
    required this.hint,
    this.width = 240,
    this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final double width;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    return SizedBox(
      width: width,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: TextStyle(fontSize: 13, color: theme.primaryText),
        decoration: InputDecoration(
          hintText: hint,
          hintMaxLines: 1,
          prefixIcon: Icon(Icons.search, size: 18, color: theme.mutedText),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  onPressed: () {
                    controller.clear();
                    onChanged?.call('');
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
      ),
    );
  }
}

class OsFilterChipOption {
  const OsFilterChipOption({required this.value, required this.label});

  final String value;
  final String label;
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final opt in options)
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: ChoiceChip(
              label: Text(opt.label),
              selected: value == opt.value,
              visualDensity: VisualDensity.standard,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              onSelected: (_) => onChanged(opt.value),
            ),
          ),
      ],
    );
  }
}

/// Filter bar layout:
/// 1) leading + chips with Add actions on one row (actions at the end / far left in RTL)
/// 2) search alone on the next row, under the filters
class OsListFilterBar extends StatelessWidget {
  const OsListFilterBar({
    super.key,
    this.leading,
    this.chips,
    this.search,
    this.actions = const [],
    this.matchCount,
  });

  final Widget? leading;
  final Widget? chips;
  final Widget? search;
  final List<Widget> actions;
  final int? matchCount;

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    final hasTopRow = leading != null || chips != null || actions.isNotEmpty;

    final topControls = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (leading != null) ...[
          leading!,
          if (chips != null) const SizedBox(width: 12),
        ],
        if (chips != null) chips!,
      ],
    );

    final topRow = !hasTopRow
        ? null
        : Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    clipBehavior: Clip.none,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: topControls,
                  ),
                ),
              ),
              if (actions.isNotEmpty) ...[
                const SizedBox(width: 12),
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

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (topRow != null) topRow,
          if (search != null) ...[
            if (topRow != null) const SizedBox(height: 10),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: search!,
            ),
          ],
          if (matchCount != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                AppLocaleKeys.osCommonMatchCount.trParams({
                  'count': '$matchCount',
                }),
                style: TextStyle(fontSize: 12, color: theme.mutedText),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
