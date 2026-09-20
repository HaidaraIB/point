import 'package:flutter_test/flutter_test.dart';
import 'package:point/Services/os_ai_service.dart';

void main() {
  group('OsAiService.parseSettingsFromResponse', () {
    test('parses configured settings payload', () {
      final status = OsAiService.parseSettingsFromResponse({
        'success': true,
        'hasGeminiKey': true,
        'keyPreview': 'AIza••••wxyz',
        'source': 'firestore',
        'configuredInFirestore': true,
        'configuredInEnv': false,
      });
      expect(status, isNotNull);
      expect(status!.hasGeminiKey, isTrue);
      expect(status.keyPreview, 'AIza••••wxyz');
      expect(status.source, 'firestore');
      expect(status.configuredInFirestore, isTrue);
    });

    test('returns null when success is false', () {
      expect(
        OsAiService.parseSettingsFromResponse({
          'success': false,
          'hasGeminiKey': true,
        }),
        isNull,
      );
    });
  });

  group('OsAiService.parseTextFromResponse', () {
    test('returns trimmed text when success is true', () {
      expect(
        OsAiService.parseTextFromResponse({
          'success': true,
          'text': '  وصف تسويقي  ',
          'source': 'gemini',
        }),
        'وصف تسويقي',
      );
    });

    test('returns null when success is false', () {
      expect(
        OsAiService.parseTextFromResponse({
          'success': false,
          'text': 'ignored',
        }),
        isNull,
      );
    });

    test('returns null for malformed payloads', () {
      expect(OsAiService.parseTextFromResponse(null), isNull);
      expect(OsAiService.parseTextFromResponse('text'), isNull);
      expect(
        OsAiService.parseTextFromResponse({'success': true, 'text': '   '}),
        isNull,
      );
    });
  });

  group('OsAiService fallbacks', () {
    test('serviceDescriptionFallback includes service name', () {
      final text = OsAiService.serviceDescriptionFallback('تصوير احترافي');
      expect(text, contains('تصوير احترافي'));
      expect(text, contains('وكالة نقطة'));
    });

    test('financialSummaryFallback includes revenue', () {
      const input = OsAiFinancialSummaryInput(
        totalRevenue: 5000000,
        clientCount: 10,
        wonClients: 4,
        activeProjects: 3,
      );
      final text = OsAiService.financialSummaryFallback(input);
      expect(text, contains('5000000'));
      expect(text, contains('د.ع'));
    });

    test('localFinancialInsight computes conversion rate', () {
      const input = OsAiFinancialSummaryInput(
        totalRevenue: 1000000,
        clientCount: 10,
        wonClients: 5,
        activeProjects: 2,
      );
      final text = OsAiService.localFinancialInsight(input);
      expect(text, contains('50%'));
      expect(text, contains('2'));
    });

    test('contractTitleFallback includes target and template', () {
      const input = OsAiContractInput(
        targetName: 'شركة بابل',
        templateTitle: 'إدارة السوشيال ميديا',
      );
      final text = OsAiService.contractTitleFallback(input);
      expect(text, contains('شركة بابل'));
      expect(text, contains('إدارة السوشيال ميديا'));
    });

    test('contractScopeFallback includes value', () {
      const input = OsAiContractInput(
        contractTitle: 'إنتاج فيديو',
        targetName: 'عميل',
        totalValue: 5000000,
        currency: 'IQD',
      );
      final text = OsAiService.contractScopeFallback(input);
      expect(text, contains('5000000'));
      expect(text, contains('د.ع'));
    });

    test('contractClauseFallback includes clause title', () {
      const input = OsAiContractInput(clauseTitle: 'السرية');
      final text = OsAiService.contractClauseFallback(input);
      expect(text, contains('السرية'));
    });

    test('parsePaymentScheduleText builds terms from JSON', () {
      const json =
          '[{"milestone":"دفعة أولى","percentage":60,"dueDateDescription":"توقيع"}]';
      final terms = OsAiService.parsePaymentScheduleText(json, 1000000);
      expect(terms, isNotNull);
      expect(terms!.length, 1);
      expect(terms.first.percentage, 60);
      expect(terms.first.amount, 600000);
    });

    test('contractJurisdictionFallback uses employee courts for employees', () {
      const input = OsAiContractInput(targetType: 'EMPLOYEE');
      final text = OsAiService.contractJurisdictionFallback(input);
      expect(text, contains('العمل'));
    });
  });
}
