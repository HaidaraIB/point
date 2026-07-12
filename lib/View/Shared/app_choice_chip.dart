import 'package:flutter/material.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/Utils/app_theme_extension.dart';

/// Dark-mode-safe choice chip with proper Arabic label padding (replaces [ChoiceChip]).
class AppChoiceChip extends StatelessWidget {
  const AppChoiceChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
    this.showCheckWhenSelected = true,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;
  final bool showCheckWhenSelected;

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    final foreground = selected ? Colors.white : theme.primaryText;
    final background = selected ? AppColors.primary : theme.inputFill;
    final borderColor = selected ? AppColors.primary : theme.border;

    return Material(
      color: background,
      shape: StadiumBorder(side: BorderSide(color: borderColor)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onSelected,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected && showCheckWhenSelected) ...[
                Icon(Icons.check, size: 18, color: foreground),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  color: foreground,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
