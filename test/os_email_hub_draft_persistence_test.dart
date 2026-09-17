import 'package:flutter_test/flutter_test.dart';
import 'package:point/Services/os_email_hub_draft_persistence.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('draft map round-trips through shared preferences', () async {
    const draft = {
      'invoiceRecipientEmail': 'client@example.com',
      'invoiceCustomNote': 'Please pay soon',
      'selectedInvoiceId': 'inv-1',
      'payslipMonth': 'March 2026',
      'payslipPaymentMethod': 'Cash',
      'payslipAllowances': 200000,
      'appreciationType': 'SPEED',
      'logsSearch': 'invoice',
      'logsCategoryFilter': 'INVOICE',
    };

    await OsEmailHubDraftPersistence.save(draft);
    final restored = await OsEmailHubDraftPersistence.load();

    expect(restored, draft);
  });
}
