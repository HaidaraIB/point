import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/EmployeeModel.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Services/StorageKeys.dart';
import 'package:point/View/Shared/app_user_avatar.dart';
import 'package:point/Utils/app_theme_extension.dart';

class LibraryPermissionsSettingsSection extends StatefulWidget {
  const LibraryPermissionsSettingsSection({super.key});

  @override
  State<LibraryPermissionsSettingsSection> createState() =>
      _LibraryPermissionsSettingsSectionState();
}

class _LibraryPermissionsSettingsSectionState
    extends State<LibraryPermissionsSettingsSection> {
  final _searchController = TextEditingController();
  final _savingIds = <String>{};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<EmployeeModel> _filteredEmployees(HomeController hc) {
    final q = _searchController.text.trim().toLowerCase();
    return hc.employees
        .where((e) => e.role.trim().toLowerCase() == 'employee')
        .where((e) {
          if (q.isEmpty) return true;
          final name = (e.name ?? '').toLowerCase();
          final email = (e.email ?? '').toLowerCase();
          return name.contains(q) || email.contains(q);
        })
        .toList(growable: false);
  }

  Future<void> _onToggle(EmployeeModel emp, bool enabled) async {
    final id = emp.id?.trim();
    if (id == null || id.isEmpty) return;
    setState(() => _savingIds.add(id));
    try {
      final hc = Get.find<HomeController>();
      final ok = await hc.setEmployeeLibraryAccess(
        employeeId: id,
        enabled: enabled,
      );
      if (!ok) {
        FunHelper.showSnackbar(
          'error'.tr,
          AppLocaleKeys.adminSettingsLibraryAccessSaveFailed.tr,
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return;
      }
      FunHelper.showSnackbar(
        'common.confirm'.tr,
        AppLocaleKeys.adminSettingsLibraryAccessSaveSuccess.tr,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } on FirebaseException catch (e) {
      final message = e.code == 'permission-denied'
          ? AppLocaleKeys.adminSettingsSavePermissionDenied.tr
          : AppLocaleKeys.adminSettingsLibraryAccessSaveFailed.tr;
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

  String _departmentSummary(EmployeeModel emp) {
    if (emp.departments.isEmpty) return '-';
    return emp.departments
        .map((d) => StorageKeys.semanticDepartmentLabelKey(d).tr)
        .join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final hc = Get.find<HomeController>();

    return Obx(() {
      final rows = _filteredEmployees(hc);

      return SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                AppLocaleKeys.adminSettingsSectionLibraryPermissions.tr,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: context.appTheme.primaryText,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                AppLocaleKeys.adminSettingsLibraryPermissionsHelp.tr,
                style: TextStyle(
                  color: context.appTheme.secondaryText,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText:
                      AppLocaleKeys.adminSettingsLibraryPermissionsSearch.tr,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 16),
              if (rows.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    AppLocaleKeys.adminSettingsLibraryPermissionsEmpty.tr,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: context.appTheme.mutedText),
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
                    return Material(
                      color: context.appTheme.cardSurface,
                      borderRadius: BorderRadius.circular(8),
                      child: ListTile(
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
                            color: context.appTheme.primaryText,
                          ),
                        ),
                        subtitle: Text(
                          '${emp.email ?? ''}\n${_departmentSummary(emp)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: context.appTheme.mutedText,
                            height: 1.35,
                          ),
                        ),
                        isThreeLine: true,
                        trailing: saving
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Switch(
                                value: emp.libraryAccess,
                                onChanged: (v) => _onToggle(emp, v),
                              ),
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
