import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/Os/os_crm_activity.dart';
import 'package:point/Models/Os/os_crm_enums.dart';

String osCrmStageLabel(String stage) {
  switch (stage) {
    case OsCrmStage.newLead:
      return AppLocaleKeys.osCrmStageNewLead.tr;
    case OsCrmStage.contacted:
      return AppLocaleKeys.osCrmStageContacted.tr;
    case OsCrmStage.quotationSent:
      return AppLocaleKeys.osCrmStageQuotationSent.tr;
    case OsCrmStage.negotiation:
      return AppLocaleKeys.osCrmStageNegotiation.tr;
    case OsCrmStage.won:
      return AppLocaleKeys.osCrmStageWon.tr;
    case OsCrmStage.inProgress:
      return AppLocaleKeys.osCrmStageInProgress.tr;
    case OsCrmStage.lost:
      return AppLocaleKeys.osCrmStageLost.tr;
    default:
      return AppLocaleKeys.osCrmStageNewLead.tr;
  }
}

String osCrmLeadSourceLabel(String source) {
  switch (source) {
    case OsLeadSource.whatsapp:
      return AppLocaleKeys.osCrmSourceWhatsapp.tr;
    case OsLeadSource.instagram:
      return AppLocaleKeys.osCrmSourceInstagram.tr;
    case OsLeadSource.referral:
      return AppLocaleKeys.osCrmSourceReferral.tr;
    case OsLeadSource.website:
      return AppLocaleKeys.osCrmSourceWebsite.tr;
    case OsLeadSource.ads:
      return AppLocaleKeys.osCrmSourceAds.tr;
    default:
      return source;
  }
}

Color osCrmStageColor(String stage) {
  switch (stage) {
    case OsCrmStage.newLead:
      return const Color(0xFF6366F1);
    case OsCrmStage.contacted:
      return const Color(0xFF0EA5E9);
    case OsCrmStage.quotationSent:
      return const Color(0xFFF59E0B);
    case OsCrmStage.negotiation:
      return const Color(0xFF8B5CF6);
    case OsCrmStage.won:
      return const Color(0xFF059669);
    case OsCrmStage.inProgress:
      return const Color(0xFF2563EB);
    case OsCrmStage.lost:
      return const Color(0xFFDC2626);
    default:
      return const Color(0xFF6366F1);
  }
}

const _crmStageMenuWidth = 220.0;

/// Colored row used inside CRM stage popup menus.
Widget osCrmStageMenuItemLabel(String stage) {
  final color = osCrmStageColor(stage);
  return Row(
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          osCrmStageLabel(stage),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: color,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ],
  );
}

String osCrmActivitySummary(OsCrmActivity activity) {
  switch (activity.type) {
    case OsCrmActivityType.stageChange:
      final parts = activity.content.split('|');
      if (parts.length == 2) {
        return AppLocaleKeys.osCrmActivityStageChange.trParams({
          'from': osCrmStageLabel(parts[0]),
          'to': osCrmStageLabel(parts[1]),
        });
      }
      return activity.content;
    case OsCrmActivityType.call:
      return activity.content.trim().isEmpty
          ? AppLocaleKeys.osCrmCall.tr
          : activity.content;
    case OsCrmActivityType.whatsapp:
      return activity.content.trim().isEmpty
          ? AppLocaleKeys.osCrmWhatsapp.tr
          : activity.content;
    case OsCrmActivityType.email:
      return activity.content.trim().isEmpty
          ? AppLocaleKeys.osCrmEmailAction.tr
          : activity.content;
    default:
      return activity.content;
  }
}

IconData osCrmActivityIcon(String type) {
  switch (type) {
    case OsCrmActivityType.stageChange:
      return Icons.swap_horiz_rounded;
    case OsCrmActivityType.call:
      return Icons.phone_outlined;
    case OsCrmActivityType.whatsapp:
      return Icons.chat_outlined;
    case OsCrmActivityType.email:
      return Icons.email_outlined;
    default:
      return Icons.sticky_note_2_outlined;
  }
}

Color osCrmActivityColor(String type) {
  switch (type) {
    case OsCrmActivityType.stageChange:
      return const Color(0xFF8B5CF6);
    case OsCrmActivityType.call:
      return const Color(0xFF0EA5E9);
    case OsCrmActivityType.whatsapp:
      return const Color(0xFF059669);
    case OsCrmActivityType.email:
      return const Color(0xFFF59E0B);
    default:
      return const Color(0xFF6366F1);
  }
}

String? osCrmLeadSourceDisplay(String? source) {
  if (source == null || source.trim().isEmpty) return null;
  if (OsLeadSource.all.contains(source)) {
    return osCrmLeadSourceLabel(source);
  }
  return source;
}

List<PopupMenuEntry<String>> osCrmStagePopupMenuItems() {
  return [
    for (final stage in OsCrmStage.ordered)
      PopupMenuItem<String>(
        value: stage,
        child: osCrmStageMenuItemLabel(stage),
      ),
  ];
}

/// Status pill used in CRM list/kanban (same chip pattern as OS finance tables).
class OsCrmStageBadge extends StatelessWidget {
  const OsCrmStageBadge({super.key, required this.stage, this.showArrow = false});

  final String stage;
  final bool showArrow;

  @override
  Widget build(BuildContext context) {
    final color = osCrmStageColor(stage);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            osCrmStageLabel(stage),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          if (showArrow) ...[
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down, size: 18, color: color),
          ],
        ],
      ),
    );
  }
}

/// Tappable stage pill — opens a menu to change pipeline stage in-place.
class OsCrmStageSelector extends StatefulWidget {
  const OsCrmStageSelector({
    super.key,
    required this.stage,
    required this.onChanged,
  });

  final String stage;
  final ValueChanged<String> onChanged;

  @override
  State<OsCrmStageSelector> createState() => _OsCrmStageSelectorState();
}

class _OsCrmStageSelectorState extends State<OsCrmStageSelector> {
  final _badgeKey = GlobalKey();
  var _menuOffsetX = 0.0;

  void _syncMenuOffset() {
    final box = _badgeKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final centered = (box.size.width - _crmStageMenuWidth) / 2;
    if (centered != _menuOffsetX) {
      setState(() => _menuOffsetX = centered);
    }
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncMenuOffset());

    return PopupMenuButton<String>(
      tooltip: AppLocaleKeys.osCrmChangeStage.tr,
      padding: EdgeInsets.zero,
      position: PopupMenuPosition.under,
      offset: Offset(_menuOffsetX, 6),
      constraints: const BoxConstraints(
        minWidth: _crmStageMenuWidth,
        maxWidth: _crmStageMenuWidth,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: widget.onChanged,
      itemBuilder: (context) => osCrmStagePopupMenuItems(),
      child: OsCrmStageBadge(
        key: _badgeKey,
        stage: widget.stage,
        showArrow: true,
      ),
    );
  }
}
