import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Controller/OsEmailHubController.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Services/os_email_hub_tab_persistence.dart';
import 'package:point/Models/Os/OsEmailLogModel.dart';
import 'package:point/Models/Os/os_email_enums.dart';
import 'package:point/Utils/OsPermissions.dart';
import 'package:point/Utils/app_theme_extension.dart';
import 'package:point/View/Os/EmailHub/os_email_hub_helpers.dart';
import 'package:point/View/Os/EmailHub/os_email_hub_logs_tab.dart';
import 'package:point/View/Os/EmailHub/os_email_hub_settings_tab.dart';
import 'package:point/View/Os/EmailHub/os_email_hub_tabs.dart';
import 'package:point/View/Os/os_button_styles.dart';
import 'package:point/View/Os/os_page_header.dart';
import 'package:point/View/Os/os_snackbar.dart';
import 'package:point/View/Shared/ResponsiveScaffold.dart';

class OsEmailHubPage extends StatefulWidget {
  const OsEmailHubPage({super.key});

  @override
  State<OsEmailHubPage> createState() => _OsEmailHubPageState();
}

class _OsEmailHubPageState extends State<OsEmailHubPage> {
  late final OsEmailHubController _hub;
  var _panelIndex = 0;
  var _restoringPrefs = false;

  @override
  void initState() {
    super.initState();
    _hub = Get.find<OsEmailHubController>();
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
    _hub.persistDraft();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final emp = Get.find<HomeController>().effectiveEmployee;
    if (!OsPermissions.canAccessOsSection(emp)) {
      return Scaffold(body: Center(child: Text(AppLocaleKeys.errorsForbidden.tr)));
    }

    final theme = context.appTheme;

    return ResponsiveScaffold(
      selectedTab: 14,
      sideMenu: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OsPageHeader(
            title: AppLocaleKeys.osEmailHubTitle.tr,
            subtitle: AppLocaleKeys.osEmailHubSubtitle.tr,
            currentRoute: '/os/email-hub',
            actions: [
              FilledButton.icon(
                onPressed: () => _selectPanel(6),
                style: OsButtonStyles.secondaryCompact(
                  theme,
                  active: _panelIndex == 6,
                ),
                icon: const Icon(Icons.settings_outlined, size: 16),
                label: Text(AppLocaleKeys.osEmailHubTabSettings.tr),
              ),
              Obx(
                () => FilledButton.icon(
                  onPressed: () => _selectPanel(5),
                  style: OsButtonStyles.secondaryCompact(
                    theme,
                    active: _panelIndex == 5,
                  ),
                  icon: const Icon(Icons.history_rounded, size: 16),
                  label: Text(
                    AppLocaleKeys.osEmailHubHeaderLogs.trParams({
                      'count': '${_hub.logs.length}',
                    }),
                  ),
                ),
              ),
            ],
          ),
          Material(
            color: theme.cardSurface,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Row(
                children: [
                  _dispatchTab(
                    theme,
                    index: 0,
                    icon: Icons.receipt_long_outlined,
                    label: AppLocaleKeys.osEmailHubTabInvoices.tr,
                  ),
                  _dispatchTab(
                    theme,
                    index: 1,
                    icon: Icons.request_quote_outlined,
                    label: AppLocaleKeys.osEmailHubTabQuotations.tr,
                  ),
                  _dispatchTab(
                    theme,
                    index: 2,
                    icon: Icons.badge_outlined,
                    label: AppLocaleKeys.osEmailHubTabPayslips.tr,
                  ),
                  _dispatchTab(
                    theme,
                    index: 3,
                    icon: Icons.emoji_events_outlined,
                    label: AppLocaleKeys.osEmailHubTabAppreciation.tr,
                  ),
                  _dispatchTab(
                    theme,
                    index: 4,
                    icon: Icons.warning_amber_rounded,
                    label: AppLocaleKeys.osEmailHubTabPenalties.tr,
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: _panelIndex,
              children: [
                OsEmailHubInvoicesTab(hub: _hub),
                OsEmailHubQuotationsTab(hub: _hub),
                OsEmailHubPayslipsTab(hub: _hub),
                OsEmailHubAppreciationTab(hub: _hub),
                OsEmailHubPenaltiesTab(hub: _hub),
                OsEmailHubLogsTab(hub: _hub),
                OsEmailHubSettingsTab(
                  hub: _hub,
                  isVisible: _panelIndex == 6,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dispatchTab(
    AppThemeExtension theme, {
    required int index,
    required IconData icon,
    required String label,
  }) {
    final selected = _panelIndex == index;
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: FilledButton.icon(
        onPressed: () => _selectPanel(index),
        style: selected
            ? OsButtonStyles.primaryCompact()
            : OsButtonStyles.secondaryCompact(theme),
        icon: Icon(icon, size: 16),
        label: Text(label),
      ),
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
  final String? emptyMessage;
  final Widget? preview;
  final String? sendLabel;
  final String? secondaryLabel;
  final Future<void> Function()? onSecondaryAction;

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;

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

    final formCard = Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.cardSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: theme.accentText),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: theme.primaryText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.secondaryText,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ...children,
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: [
              if (secondaryLabel != null && onSecondaryAction != null)
                FilledButton.icon(
                  onPressed: isSending ? null : onSecondaryAction,
                  style: OsButtonStyles.secondaryCompact(theme),
                  icon: const Icon(Icons.groups_outlined, size: 18),
                  label: Text(secondaryLabel!),
                ),
              FilledButton.icon(
                onPressed: isSending ? null : onSend,
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
              ),
            ],
          ),
        ],
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 960 && preview != null;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: formCard),
                  const SizedBox(width: 16),
                  Expanded(child: preview!),
                ],
              )
            else ...[
              formCard,
              if (preview != null) ...[
                const SizedBox(height: 16),
                preview!,
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
    default:
      return AppLocaleKeys.osEmailHubCategoryOther.tr;
  }
}

void showEmailLogPreview(
  BuildContext context,
  OsEmailLogModel log, {
  OsEmailHubController? hub,
}) {
  final theme = context.appTheme;
  final failed = log.status == OsEmailLogStatus.failed;
  showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 520),
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
                child: SingleChildScrollView(
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
