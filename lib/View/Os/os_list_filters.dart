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
    this.width = double.infinity,
    this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final double width;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    final field = TextField(
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
    );
    if (!width.isFinite) return field;
    return SizedBox(width: width, child: field);
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
  });

  final Widget? leading;
  final Widget? chips;
  final Widget? search;
  final List<Widget> actions;
  final int? matchCount;

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
    final hasTopRow = leading != null || chips != null || actions.isNotEmpty;
    final hasSearchRow = search != null || matchCount != null;

    final topRow = !hasTopRow
        ? null
        : Row(
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

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (topRow != null) topRow,
          if (hasSearchRow) ...[
            if (topRow != null) const SizedBox(height: 10),
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
