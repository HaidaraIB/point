import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Controller/OsEmailHubController.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Services/os_email_hub_tab_persistence.dart';
import 'package:point/Models/Os/OsEmailLogModel.dart';
import 'package:point/Models/Os/os_email_enums.dart';
import 'package:point/Utils/OsPermissions.dart';
import 'package:point/Utils/os_module_ids.dart';
import 'package:point/Utils/app_theme_extension.dart';
import 'package:point/View/Os/EmailHub/os_email_hub_helpers.dart';
import 'package:point/View/Os/EmailHub/os_email_hub_logs_tab.dart';
import 'package:point/View/Os/EmailHub/os_email_hub_app_tabs.dart';
import 'package:point/View/Os/EmailHub/os_email_hub_tabs.dart';
import 'package:point/View/Os/os_button_styles.dart';
import 'package:point/View/Os/os_horizontal_scroll_view.dart';
import 'package:point/View/Os/os_page_header.dart';
import 'package:point/View/Os/os_snackbar.dart';
import 'package:point/View/Shared/ResponsiveScaffold.dart';
import 'package:point/View/Shared/responsive.dart';
import 'package:point/View/Os/EmailHub/html_email_preview.dart';

class OsEmailHubPage extends StatefulWidget {
  const OsEmailHubPage({super.key});

  @override
  State<OsEmailHubPage> createState() => _OsEmailHubPageState();
}

class _OsEmailHubPageState extends State<OsEmailHubPage> {
  late final OsEmailHubController _hub;
  var _panelIndex = 0;
  var _restoringPrefs = false;
  var _logsCount = 0;
  Worker? _logsCountWorker;
  final ScrollController _tabBarScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _hub = Get.find<OsEmailHubController>();
    _logsCount = _hub.logs.length;
    _logsCountWorker = ever(_hub.logs, (_) {
      final next = _hub.logs.length;
      if (next != _logsCount && mounted) {
        setState(() => _logsCount = next);
      }
    });
    if (OsEmailHubTabPersistence.hasRouteTab()) {
      _panelIndex = OsEmailHubTabPersistence.indexFromRoute();
      OsEmailHubTabPersistence.saveIndex(_panelIndex);
    } else {
      _restoreSavedPanel();
    }
  }

  Future<void> _restoreSavedPanel() async {
    final saved = await OsEmailHubTabPersistence.loadSavedIndex();
    if (!mounted || saved == _panelIndex) return;
    _restoringPrefs = true;
    setState(() => _panelIndex = saved);
    _restoringPrefs = false;
  }

  void _selectPanel(int index) {
    final safe = index.clamp(0, OsEmailHubTabPersistence.names.length - 1);
    if (_panelIndex == safe) return;
    setState(() => _panelIndex = safe);
    if (_restoringPrefs) return;
    OsEmailHubTabPersistence.saveIndex(safe);
    _hub.persistDraft();
  }

  @override
  void dispose() {
    _logsCountWorker?.dispose();
    _tabBarScrollController.dispose();
    _hub.persistDraft();
    super.dispose();
  }

  String _activeTabName() {
    final safe = _panelIndex.clamp(0, OsEmailHubTabPersistence.names.length - 1);
    return OsEmailHubTabPersistence.names[safe];
  }

  Widget _buildPanelContent() {
    switch (_activeTabName()) {
      case OsEmailHubTabPersistence.invoices:
        return OsEmailHubInvoicesTab(hub: _hub);
      case OsEmailHubTabPersistence.quotations:
        return OsEmailHubQuotationsTab(hub: _hub);
      case OsEmailHubTabPersistence.payslips:
        return OsEmailHubPayslipsTab(hub: _hub);
      case OsEmailHubTabPersistence.appreciation:
        return OsEmailHubAppreciationTab(hub: _hub);
      case OsEmailHubTabPersistence.penalties:
        return OsEmailHubPenaltiesTab(hub: _hub);
      case OsEmailHubTabPersistence.contracts:
        return OsEmailHubContractsTab(hub: _hub);
      case OsEmailHubTabPersistence.chat:
        return const OsEmailHubChatDigestTab();
      case OsEmailHubTabPersistence.employeeNotifications:
        return OsEmailHubNotificationCategoryTab(
          key: const ValueKey(OsEmailHubTabPersistence.employeeNotifications),
          categoryKey: AppLocaleKeys.pushTestCategoryEmployee,
          title: AppLocaleKeys.osEmailHubTabEmployeeNotifications.tr,
          subtitle: AppLocaleKeys.osEmailHubAppNotificationsSelectType.tr,
          icon: Icons.assignment_outlined,
        );
      case OsEmailHubTabPersistence.managerNotifications:
        return OsEmailHubNotificationCategoryTab(
          key: const ValueKey(OsEmailHubTabPersistence.managerNotifications),
          categoryKey: AppLocaleKeys.pushTestCategoryManager,
          title: AppLocaleKeys.osEmailHubTabManagerNotifications.tr,
          subtitle: AppLocaleKeys.osEmailHubAppNotificationsSelectType.tr,
          icon: Icons.supervisor_account_outlined,
        );
      case OsEmailHubTabPersistence.clientNotifications:
        return OsEmailHubNotificationCategoryTab(
          key: const ValueKey(OsEmailHubTabPersistence.clientNotifications),
          categoryKey: AppLocaleKeys.pushTestCategoryClient,
          title: AppLocaleKeys.osEmailHubTabClientNotifications.tr,
          subtitle: AppLocaleKeys.osEmailHubAppNotificationsSelectType.tr,
          icon: Icons.person_outline,
        );
      case OsEmailHubTabPersistence.publishNotifications:
        return OsEmailHubNotificationCategoryTab(
          key: const ValueKey(OsEmailHubTabPersistence.publishNotifications),
          categoryKey: AppLocaleKeys.pushTestCategoryPublish,
          title: AppLocaleKeys.osEmailHubTabPublishNotifications.tr,
          subtitle: AppLocaleKeys.osEmailHubAppNotificationsSelectType.tr,
          icon: Icons.publish_outlined,
        );
      case OsEmailHubTabPersistence.adminNotifications:
        return OsEmailHubNotificationCategoryTab(
          key: const ValueKey(OsEmailHubTabPersistence.adminNotifications),
          categoryKey: AppLocaleKeys.pushTestCategoryAdminMeta,
          title: AppLocaleKeys.osEmailHubTabAdminNotifications.tr,
          subtitle: AppLocaleKeys.osEmailHubAppNotificationsSelectType.tr,
          icon: Icons.admin_panel_settings_outlined,
        );
      case OsEmailHubTabPersistence.broadcast:
        return const OsEmailHubBroadcastTab();
      case OsEmailHubTabPersistence.logs:
        return OsEmailHubLogsTab(hub: _hub);
      default:
        return OsEmailHubInvoicesTab(hub: _hub);
    }
  }

  @override
  Widget build(BuildContext context) {
    final emp = Get.find<HomeController>().effectiveEmployee;
    if (!OsPermissions.canAccessModule(emp, OsModuleIds.emailHub)) {
      return Scaffold(body: Center(child: Text(AppLocaleKeys.errorsForbidden.tr)));
    }

    final theme = context.appTheme;
    final compact = Responsive.isMobile(context);

    return ResponsiveScaffold(
      selectedTab: 14,
      sideMenu: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OsPageHeader(
            title: AppLocaleKeys.osEmailHubTitle.tr,
            subtitle: compact ? null : AppLocaleKeys.osEmailHubSubtitle.tr,
            currentRoute: '/os/email-hub',
            actions: [
              FilledButton.icon(
                onPressed: () => _selectPanel(OsEmailHubTabPersistence.logsIndex),
                style: OsButtonStyles.secondaryCompact(
                  theme,
                  active: _activeTabName() == OsEmailHubTabPersistence.logs,
                ),
                icon: const Icon(Icons.history_rounded, size: 16),
                label: Text(
                  AppLocaleKeys.osEmailHubHeaderLogs.trParams({
                    'count': '$_logsCount',
                  }),
                  style: OsButtonStyles.compactTextStyle,
                ),
              ),
            ],
          ),
          Material(
            color: theme.cardSurface,
            child: _EmailHubTabStrip(
              compact: compact,
              controller: _tabBarScrollController,
              child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                  if (OsPermissions.canAccessModule(emp, OsModuleIds.invoices))
                    _dispatchTab(
                      theme,
                      compact: compact,
                      index: 0,
                      icon: Icons.receipt_long_outlined,
                      label: AppLocaleKeys.osEmailHubTabInvoices.tr,
                    ),
                  if (OsPermissions.canAccessModule(emp, OsModuleIds.quotations))
                    _dispatchTab(
                      theme,
                      compact: compact,
                      index: 1,
                      icon: Icons.request_quote_outlined,
                      label: AppLocaleKeys.osEmailHubTabQuotations.tr,
                    ),
                  if (OsPermissions.canAccessModule(emp, OsModuleIds.payroll))
                    _dispatchTab(
                      theme,
                      compact: compact,
                      index: 2,
                      icon: Icons.badge_outlined,
                      label: AppLocaleKeys.osEmailHubTabPayslips.tr,
                    ),
                  _dispatchTab(
                    theme,
                    compact: compact,
                    index: 3,
                    icon: Icons.emoji_events_outlined,
                    label: AppLocaleKeys.osEmailHubTabAppreciation.tr,
                  ),
                  _dispatchTab(
                    theme,
                    compact: compact,
                    index: 4,
                    icon: Icons.warning_amber_rounded,
                    label: AppLocaleKeys.osEmailHubTabPenalties.tr,
                  ),
                  if (OsPermissions.canAccessModule(emp, OsModuleIds.contracts))
                    _dispatchTab(
                      theme,
                      compact: compact,
                      index: OsEmailHubTabPersistence.names
                          .indexOf(OsEmailHubTabPersistence.contracts),
                      icon: Icons.description_outlined,
                      label: AppLocaleKeys.osEmailHubTabContracts.tr,
                    ),
                  _dispatchTab(
                    theme,
                    compact: compact,
                    index: OsEmailHubTabPersistence.names
                        .indexOf(OsEmailHubTabPersistence.chat),
                    icon: Icons.forum_outlined,
                    label: AppLocaleKeys.osEmailHubTabChat.tr,
                  ),
                  _dispatchTab(
                    theme,
                    compact: compact,
                    index: OsEmailHubTabPersistence.names.indexOf(
                      OsEmailHubTabPersistence.employeeNotifications,
                    ),
                    icon: Icons.assignment_outlined,
                    label: AppLocaleKeys.osEmailHubTabEmployeeNotifications.tr,
                  ),
                  _dispatchTab(
                    theme,
                    compact: compact,
                    index: OsEmailHubTabPersistence.names.indexOf(
                      OsEmailHubTabPersistence.managerNotifications,
                    ),
                    icon: Icons.supervisor_account_outlined,
                    label: AppLocaleKeys.osEmailHubTabManagerNotifications.tr,
                  ),
                  _dispatchTab(
                    theme,
                    compact: compact,
                    index: OsEmailHubTabPersistence.names.indexOf(
                      OsEmailHubTabPersistence.clientNotifications,
                    ),
                    icon: Icons.person_outline,
                    label: AppLocaleKeys.osEmailHubTabClientNotifications.tr,
                  ),
                  _dispatchTab(
                    theme,
                    compact: compact,
                    index: OsEmailHubTabPersistence.names.indexOf(
                      OsEmailHubTabPersistence.publishNotifications,
                    ),
                    icon: Icons.publish_outlined,
                    label: AppLocaleKeys.osEmailHubTabPublishNotifications.tr,
                  ),
                  _dispatchTab(
                    theme,
                    compact: compact,
                    index: OsEmailHubTabPersistence.names.indexOf(
                      OsEmailHubTabPersistence.adminNotifications,
                    ),
                    icon: Icons.admin_panel_settings_outlined,
                    label: AppLocaleKeys.osEmailHubTabAdminNotifications.tr,
                  ),
                  _dispatchTab(
                    theme,
                    compact: compact,
                    index: OsEmailHubTabPersistence.names
                        .indexOf(OsEmailHubTabPersistence.broadcast),
                    icon: Icons.campaign_outlined,
                    label: AppLocaleKeys.osEmailHubTabBroadcast.tr,
                  ),
                  ],
                ),
            ),
          ),
          Expanded(child: _buildPanelContent()),
        ],
      ),
    );
  }

  Widget _dispatchTab(
    AppThemeExtension theme, {
    required bool compact,
    required int index,
    required IconData icon,
    required String label,
  }) {
    final selected = _panelIndex == index;
    return Padding(
      padding: EdgeInsetsDirectional.only(end: compact ? 10 : 8),
      child: FilledButton.icon(
        onPressed: () => _selectPanel(index),
        style: selected
            ? OsButtonStyles.primaryCompact()
            : OsButtonStyles.secondaryCompact(theme),
        icon: Icon(icon, size: compact ? 15 : 16),
        label: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: OsButtonStyles.compactTextStyle.copyWith(
            fontSize: compact ? 12 : null,
          ),
        ),
      ),
    );
  }
}

/// Horizontal email-type tabs with OS thin scrollbar (matches module nav).
class _EmailHubTabStrip extends StatelessWidget {
  const _EmailHubTabStrip({
    required this.compact,
    required this.controller,
    required this.child,
  });

  final bool compact;
  final ScrollController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return OsHorizontalScrollView(
      controller: controller,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        compact ? 10 : 12,
        compact ? 4 : 0,
        compact ? 10 : 12,
        compact ? 10 : 8,
      ),
      child: child,
    );
  }
}

/// Shared dispatch panel shell for invoice / quote / payslip tabs.
class OsEmailHubDispatchPanel extends StatelessWidget {
  const OsEmailHubDispatchPanel({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.children,
    required this.onSend,
    required this.isSending,
    this.sendEnabled = true,
    this.emptyMessage,
    this.preview,
    this.sendLabel,
    this.secondaryLabel,
    this.onSecondaryAction,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<Widget> children;
  final Future<void> Function() onSend;
  final bool isSending;
  final bool sendEnabled;
  final String? emptyMessage;
  final Widget? preview;
  final String? sendLabel;
  final String? secondaryLabel;
  final Future<void> Function()? onSecondaryAction;

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    final compact = Responsive.isMobile(context);
    final pagePad = compact ? 12.0 : 16.0;
    final cardPad = compact ? 14.0 : 18.0;

    if (emptyMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            emptyMessage!,
            textAlign: TextAlign.center,
            style: TextStyle(color: theme.secondaryText, fontSize: 15),
          ),
        ),
      );
    }

    final sendPrimary = FilledButton.icon(
      onPressed: (isSending || !sendEnabled) ? null : onSend,
      style: OsButtonStyles.primaryCompact(),
      icon: isSending
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.send_rounded, size: 18),
      label: Text(sendLabel ?? AppLocaleKeys.osEmailHubSend.tr),
    );

    final sendSecondary = secondaryLabel != null && onSecondaryAction != null
        ? FilledButton.icon(
            onPressed: isSending ? null : onSecondaryAction,
            style: OsButtonStyles.secondaryCompact(theme),
            icon: const Icon(Icons.groups_outlined, size: 18),
            label: Text(secondaryLabel!),
          )
        : null;

    final actionButtons = compact
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (sendSecondary != null) ...[
                SizedBox(width: double.infinity, child: sendSecondary),
                const SizedBox(height: 8),
              ],
              SizedBox(width: double.infinity, child: sendPrimary),
            ],
          )
        : Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: [
              if (sendSecondary != null) sendSecondary,
              sendPrimary,
            ],
          );

    final formCard = Container(
      padding: EdgeInsets.all(cardPad),
      decoration: BoxDecoration(
        color: theme.cardSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: theme.accentText, size: compact ? 22 : 24),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: compact ? 16 : 17,
                        fontWeight: FontWeight.w800,
                        color: theme.primaryText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: compact ? 12 : 13,
                        color: theme.secondaryText,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 14 : 18),
          ...children,
          SizedBox(height: compact ? 12 : 8),
          actionButtons,
        ],
      ),
    );

    final previewWidget = preview;

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = !compact && constraints.maxWidth >= 960 && preview != null;
        return ListView(
          padding: EdgeInsets.fromLTRB(pagePad, pagePad, pagePad, 24),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: formCard),
                  const SizedBox(width: 16),
                  Expanded(child: previewWidget!),
                ],
              )
            else ...[
              formCard,
              if (previewWidget != null) ...[
                SizedBox(height: compact ? 12 : 16),
                previewWidget,
              ],
            ],
          ],
        );
      },
    );
  }
}

String osEmailCategoryLabel(String type) {
  switch (type) {
    case OsEmailCategory.invoice:
      return AppLocaleKeys.osEmailHubCategoryInvoice.tr;
    case OsEmailCategory.quotation:
      return AppLocaleKeys.osEmailHubCategoryQuotation.tr;
    case OsEmailCategory.payslip:
      return AppLocaleKeys.osEmailHubCategoryPayslip.tr;
    case OsEmailCategory.appreciation:
      return AppLocaleKeys.osEmailHubCategoryAppreciation.tr;
    case OsEmailCategory.penalty:
      return AppLocaleKeys.osEmailHubCategoryPenalty.tr;
    case OsEmailCategory.contract:
      return AppLocaleKeys.osEmailHubCategoryContract.tr;
    default:
      return AppLocaleKeys.osEmailHubCategoryOther.tr;
  }
}

bool _isHtmlEmailContent(String content) {
  final trimmed = content.trimLeft().toLowerCase();
  return trimmed.startsWith('<!doctype html') || trimmed.startsWith('<html');
}

void showEmailLogPreview(
  BuildContext context,
  OsEmailLogModel log, {
  OsEmailHubController? hub,
}) {
  final theme = context.appTheme;
  final failed = log.status == OsEmailLogStatus.failed;
  final size = MediaQuery.sizeOf(context);
  final dialogWide = size.width >= 720;
  showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: dialogWide ? 24 : 12,
        vertical: dialogWide ? 24 : 16,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: dialogWide ? 560 : size.width - 24,
          maxHeight: dialogWide ? 520 : size.height * 0.88,
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                AppLocaleKeys.osEmailHubLogsDetailTitle.tr,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: theme.primaryText,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                log.subject,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: theme.primaryText,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${log.recipientName} <${log.recipientEmail}>',
                style: TextStyle(fontSize: 13, color: theme.secondaryText),
              ),
              const SizedBox(height: 8),
              Text(
                failed
                    ? AppLocaleKeys.osEmailHubLogsStatusFailed.tr
                    : AppLocaleKeys.osEmailHubLogsStatusSent.tr,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: failed ? Colors.redAccent : Colors.green.shade700,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _isHtmlEmailContent(log.content)
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: HtmlEmailPreview(
                          html: log.content,
                          embedded: true,
                        ),
                      )
                    : SingleChildScrollView(
                        child: Text(
                          log.content,
                          style: TextStyle(
                            fontSize: 14,
                            color: theme.primaryText,
                            height: 1.5,
                          ),
                        ),
                      ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (hub != null)
                    Obx(
                      () => TextButton.icon(
                        onPressed: hub.isSending.value
                            ? null
                            : () async {
                                final confirmed = await confirmResendEmailLog(
                                  context: ctx,
                                  recipientEmail: log.recipientEmail,
                                );
                                if (!confirmed) return;
                                final ok = await hub.resendLog(log);
                                if (ok) {
                                  OsSnackbar.success(
                                    AppLocaleKeys.osEmailHubTitle.tr,
                                    AppLocaleKeys.osEmailHubSentSuccess.trParams({
                                      'email': log.recipientEmail,
                                    }),
                                  );
                                  Navigator.pop(ctx);
                                } else {
                                  OsSnackbar.error(
                                    AppLocaleKeys.osEmailHubTitle.tr,
                                    AppLocaleKeys.osInvoicesErrorEmailFailed.tr,
                                  );
                                }
                              },
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: Text(AppLocaleKeys.osEmailHubLogsResend.tr),
                      ),
                    ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(AppLocaleKeys.osInvoicesOk.tr),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
