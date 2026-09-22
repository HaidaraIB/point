import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Controller/OsWhatsappHubController.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Services/os_messaging_hub_tab_persistence.dart';
import 'package:point/Services/os_whatsapp_service.dart';
import 'package:point/Utils/OsPermissions.dart';
import 'package:point/Utils/app_theme_extension.dart';
import 'package:point/Utils/os_module_ids.dart';
import 'package:point/View/Os/Messaging/os_messaging_hub_tabs.dart';
import 'package:point/View/Os/os_button_styles.dart';
import 'package:point/View/Os/os_horizontal_scroll_view.dart';
import 'package:point/View/Os/os_page_header.dart';
import 'package:point/View/Shared/ResponsiveScaffold.dart';
import 'package:point/View/Shared/responsive.dart';

class OsMessagingHubPage extends StatefulWidget {
  const OsMessagingHubPage({super.key});

  @override
  State<OsMessagingHubPage> createState() => _OsMessagingHubPageState();
}

class _OsMessagingHubPageState extends State<OsMessagingHubPage> {
  late final OsWhatsappHubController _hub;
  var _panelIndex = 0;
  var _logsCount = 0;
  Worker? _logsCountWorker;

  @override
  void initState() {
    super.initState();
    _hub = Get.find<OsWhatsappHubController>();
    _logsCount = _hub.logs.length;
    _logsCountWorker = ever(_hub.logs, (_) {
      final next = _hub.logs.length;
      if (next != _logsCount && mounted) {
        setState(() => _logsCount = next);
      }
    });
    final args = Get.arguments;
    final openInvoiceInSendTab = args is Map &&
        (args['invoiceId']?.toString().trim().isNotEmpty ?? false);
    if (openInvoiceInSendTab) {
      _panelIndex = 0;
      OsMessagingHubTabPersistence.saveIndex(0);
      _hub.applyNavigationArguments(args);
      _hub.ensureInvoicePurposeSelected();
    } else {
      _restoreSavedPanel();
    }
    OsWhatsappService.instance.loadSettings();
  }

  Future<void> _restoreSavedPanel() async {
    final saved = await OsMessagingHubTabPersistence.loadSavedIndex();
    if (!mounted || saved == _panelIndex) return;
    setState(() => _panelIndex = saved);
  }

  void _selectPanel(int index) {
    final safe = index.clamp(0, OsMessagingHubTabPersistence.names.length - 1);
    if (_panelIndex == safe) return;
    setState(() => _panelIndex = safe);
    OsMessagingHubTabPersistence.saveIndex(safe);
  }

  @override
  void dispose() {
    _logsCountWorker?.dispose();
    super.dispose();
  }

  Widget _buildPanel() {
    switch (OsMessagingHubTabPersistence.nameAt(_panelIndex)) {
      case OsMessagingHubTabPersistence.logs:
        return OsMessagingHubLogsTab(hub: _hub);
      case OsMessagingHubTabPersistence.send:
      default:
        return OsMessagingHubSendTab(hub: _hub);
    }
  }

  @override
  Widget build(BuildContext context) {
    final emp = Get.find<HomeController>().effectiveEmployee;
    if (!OsPermissions.canAccessModule(emp, OsModuleIds.messaging)) {
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
            title: AppLocaleKeys.osMessagingHubTitle.tr,
            subtitle: compact ? null : AppLocaleKeys.osMessagingHubSubtitle.tr,
            currentRoute: '/os/messaging',
            actions: [
              FilledButton.icon(
                onPressed: () =>
                    _selectPanel(OsMessagingHubTabPersistence.logsIndex),
                style: OsButtonStyles.secondaryCompact(
                  theme,
                  active: OsMessagingHubTabPersistence.nameAt(_panelIndex) ==
                      OsMessagingHubTabPersistence.logs,
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
            child: OsHorizontalScrollContainer(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              builder: (_) => Row(
                children: [
                  _tabChip(
                    theme,
                    index: 0,
                    icon: Icons.send_outlined,
                    label: AppLocaleKeys.osMessagingHubTabSend.tr,
                  ),
                  _tabChip(
                    theme,
                    index: OsMessagingHubTabPersistence.logsIndex,
                    icon: Icons.history_rounded,
                    label: AppLocaleKeys.osMessagingHubTabLogs.tr,
                  ),
                ],
              ),
            ),
          ),
          Expanded(child: _buildPanel()),
        ],
      ),
    );
  }

  Widget _tabChip(
    AppThemeExtension theme, {
    required int index,
    required IconData icon,
    required String label,
  }) {
    final active = _panelIndex == index;
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: FilledButton.icon(
        onPressed: () => _selectPanel(index),
        style: OsButtonStyles.secondaryCompact(theme, active: active),
        icon: Icon(icon, size: 16),
        label: Text(label, style: OsButtonStyles.compactTextStyle),
      ),
    );
  }
}
