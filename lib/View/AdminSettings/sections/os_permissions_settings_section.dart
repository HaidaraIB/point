import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:point/Utils/text_input_bidi.dart';
import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/EmployeeModel.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Utils/os_module_ids.dart';
import 'package:point/View/Os/os_modules.dart';
import 'package:point/View/Shared/app_user_avatar.dart';
import 'package:point/Utils/app_theme_extension.dart';

class OsPermissionsSettingsSection extends StatefulWidget {
  const OsPermissionsSettingsSection({super.key});

  @override
  State<OsPermissionsSettingsSection> createState() =>
      _OsPermissionsSettingsSectionState();
}

class _OsPermissionsSettingsSectionState
    extends State<OsPermissionsSettingsSection> {
  final _searchController = TextEditingController();
  final _savingIds = <String>{};
  String? _expandedSupervisorId;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<EmployeeModel> _filteredSupervisors(HomeController hc) {
    final q = _searchController.text.trim().toLowerCase();
    return hc.employees
        .where((e) => e.role.trim().toLowerCase() == 'supervisor')
        .where((e) {
          if (q.isEmpty) return true;
          final name = (e.name ?? '').toLowerCase();
          final email = (e.email ?? '').toLowerCase();
          return name.contains(q) || email.contains(q);
        })
        .toList(growable: false);
  }

  Future<void> _onToggleModule(
    EmployeeModel emp,
    String moduleId,
    bool enabled,
  ) async {
    final id = emp.id?.trim();
    if (id == null || id.isEmpty) return;
    final next = List<String>.from(emp.osModuleAccess);
    if (enabled) {
      if (!next.contains(moduleId)) next.add(moduleId);
    } else {
      next.remove(moduleId);
    }
    final normalized = OsModuleIds.normalize(next);
    setState(() => _savingIds.add(id));
    try {
      final hc = Get.find<HomeController>();
      final ok = await hc.setEmployeeOsModuleAccess(
        employeeId: id,
        moduleIds: normalized,
      );
      if (!ok) {
        FunHelper.showSnackbar(
          'error'.tr,
          AppLocaleKeys.adminSettingsOsModuleAccessSaveFailed.tr,
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return;
      }
      FunHelper.showSnackbar(
        'common.confirm'.tr,
        AppLocaleKeys.adminSettingsOsModuleAccessSaveSuccess.tr,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } on FirebaseException catch (e) {
      final message = e.code == 'permission-denied'
          ? AppLocaleKeys.adminSettingsSavePermissionDenied.tr
          : AppLocaleKeys.adminSettingsOsModuleAccessSaveFailed.tr;
      FunHelper.showSnackbar(
        'error'.tr,
        message,
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      if (mounted) setState(() => _savingIds.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final hc = Get.find<HomeController>();
    final theme = context.appTheme;

    return Obx(() {
      final rows = _filteredSupervisors(hc);

      return SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                AppLocaleKeys.adminSettingsSectionOsPermissions.tr,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: theme.primaryText,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                AppLocaleKeys.adminSettingsOsPermissionsHelp.tr,
                style: TextStyle(
                  color: theme.secondaryText,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              typedDirectionTextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: AppLocaleKeys.adminSettingsOsPermissionsSearch.tr,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 16),
              if (rows.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    AppLocaleKeys.adminSettingsOsPermissionsEmpty.tr,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: theme.mutedText),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final emp = rows[index];
                    final id = emp.id ?? '';
                    final saving = _savingIds.contains(id);
                    final expanded = _expandedSupervisorId == id;
                    final grantedCount = emp.osModuleAccess.length;

                    return Material(
                      color: theme.cardSurface,
                      borderRadius: BorderRadius.circular(8),
                      child: Column(
                        children: [
                          ListTile(
                            leading: AppUserAvatar(
                              url: emp.image ?? '',
                              displayName: emp.name ?? '',
                              radius: 20,
                            ),
                            title: Text(
                              emp.name?.trim().isNotEmpty == true
                                  ? emp.name!.trim()
                                  : '-',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: theme.primaryText,
                              ),
                            ),
                            subtitle: Text(
                              emp.email ?? '',
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.mutedText,
                              ),
                            ),
                            trailing: saving
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        AppLocaleKeys
                                            .adminSettingsOsPermissionsGrantedCount
                                            .trParams({'count': '$grantedCount'}),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: theme.mutedText,
                                        ),
                                      ),
                                      Icon(
                                        expanded
                                            ? Icons.expand_less
                                            : Icons.expand_more,
                                        color: theme.mutedText,
                                      ),
                                    ],
                                  ),
                            onTap: saving
                                ? null
                                : () => setState(() {
                                      _expandedSupervisorId =
                                          expanded ? null : id;
                                    }),
                          ),
                          if (expanded)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                children: [
                                  for (final module in osModules)
                                    FilterChip(
                                      label: Text(module.titleKey.tr),
                                      selected: emp.osModuleAccess
                                          .contains(module.id),
                                      onSelected: saving
                                          ? null
                                          : (v) => _onToggleModule(
                                                emp,
                                                module.id,
                                                v,
                                              ),
                                    ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      );
    });
  }
}
