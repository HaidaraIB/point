import 'package:flutter/material.dart';
import 'package:point/Utils/app_theme_extension.dart';

Widget tableActionsMenuRow({
  required String label,
  required IconData icon,
  required Color iconColor,
  BuildContext? context,
}) {
  final theme = context?.appTheme ?? resolveAppTheme(context);
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 14,
              color: theme.primaryText,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Icon(icon, color: iconColor, size: 20),
      ],
    ),
  );
}
