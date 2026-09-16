import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Controller/OsCrmController.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/ClientModel.dart';
import 'package:point/Models/Os/os_crm_enums.dart';
import 'package:point/View/Os/Crm/os_crm_labels.dart';
import 'package:point/View/Os/os_form_dialog.dart';
import 'package:point/View/Os/os_snackbar.dart';

Future<void> showOsCrmClientFormDialog(
  BuildContext context, {
  String? initialStage,
  ClientModel? existing,
}) async {
  final companyCtrl = TextEditingController(text: existing?.company ?? '');
  final nameCtrl = TextEditingController(text: existing?.name ?? '');
  final phoneCtrl = TextEditingController(text: existing?.phone ?? '');
  final emailCtrl = TextEditingController(text: existing?.email ?? '');
  var stage = OsCrmStage.effective(initialStage ?? existing?.crmStage);
  String? leadSource = existing?.leadSource;
  String? employeeId = existing?.assignedEmployeeId;

  final saved = await showOsFormDialog(
    context: context,
    title: existing == null
        ? AppLocaleKeys.osCrmAddTitle.tr
        : AppLocaleKeys.osCrmEditTitle.tr,
    titleIcon: existing == null
        ? Icons.person_add_outlined
        : Icons.edit_outlined,
    saveLabel: AppLocaleKeys.osCommonSave.tr,
    builder: (context, setLocal) {
      final home = Get.find<HomeController>();
      final employees = home.employees
          .where((e) => (e.id ?? '').isNotEmpty)
          .toList();

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: companyCtrl,
                  style: const TextStyle(fontSize: 16),
                  decoration: osFinanceFieldDecoration(
                    AppLocaleKeys.osCrmCompany.tr,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: nameCtrl,
                  style: const TextStyle(fontSize: 16),
                  decoration: osFinanceFieldDecoration(
                    AppLocaleKeys.osCrmContactName.tr,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: phoneCtrl,
                  style: const TextStyle(fontSize: 16),
                  textDirection: TextDirection.ltr,
                  keyboardType: TextInputType.phone,
                  decoration: osFinanceFieldDecoration(
                    AppLocaleKeys.osCrmPhone.tr,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: emailCtrl,
                  style: const TextStyle(fontSize: 16),
                  textDirection: TextDirection.ltr,
                  keyboardType: TextInputType.emailAddress,
                  decoration: osFinanceFieldDecoration(
                    AppLocaleKeys.osCrmEmail.tr,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  key: ValueKey(stage),
                  initialValue: stage,
                  isExpanded: true,
                  decoration: osFinanceFieldDecoration(
                    AppLocaleKeys.osCrmStage.tr,
                  ),
                  items: [
                    for (final s in OsCrmStage.ordered)
                      DropdownMenuItem(
                        value: s,
                        child: Text(
                          osCrmStageLabel(s),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (v) {
                    if (v != null) setLocal(() => stage = v);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String?>(
                  key: ValueKey(employeeId),
                  initialValue: employeeId,
                  isExpanded: true,
                  decoration: osFinanceFieldDecoration(
                    AppLocaleKeys.osCrmAssignee.tr,
                  ),
                  items: [
                    DropdownMenuItem<String?>(
                      value: null,
                      child: Text(AppLocaleKeys.osCommonDash.tr),
                    ),
                    for (final e in employees)
                      DropdownMenuItem<String?>(
                        value: e.id,
                        child: Text(
                          e.name ?? AppLocaleKeys.osCommonDash.tr,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (v) => setLocal(() => employeeId = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String?>(
            key: ValueKey(leadSource),
            initialValue: leadSource,
            isExpanded: true,
            decoration: osFinanceFieldDecoration(
              AppLocaleKeys.osCrmLeadSource.tr,
            ),
            items: [
              DropdownMenuItem<String?>(
                value: null,
                child: Text(AppLocaleKeys.osCommonDash.tr),
              ),
              for (final s in OsLeadSource.all)
                DropdownMenuItem<String?>(
                  value: s,
                  child: Text(osCrmLeadSourceLabel(s)),
                ),
            ],
            onChanged: (v) => setLocal(() => leadSource = v),
          ),
        ],
      );
    },
  );

  if (saved != true) {
    companyCtrl.dispose();
    nameCtrl.dispose();
    phoneCtrl.dispose();
    emailCtrl.dispose();
    return;
  }

  final company = companyCtrl.text.trim();
  final contactName = nameCtrl.text.trim();
  final phone = phoneCtrl.text.trim();
  final email = emailCtrl.text.trim();
  companyCtrl.dispose();
  nameCtrl.dispose();
  phoneCtrl.dispose();
  emailCtrl.dispose();

  if (company.isEmpty) {
    OsSnackbar.error(
      AppLocaleKeys.osCommonSaveFailed.tr,
      AppLocaleKeys.osCrmCompanyRequired.tr,
    );
    return;
  }
  if (contactName.isEmpty) {
    OsSnackbar.error(
      AppLocaleKeys.osCommonSaveFailed.tr,
      AppLocaleKeys.osCrmContactRequired.tr,
    );
    return;
  }

  final home = Get.find<HomeController>();
  final employee = home.employees.firstWhereOrNull((e) => e.id == employeeId);
  final crm = Get.find<OsCrmController>();

  if (existing != null) {
    final ok = await crm.updateCrmClient(
      existing.copyWith(
        company: company,
        name: contactName,
        phone: phone.isEmpty ? null : phone,
        email: email.isEmpty ? null : email,
        crmStage: stage,
        leadSource: leadSource,
        assignedEmployeeId: employeeId,
        assignedTo: employee?.name,
      ),
    );
    if (ok) {
      OsSnackbar.success(AppLocaleKeys.osCrmSaved.tr, company);
    } else {
      OsSnackbar.error(
        AppLocaleKeys.osCommonSaveFailed.tr,
        'client.errors.email_in_use_cross'.tr,
      );
    }
    return;
  }

  final ok = await crm.addCrmClient(
    company: company,
    contactName: contactName,
    phone: phone.isEmpty ? null : phone,
    email: email.isEmpty ? null : email,
    crmStage: stage,
    leadSource: leadSource,
    assignedTo: employee?.name,
    assignedEmployeeId: employeeId,
  );
  if (ok) {
    OsSnackbar.success(AppLocaleKeys.osCrmSaved.tr, company);
  } else {
    OsSnackbar.error(
      AppLocaleKeys.osCommonSaveFailed.tr,
      'client.errors.email_in_use_cross'.tr,
    );
  }
}
