import 'package:flutter/material.dart';
import 'package:point/Utils/AppColors.dart';

Widget tableActionsMenuRow({
  required String label,
  required IconData icon,
  required Color iconColor,
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 14,
              color: AppColors.primaryfontColor,
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
