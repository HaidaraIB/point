import 'package:flutter_test/flutter_test.dart';
import 'package:point/Models/Os/OsWhatsappLogModel.dart';
import 'package:point/Utils/os_whatsapp_template_vars.dart';

OsWhatsappTemplateModel _templateWithBody(String bodyText) {
  return OsWhatsappTemplateModel.fromJson({
    'name': 'test_template',
    'status': 'APPROVED',
    'category': 'UTILITY',
    'language': 'ar',
    'components': [
      {'type': 'BODY', 'text': bodyText},
    ],
  });
}

OsWhatsappTemplateModel _templateWithPayUrlButton({
  String bodyText = 'Pay: {{1}}',
  String buttonUrl =
      'https://agency.point-iq.app/pay.html?t={{1}}',
}) {
  return OsWhatsappTemplateModel.fromJson({
    'name': 'invoice_pay',
    'status': 'APPROVED',
    'category': 'UTILITY',
    'language': 'ar',
    'components': [
      {'type': 'BODY', 'text': bodyText},
      {
        'type': 'BUTTONS',
        'buttons': [
          {
            'type': 'URL',
            'text': 'Pay',
            'url': buttonUrl,
          },
        ],
      },
    ],
  });
}

void main() {
  test('extracts named and numbered placeholders', () {
    final t = _templateWithBody(
      'Hello {{customer_name}}, invoice {{1}} for {{total_amount}}',
    );
    final list = osWhatsappExtractPlaceholders(t);
    expect(list.length, 3);
    expect(list[0].token, 'customer_name');
    expect(list[0].isNamed, isTrue);
    expect(list[1].token, '1');
    expect(list[1].isNamed, isFalse);
    expect(list[2].token, 'total_amount');
  });

  test('buildGraphParameters includes parameter_name for named tokens only', () {
    final t = _templateWithBody(
      'Hi {{customer_name}}, ref {{2}}',
    );
    final built = osWhatsappBuildGraphParameters(t, {
      'customer_name': 'Acme',
      '2': 'INV-9',
    });
    expect(built.body.length, 2);
    expect(built.body[0].isNamed, isTrue);
    expect(built.body[0].toJson()['parameter_name'], 'customer_name');
    expect(built.body[1].isNamed, isFalse);
    expect(built.body[1].toJson().containsKey('parameter_name'), isFalse);
  });

  test('substitute replaces named tokens in preview text', () {
    const text = 'Dear {{customer_name}}, total {{total_amount}}';
    final out = osWhatsappSubstitutePlaceholders(text, {
      'customer_name': 'Sara',
      'total_amount': '500 IQD',
    });
    expect(out, contains('Sara'));
    expect(out, contains('500 IQD'));
    expect(out, isNot(contains('{{')));
  });

  test('url button parameter uses pay token suffix from full payment link', () {
    const templateUrl = 'https://agency.point-iq.app/pay.html?t={{1}}';
    const fullLink =
        'https://agency.point-iq.app/pay.html?t=AbCdEfGh12';
    final suffix = osWhatsappUrlButtonParameterValue(
      templateButtonUrl: templateUrl,
      token: '1',
      resolvedValue: fullLink,
    );
    expect(suffix, 'AbCdEfGh12');
  });

  test('buildGraphParameters keeps full pay URL in body and token on button',
      () {
    final t = _templateWithPayUrlButton();
    const fullLink =
        'https://agency.point-iq.app/pay.html?t=TokenXyZ99';
    final built = osWhatsappBuildGraphParameters(t, {'1': fullLink});
    expect(built.body.single.text, fullLink);
    expect(built.buttonUrlByIndex[0]!.single.text, 'TokenXyZ99');
  });

  test('static pay.html button is detected when URL has no placeholder', () {
    final staticBtn = _templateWithPayUrlButton(
      buttonUrl: 'https://agency.point-iq.app/pay.html?t=FixedSample',
    );
    expect(osWhatsappHasStaticPayHtmlButton(staticBtn), isTrue);

    final dynamicBtn = _templateWithPayUrlButton();
    expect(osWhatsappHasStaticPayHtmlButton(dynamicBtn), isFalse);
  });
}
