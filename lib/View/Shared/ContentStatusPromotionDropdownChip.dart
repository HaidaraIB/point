import 'package:flutter/material.dart';
import 'package:point/Services/StorageKeys.dart';

Color getContentStatusColor(String status) {
  switch (status) {
    case StorageKeys.status_under_revision:
      return Colors.blue;
    case StorageKeys.status_ready_to_publish:
      return Colors.teal;
    case StorageKeys.status_approved:
      return Colors.green;
    case StorageKeys.status_scheduled:
      return Colors.orange;
    case StorageKeys.status_processing:
      return Colors.amber;
    case StorageKeys.status_published:
      return Colors.lightGreen;
    case StorageKeys.status_rejected:
      return Colors.red;
    case StorageKeys.status_in_edit:
      return Colors.purple;
    case StorageKeys.status_edit_requested:
      return Colors.deepOrange;
    case StorageKeys.status_not_start_yet:
      return Colors.grey;
    default:
      return Colors.black45;
  }
}

Color getContentStatusBgColor(String status) {
  switch (status) {
    case StorageKeys.status_under_revision:
      return Colors.blue.shade50;
    case StorageKeys.status_approved:
      return Colors.green.shade50;
    case StorageKeys.status_rejected:
      return Colors.red.shade50;
    default:
      return Colors.grey.shade200;
  }
}

Color getContentPromotionColor(String? promotion) {
  switch (promotion) {
    case 'under_promotion':
      return Colors.teal;
    case 'end_promotion':
      return Colors.deepOrange;
    case 'no_promotion':
      return Colors.grey.shade700;
    default:
      return Colors.black54;
  }
}

Color getContentPromotionBgColor(String? promotion) {
  switch (promotion) {
    case 'under_promotion':
      return Colors.teal.shade50;
    case 'end_promotion':
      return Colors.deepOrange.shade50;
    case 'no_promotion':
      return Colors.grey.shade200;
    default:
      return Colors.grey.shade100;
  }
}

Widget buildContentDropdownChip({
  required String label,
  required Color textColor,
  required Color backgroundColor,
}) {
  return MouseRegion(
    cursor: SystemMouseCursors.click,
    child: Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            maxLines: 1,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 3),
          Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 16,
            color: textColor,
          ),
        ],
      ),
    ),
  );
}
