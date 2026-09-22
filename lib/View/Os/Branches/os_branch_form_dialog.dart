import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/OsFinanceController.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/Os/OsBranchModel.dart';
import 'package:point/Utils/whatsapp_phone.dart';
import 'package:point/View/Os/os_form_dialog.dart';
import 'package:point/View/Os/os_snackbar.dart';
import 'package:point/View/Shared/whatsapp_phone_field.dart';

Future<void> showOsBranchFormDialog(
  BuildContext context, {
  OsBranchModel? existing,
}) async {
  final nameCtrl = TextEditingController(text: existing?.name ?? '');
  final managerCtrl = TextEditingController(text: existing?.manager ?? '');
  final locationCtrl = TextEditingController(text: existing?.location ?? '');
  final phoneCtrl = TextEditingController(text: existing?.phone ?? '');
  var status = existing?.status ?? OsBranchStatus.active;

  final saved = await showOsFormDialog(
    context: context,
    title: existing == null
        ? AppLocaleKeys.osBranchesAddTitle.tr
        : AppLocaleKeys.osBranchesEditTitle.tr,
    titleIcon: existing == null
        ? Icons.apartment_outlined
        : Icons.edit_outlined,
    saveLabel: AppLocaleKeys.osCommonSave.tr,
    builder: (context, setLocal) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: osTypedTextField(
                  controller: nameCtrl,
                  style: const TextStyle(fontSize: 16),
                  decoration: osFinanceFieldDecoration(
                    AppLocaleKeys.osBranchesName.tr,
                    hint: AppLocaleKeys.osBranchesNameHint.tr,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: osTypedTextField(
                  controller: managerCtrl,
                  style: const TextStyle(fontSize: 16),
                  decoration: osFinanceFieldDecoration(
                    AppLocaleKeys.osBranchesManager.tr,
                    hint: AppLocaleKeys.osBranchesManagerHint.tr,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          osTypedTextField(
            controller: locationCtrl,
            style: const TextStyle(fontSize: 16),
            decoration: osFinanceFieldDecoration(
              AppLocaleKeys.osBranchesLocation.tr,
              hint: AppLocaleKeys.osBranchesLocationHint.tr,
            ).copyWith(
              prefixIcon: const Icon(Icons.place_outlined, size: 18),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: WhatsappPhoneField(
                  initialNormalized: phoneCtrl.text.trim().isEmpty
                      ? null
                      : phoneCtrl.text.trim(),
                  decoration: osFinanceFieldDecoration(
                    AppLocaleKeys.osBranchesPhone.tr,
                  ),
                  onChanged: (v) => phoneCtrl.text = v ?? '',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  key: ValueKey(status),
                  initialValue: status,
                  isExpanded: true,
                  decoration: osFinanceFieldDecoration(
                    AppLocaleKeys.osBranchesStatus.tr,
                  ),
                  items: [
                    DropdownMenuItem(
                      value: OsBranchStatus.active,
                      child: Text(
                        AppLocaleKeys.osBranchesStatusActive.tr,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    DropdownMenuItem(
                      value: OsBranchStatus.inactive,
                      child: Text(
                        AppLocaleKeys.osBranchesStatusInactive.tr,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) setLocal(() => status = v);
                  },
                ),
              ),
            ],
          ),
        ],
      );
    },
  );

  if (saved != true) {
    nameCtrl.dispose();
    managerCtrl.dispose();
    locationCtrl.dispose();
    phoneCtrl.dispose();
    return;
  }

  final name = nameCtrl.text.trim();
  final location = locationCtrl.text.trim();
  final manager = managerCtrl.text.trim();
  final phone = normalizeWhatsappPhone(phoneCtrl.text.trim()) ??
      phoneCtrl.text.trim();
  nameCtrl.dispose();
  managerCtrl.dispose();
  locationCtrl.dispose();
  phoneCtrl.dispose();

  if (name.isEmpty) {
    OsSnackbar.error(
      AppLocaleKeys.osCommonSaveFailed.tr,
      AppLocaleKeys.osBranchesNameRequired.tr,
    );
    return;
  }
  if (location.isEmpty) {
    OsSnackbar.error(
      AppLocaleKeys.osCommonSaveFailed.tr,
      AppLocaleKeys.osBranchesLocationRequired.tr,
    );
    return;
  }

  final model = OsBranchModel(
    id: existing?.id,
    name: name,
    location: location,
    manager: manager,
    phone: phone,
    status: status,
    color: existing?.color,
    createdAt: existing?.createdAt ?? DateTime.now(),
  );

  final ok = await Get.find<OsFinanceController>().saveBranch(model);
  if (ok) {
    OsSnackbar.success(
      AppLocaleKeys.osBranchesSaved.tr,
      name,
    );
  } else {
    OsSnackbar.error(
      AppLocaleKeys.osCommonSaveFailed.tr,
      AppLocaleKeys.errorsOsBranchesSave.tr,
    );
  }
}
