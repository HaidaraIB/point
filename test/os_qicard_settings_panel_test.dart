import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:point/Localization/AppTranslations.dart';
import 'package:point/Models/Os/OsQicardSettingsStatus.dart';
import 'package:point/Services/os_qicard_service.dart';
import 'package:point/View/Os/os_qicard_settings_panel.dart';

const _savedPem = '''-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAiZZE6p1CYskphgm9SM2Y
Ot0jGATECil95naErtyXRi1Gq96Fxh8Y7wM5Q7YFomKRyyjFZWDTDhF1gL5FXYmV
BAtlYUwlOdlFznW7J7Z4193JsyEYFvsW9b+jhdu+mG/tgfeDzX+Pp1nAzCzrGv3P
xxwHiN6FrL6LvKUoBqH9gQCLfoIgTClqAI38f3xLHyJwUSyCEiuq9nUKxwX+qTSS
azlIPbgVL9KwHP7Hieac5Wb+bbuYTyfQETWZnnh8qY/v7s5gNl3ljuV5P1EHdNLk
Oc0ny8DD6EaXcGwJsiyMrA0+gQnQm0z3M4J+nO+R+NWrorSHnBgqpBiK91kMh/xZ
hQIDAQAB
-----END PUBLIC KEY-----''';

OsQicardSettingsStatus _status({
  String environment = 'test',
  bool hasPassword = false,
  String webhookPublicKey = '',
}) =>
    OsQicardSettingsStatus(
      enabled: false,
      environment: environment,
      username: '',
      terminalId: '',
      currency: 'IQD',
      bankAccountId: '',
      liveApiBase: '',
      hasPassword: hasPassword,
      passwordPreview: '',
      hasWebhookPublicKey: webhookPublicKey.isNotEmpty,
      webhookPublicKeyPreview: '',
      webhookPublicKey: webhookPublicKey,
      configuredInFirestore: false,
    );

Future<void> _pump(WidgetTester tester, OsQicardSettingsStatus status) async {
  OsQicardService.instance.debugCachedSettings = status;
  await tester.binding.setSurfaceSize(const Size(600, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    GetMaterialApp(
      translations: AppTranslations(),
      locale: const Locale('en'),
      home: const Scaffold(
        body: SingleChildScrollView(child: OsQicardSettingsPanel()),
      ),
    ),
  );
  await tester.pump();
}

Finder _pemField() => find.descendant(
      of: find.byWidgetPredicate(
        (w) => w.runtimeType.toString() == '_QicardPemField',
      ),
      matching: find.byType(TextField),
    );

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  tearDown(() => OsQicardService.instance.debugCachedSettings = null);

  testWidgets('save with empty credentials shows inline required errors',
      (tester) async {
    await _pump(tester, _status());
    expect(find.text('This field is required'), findsNothing);
    await tester.tap(find.text('Save Qi Card settings'));
    await tester.pump();
    // username, password (none saved yet) and terminal id
    expect(find.text('This field is required'), findsNWidgets(3));
  });

  testWidgets('password is optional once one is saved', (tester) async {
    await _pump(tester, _status(hasPassword: true));
    await tester.tap(find.text('Save Qi Card settings'));
    await tester.pump();
    expect(find.text('This field is required'), findsNWidgets(2));
  });

  testWidgets('pasting a private key is flagged immediately', (tester) async {
    await _pump(tester, _status());
    await tester.enterText(
      _pemField(),
      '-----BEGIN PRIVATE KEY-----\nAAAA\n-----END PRIVATE KEY-----',
    );
    await tester.pump();
    expect(find.textContaining('This is a private key'), findsOneWidget);
  });

  testWidgets('key states: saved, edited, cleared', (tester) async {
    await _pump(tester, _status(webhookPublicKey: _savedPem));
    expect(
      find.text('Saved. Incoming webhooks are signature-checked.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Clear'));
    await tester.pump();
    expect(
      find.text('Saving will remove the saved key and stop signature checks.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Restore saved key'));
    await tester.pump();
    expect(
      find.text('Saved. Incoming webhooks are signature-checked.'),
      findsOneWidget,
    );
    expect(find.text('Restore saved key'), findsNothing);

    await tester.enterText(_pemField(), 'not a key');
    // Format errors wait until the field loses focus.
    expect(find.textContaining("isn't a valid public key"), findsNothing);
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    expect(find.textContaining("isn't a valid public key"), findsOneWidget);
  });

  testWidgets('live base URL: preview and https validation', (tester) async {
    await _pump(tester, _status(environment: 'live'));
    expect(
      find.textContaining('Requests will go to https://3ds-api.qi.iq/api/v1'),
      findsOneWidget,
    );

    final baseField = find.widgetWithText(TextField, 'Live API base URL');
    await tester.enterText(baseField, 'https://custom-qi.example/api/v1/');
    await tester.pump();
    expect(
      find.textContaining('Requests will go to https://custom-qi.example/api/v1'),
      findsOneWidget,
    );

    await tester.enterText(baseField, 'http://3ds-api.qi.iq');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    expect(find.textContaining('Enter a full https:// address'), findsOneWidget);
  });
}
