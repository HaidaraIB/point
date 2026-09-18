import 'package:get/get.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/Os/OsLegalContractModel.dart';
import 'package:point/Models/Os/os_email_enums.dart';
import 'package:point/Services/firestore/firestore_os_email_api.dart';
import 'package:point/Services/firestore/firestore_os_finance_api.dart';
import 'package:point/Services/os_email_hub_service.dart';
import 'package:point/View/Os/Contracts/os_legal_contract_labels.dart';
import 'package:point/View/Os/os_snackbar.dart';

/// Sends the official contract copy to party two and logs it in the email hub.
Future<bool> sendOsLegalContractEmail(OsLegalContractModel contract) async {
  final email = contract.partyTwoEmail.trim();
  if (email.isEmpty) {
    OsSnackbar.error(
      AppLocaleKeys.osLegalContractTitle.tr,
      AppLocaleKeys.osLegalContractErrorNoEmail.tr,
    );
    return false;
  }

  final start = FirestoreOsFinanceApi.formatDate(contract.startDate);
  final amount =
      osLegalContractMoneyLabel(contract.totalValue, contract.currency);

  final subject = AppLocaleKeys.osLegalContractEmailSubject.trParams({
    'title': contract.title,
    'number': contract.contractNumber,
  });
  final body = AppLocaleKeys.osLegalContractEmailBody.trParams({
    'number': contract.contractNumber,
    'start': start,
    'amount': amount,
  });

  try {
    final settings = await FirestoreOsEmailApi.loadSettings();
    final ok = await OsEmailHubService.sendAndLog(
      type: OsEmailCategory.contract,
      toEmail: email,
      recipientName: contract.targetName,
      subject: subject,
      content: body,
      settings: settings,
      referenceId: contract.contractNumber,
      attachmentsCount: 1,
    );
    if (ok) {
      OsSnackbar.success(
        AppLocaleKeys.osLegalContractTitle.tr,
        AppLocaleKeys.osLegalContractEmailSent.trParams({'email': email}),
      );
    } else {
      OsSnackbar.error(
        AppLocaleKeys.osLegalContractTitle.tr,
        AppLocaleKeys.osLegalContractErrorEmailFailed.tr,
      );
    }
    return ok;
  } catch (_) {
    OsSnackbar.error(
      AppLocaleKeys.osLegalContractTitle.tr,
      AppLocaleKeys.osLegalContractErrorEmailFailed.tr,
    );
    return false;
  }
}
