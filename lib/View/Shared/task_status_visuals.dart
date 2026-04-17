import 'package:flutter/material.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Services/StorageKeys.dart';

/// Material icons for canonical task/content status keys ([StorageKeys.status_*]
/// and promotion task statuses). Used on chips, menus, and meta tiles.
class TaskStatusVisuals {
  TaskStatusVisuals._();

  static String _canon(String rawOrCanonical) =>
      FunHelper.canonicalStoredStatus(rawOrCanonical);

  static IconData iconFor(String rawOrCanonical) {
    final k = _canon(rawOrCanonical);
    switch (k) {
      case StorageKeys.status_not_start_yet:
        return Icons.hourglass_empty_rounded;
      case StorageKeys.status_processing:
        return Icons.play_circle_outline_rounded;
      case StorageKeys.status_under_revision:
        return Icons.send_rounded;
      case StorageKeys.status_in_edit:
        return Icons.draw_rounded;
      case StorageKeys.status_edit_requested:
        return Icons.build_circle_outlined;
      case StorageKeys.status_ready_to_publish:
        return Icons.rocket_launch_outlined;
      case StorageKeys.status_awaiting_manager:
        return Icons.business_center_rounded;
      case StorageKeys.status_approved:
        return Icons.verified_rounded;
      case StorageKeys.status_scheduled:
        return Icons.event_available_rounded;
      case StorageKeys.status_task_completed:
        return Icons.task_alt_rounded;
      case StorageKeys.status_published:
        return Icons.newspaper_rounded;
      case StorageKeys.status_rejected:
        return Icons.cancel_rounded;
      case StorageKeys.status_promotion_in_progress:
        return Icons.campaign_outlined;
      case StorageKeys.status_promotion_ad_platform_review:
        return Icons.fact_check_rounded;
      case StorageKeys.status_promotion_running:
        return Icons.trending_up_rounded;
      case StorageKeys.status_promotion_finished:
        return Icons.flag_rounded;
      default:
        return Icons.label_outline_rounded;
    }
  }

  static Color iconTintFor(String rawOrCanonical) {
    final k = _canon(rawOrCanonical);
    switch (k) {
      case StorageKeys.status_processing:
        return Colors.amber.shade800;
      case StorageKeys.status_under_revision:
        return Colors.blue.shade700;
      case StorageKeys.status_awaiting_manager:
        return Colors.indigo.shade700;
      case StorageKeys.status_ready_to_publish:
        return Colors.teal.shade700;
      case StorageKeys.status_approved:
        return Colors.green.shade700;
      case StorageKeys.status_scheduled:
        return Colors.orange.shade800;
      case StorageKeys.status_task_completed:
      case StorageKeys.status_published:
        return Colors.lightGreen.shade800;
      case StorageKeys.status_rejected:
        return Colors.red.shade700;
      case StorageKeys.status_in_edit:
        return Colors.purple.shade700;
      case StorageKeys.status_edit_requested:
        return Colors.deepOrange.shade700;
      case StorageKeys.status_not_start_yet:
        return Colors.grey.shade700;
      case StorageKeys.status_promotion_in_progress:
        return Colors.amber.shade900;
      case StorageKeys.status_promotion_ad_platform_review:
        return Colors.blue.shade800;
      case StorageKeys.status_promotion_running:
        return Colors.green.shade800;
      case StorageKeys.status_promotion_finished:
        return Colors.blueGrey.shade700;
      default:
        return Colors.blueGrey.shade600;
    }
  }

  /// Pill tag with leading status icon (task cards, content cards, mobile details).
  static Widget statusChip({
    required String rawStatus,
    required Color fg,
    required Color bg,
    double iconSize = 13,
    double fontSize = 11,
  }) {
    final label = FunHelper.trStored(
      rawStatus,
      kind: StoredValueKind.taskStatus,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            iconFor(rawStatus),
            size: iconSize,
            color: fg,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: fg,
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  /// Popup row: label on the left, status icon on the right (matches TaskCard shortcuts).
  static Widget popupMenuRow({
    required String label,
    required String rawOrCanonicalForIcon,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Icon(
          iconFor(rawOrCanonicalForIcon),
          color: iconTintFor(rawOrCanonicalForIcon),
          size: 20,
        ),
      ],
    );
  }
}
