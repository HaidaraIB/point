import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Controller/OsCrmController.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/ClientModel.dart';
import 'package:point/Services/os_crm_view_persistence.dart';
import 'package:point/Utils/OsPermissions.dart';
import 'package:point/Utils/os_module_ids.dart';
import 'package:point/View/Os/Crm/os_crm_client_form_dialog.dart';
import 'package:point/View/Os/Crm/os_crm_kanban.dart';
import 'package:point/View/Os/Crm/os_crm_list_view.dart';
import 'package:point/View/Os/Crm/os_crm_profile_panel.dart';
import 'package:point/View/Os/Crm/os_crm_stage_change.dart';
import 'package:point/View/Os/os_button_styles.dart';
import 'package:point/View/Os/os_form_dialog.dart';
import 'package:point/View/Os/os_list_filters.dart';
import 'package:point/View/Os/os_page_header.dart';
import 'package:point/View/Shared/ResponsiveScaffold.dart';
import 'package:point/View/Shared/responsive.dart';

enum _CrmViewMode { kanban, list, profile }

class OsCrmPage extends StatefulWidget {
  const OsCrmPage({super.key});

  @override
  State<OsCrmPage> createState() => _OsCrmPageState();
}

class _OsCrmPageState extends State<OsCrmPage> {
  final _search = TextEditingController();
  var _viewMode = _CrmViewMode.kanban;
  var _previousViewMode = _CrmViewMode.kanban;
  String? _selectedClientId;
  var _restoringPrefs = false;

  @override
  void initState() {
    super.initState();
    Get.find<OsCrmController>();
    _restoreViewMode();
  }

  Future<void> _restoreViewMode() async {
    final saved = await OsCrmViewPersistence.load();
    if (!mounted) return;
    _restoringPrefs = true;
    setState(() {
      final mode =
          saved == OsCrmViewPersistence.list ? _CrmViewMode.list : _CrmViewMode.kanban;
      _viewMode = mode;
      _previousViewMode = mode;
    });
    _restoringPrefs = false;
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _openProfile(String clientId) {
    setState(() {
      _previousViewMode = _viewMode == _CrmViewMode.profile
          ? _previousViewMode
          : _viewMode;
      _selectedClientId = clientId;
      _viewMode = _CrmViewMode.profile;
    });
  }

  void _backFromProfile() {
    setState(() {
      _viewMode = _previousViewMode;
      _selectedClientId = null;
    });
  }

  void _setViewMode(_CrmViewMode mode) {
    if (mode == _viewMode || mode == _CrmViewMode.profile) return;
    setState(() {
      _viewMode = mode;
      _previousViewMode = mode;
      _selectedClientId = null;
    });
    if (!_restoringPrefs) {
      OsCrmViewPersistence.save(
        mode == _CrmViewMode.list
            ? OsCrmViewPersistence.list
            : OsCrmViewPersistence.kanban,
      );
    }
  }

  Future<void> _handleStageChange(ClientModel client, String newStage) async {
    final crm = Get.find<OsCrmController>();
    final current = crm.effectiveStage(client);
    await confirmAndApplyCrmStageChange(
      context,
      currentStage: current,
      newStage: newStage,
      onApply: () => crm.updateStage(client.id!, newStage),
    );
  }

  @override
  Widget build(BuildContext context) {
    final emp = Get.find<HomeController>().effectiveEmployee;
    if (!OsPermissions.canAccessModule(emp, OsModuleIds.crm)) {
      return Scaffold(body: Center(child: Text('errors.forbidden'.tr)));
    }

    final crm = Get.find<OsCrmController>();
    final boardMode = _viewMode == _CrmViewMode.profile
        ? _previousViewMode
        : _viewMode;
    final mobile = Responsive.isMobile(context);
    final inProfile = _viewMode == _CrmViewMode.profile;

    return ResponsiveScaffold(
      selectedTab: 14,
      sideMenu: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OsPageHeader(
            title: AppLocaleKeys.osCrmTitle.tr,
            subtitle: AppLocaleKeys.osCrmSubtitle.tr,
            currentRoute: '/os/crm',
            actions: inProfile
                ? null
                : [
                    OsCrmViewToggle(
                      isKanban: boardMode == _CrmViewMode.kanban,
                      onKanban: () => _setViewMode(_CrmViewMode.kanban),
                      onList: () => _setViewMode(_CrmViewMode.list),
                    ),
                    FilledButton.icon(
                      onPressed: () => showOsCrmClientFormDialog(context),
                      style: OsButtonStyles.primaryCompact(),
                      icon: const Icon(Icons.add, size: 18),
                      label: Text(AppLocaleKeys.osCrmAdd.tr),
                    ),
                  ],
          ),
          if (!inProfile)
            Padding(
              padding: EdgeInsets.fromLTRB(mobile ? 12 : 16, 0, mobile ? 12 : 16, 8),
              child: Obx(() {
                final total = crm.clients.length;
                final filtered = crm.filteredClients(_search.text).length;
                return OsListFilterBar(
                  dense: mobile,
                  search: OsSearchField(
                    controller: _search,
                    hint: AppLocaleKeys.osCrmSearch.tr,
                    width: double.infinity,
                    onChanged: (_) => setState(() {}),
                  ),
                  matchCount: total == 0 ? null : filtered,
                );
              }),
            ),
          Expanded(
            child: Obx(() {
              final all = crm.filteredClients(_search.text);
              if (_viewMode == _CrmViewMode.profile) {
                final client = crm.clientById(_selectedClientId);
                if (client == null) {
                  return OsEmptyState(message: AppLocaleKeys.osCrmEmpty.tr);
                }
                return OsCrmProfilePanel(
                  key: ValueKey(client.id),
                  client: client,
                  onBack: _backFromProfile,
                );
              }
              if (all.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      OsEmptyState(
                        message: _search.text.trim().isEmpty
                            ? AppLocaleKeys.osCrmEmpty.tr
                            : AppLocaleKeys.osCrmEmptyFilter.tr,
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: () => showOsCrmClientFormDialog(context),
                        style: OsButtonStyles.primaryCompact(),
                        icon: const Icon(Icons.add, size: 18),
                        label: Text(AppLocaleKeys.osCrmAdd.tr),
                      ),
                    ],
                  ),
                );
              }
              if (_viewMode == _CrmViewMode.list) {
                return OsCrmListView(
                  clients: all,
                  crm: crm,
                  onTap: _openProfile,
                  onChangeStage: (client, stage) =>
                      _handleStageChange(client, stage),
                );
              }
              return OsCrmKanbanView(
                clients: all,
                crm: crm,
                onTap: _openProfile,
                onAdd: (stage) => showOsCrmClientFormDialog(
                  context,
                  initialStage: stage,
                ),
                onChangeStage: _handleStageChange,
              );
            }),
          ),
        ],
      ),
    );
  }
}
