import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/OsFinanceController.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/Os/OsServiceModel.dart';
import 'package:point/View/Os/os_form_dialog.dart';
import 'package:point/View/Os/os_snackbar.dart';

Future<void> showOsServiceFormDialog(
  BuildContext context, {
  OsServiceModel? existing,
}) async {
  final nameCtrl = TextEditingController(text: existing?.name ?? '');
  final priceCtrl = TextEditingController(
    text: existing == null
        ? ''
        : existing.basePrice.toStringAsFixed(0),
  );
  var category = existing?.category ?? OsServiceCategory.artisticProduction;
  var priceType = existing?.priceType ?? OsServicePriceType.fixed;

  final saved = await showOsFormDialog(
    context: context,
    title: existing == null
        ? AppLocaleKeys.osServicesAddTitle.tr
        : AppLocaleKeys.osServicesEditTitle.tr,
    titleIcon: existing == null
        ? Icons.design_services_outlined
        : Icons.edit_outlined,
    saveLabel: AppLocaleKeys.osCommonSave.tr,
    builder: (context, setLocal) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          osTypedTextField(
            controller: nameCtrl,
            style: const TextStyle(fontSize: 16),
            decoration: osFinanceFieldDecoration(
              AppLocaleKeys.osServicesName.tr,
              hint: AppLocaleKeys.osServicesNameHint.tr,
            ),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            key: ValueKey(category),
            initialValue: category,
            isExpanded: true,
            decoration: osFinanceFieldDecoration(
              AppLocaleKeys.osServicesCategory.tr,
            ),
            items: [
              for (final c in OsServiceCategory.all)
                DropdownMenuItem(
                  value: c,
                  child: Text(
                    OsServiceCategory.labelKey(c).tr,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (v) {
              if (v != null) setLocal(() => category = v);
            },
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: osTypedTextField(
                  controller: priceCtrl,
                  style: const TextStyle(fontSize: 16),
                  keyboardType: TextInputType.number,
                  decoration: osFinanceFieldDecoration(
                    AppLocaleKeys.osServicesBasePrice.tr,
                    hint: '1500000',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  key: ValueKey(priceType),
                  initialValue: priceType,
                  isExpanded: true,
                  decoration: osFinanceFieldDecoration(
                    AppLocaleKeys.osServicesPriceType.tr,
                  ),
                  items: [
                    for (final t in OsServicePriceType.all)
                      DropdownMenuItem(
                        value: t,
                        child: Text(
                          OsServicePriceType.labelKey(t).tr,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (v) {
                    if (v != null) setLocal(() => priceType = v);
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
    priceCtrl.dispose();
    return;
  }

  final name = nameCtrl.text.trim();
  final price = double.tryParse(priceCtrl.text.trim()) ?? -1;
  nameCtrl.dispose();
  priceCtrl.dispose();

  if (name.isEmpty) {
    OsSnackbar.error(
      AppLocaleKeys.osCommonSaveFailed.tr,
      AppLocaleKeys.osServicesNameRequired.tr,
    );
    return;
  }
  if (price < 0) {
    OsSnackbar.error(
      AppLocaleKeys.osCommonSaveFailed.tr,
      AppLocaleKeys.osServicesPriceRequired.tr,
    );
    return;
  }

  final model = OsServiceModel(
    id: existing?.id,
    name: name,
    category: category,
    basePrice: price,
    priceType: priceType,
    createdAt: existing?.createdAt ?? DateTime.now(),
  );

  final ok = await Get.find<OsFinanceController>().saveService(model);
  if (ok) {
    OsSnackbar.success(AppLocaleKeys.osServicesSaved.tr, name);
  } else {
    OsSnackbar.error(
      AppLocaleKeys.osCommonSaveFailed.tr,
      AppLocaleKeys.errorsOsServicesSave.tr,
    );
  }
}
