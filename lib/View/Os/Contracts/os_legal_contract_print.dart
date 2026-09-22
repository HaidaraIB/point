import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:point/Controller/OsLegalContractsController.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/Os/OsLegalContractModel.dart';
import 'package:point/View/Os/Contracts/os_legal_contract_print_text.dart';
import 'package:point/View/Os/Print/os_print_assets.dart';
import 'package:point/View/Os/os_print_document.dart';
import 'package:point/View/Os/os_print_pdf.dart';
import 'package:point/View/Os/os_snackbar.dart';

/// Opens a print-friendly contract HTML document (web) or copies plain text.
Future<void> printOsLegalContract(OsLegalContractModel contract) async {
  await OsPrintAssets.ensureLoaded();
  final settings = Get.find<OsLegalContractsController>().settings.value;
  return openOsPrintDocument(
    html: buildOsLegalContractPrintHtml(contract, settings),
    titleKey: AppLocaleKeys.osLegalContractTitle,
    fallbackKey: AppLocaleKeys.osLegalContractPrintHint,
    onUnsupported: () async {
      final text = buildOsLegalContractPlainText(contract, settings);
      await Clipboard.setData(ClipboardData(text: text));
      OsSnackbar.success(
        AppLocaleKeys.osLegalContractTitle.tr,
        AppLocaleKeys.osLegalContractPrintHint.tr,
      );
    },
  );
}

String osLegalContractPdfFilename(OsLegalContractModel contract) {
  final num = contract.contractNumber.trim();
  final ref = num.isNotEmpty ? num : contract.id;
  final safe = ref.replaceAll(RegExp(r'[^\w\-]+'), '_');
  return 'contract-$safe.pdf';
}

Future<Uint8List?> generateOsLegalContractPdfBytes(
  OsLegalContractModel contract,
) async {
  if (!kIsWeb) return null;
  await OsPrintAssets.ensureLoaded();
  final settings = Get.find<OsLegalContractsController>().settings.value;
  return generateOsPrintPdfBytesFromPrintHtml(
    buildOsLegalContractPrintHtml(contract, settings, forPdf: true),
  );
}

Future<void> downloadOsLegalContractPdf(OsLegalContractModel contract) async {
  await OsPrintAssets.ensureLoaded();
  final settings = Get.find<OsLegalContractsController>().settings.value;
  await downloadOsPrintPdf(
    printHtml: buildOsLegalContractPrintHtml(contract, settings, forPdf: true),
    fileName: osLegalContractPdfFilename(contract),
    titleKey: AppLocaleKeys.osLegalContractTitle,
  );
}
