import 'package:firebase_auth/firebase_auth.dart';
import 'package:point/Models/Os/OsAiSettingsStatus.dart';
import 'package:point/Utils/EdgeFunctionRateLimiter.dart';
import 'package:point/Utils/app_log.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const String _functionName = 'os-ai';

/// Context for contract AI field generation.
class OsAiContractInput {
  const OsAiContractInput({
    this.contractTitle = '',
    this.targetType = '',
    this.targetName = '',
    this.templateTitle = '',
    this.totalValue = 0,
    this.currency = 'IQD',
    this.clauseTitle = '',
    this.clauseContent = '',
    this.startDate = '',
    this.endDate = '',
  });

  final String contractTitle;
  final String targetType;
  final String targetName;
  final String templateTitle;
  final double totalValue;
  final String currency;
  final String clauseTitle;
  final String clauseContent;
  final String startDate;
  final String endDate;

  Map<String, dynamic> toJson() => {
    if (contractTitle.trim().isNotEmpty) 'contractTitle': contractTitle.trim(),
    if (targetType.trim().isNotEmpty) 'targetType': targetType.trim(),
    if (targetName.trim().isNotEmpty) 'targetName': targetName.trim(),
    if (templateTitle.trim().isNotEmpty) 'templateTitle': templateTitle.trim(),
    if (totalValue > 0) 'totalValue': totalValue,
    if (currency.trim().isNotEmpty) 'currency': currency.trim(),
    if (clauseTitle.trim().isNotEmpty) 'clauseTitle': clauseTitle.trim(),
    if (clauseContent.trim().isNotEmpty) 'clauseContent': clauseContent.trim(),
    if (startDate.trim().isNotEmpty) 'startDate': startDate.trim(),
    if (endDate.trim().isNotEmpty) 'endDate': endDate.trim(),
  };
}

/// Finance KPIs sent to the OS AI summarize action.
class OsAiFinancialSummaryInput {
  const OsAiFinancialSummaryInput({
    required this.totalRevenue,
    required this.clientCount,
    required this.wonClients,
    required this.activeProjects,
    this.recalculating = false,
  });

  final double totalRevenue;
  final int clientCount;
  final int wonClients;
  final int activeProjects;
  final bool recalculating;

  Map<String, dynamic> toJson() => {
    'totalRevenue': totalRevenue,
    'clientCount': clientCount,
    'wonClients': wonClients,
    'activeProjects': activeProjects,
    if (recalculating) 'recalculating': true,
  };
}

/// Client for Point OS AI suggestions via Supabase Edge Function `os-ai`.
class OsAiService {
  OsAiService._();
  static final OsAiService instance = OsAiService._();

  static String serviceDescriptionFallback(String serviceName) {
    return 'خدمة $serviceName من وكالة نقطة: حل إبداعي متكامل مصمم خصيصاً لتعزيز حضور علامتكم التجارية وتحقيق أثر ملموس لجمهوركم المستهدف.';
  }

  static String financialSummaryFallback(OsAiFinancialSummaryInput data) {
    final rev = data.totalRevenue.toStringAsFixed(0);
    return 'تحليل الأداء المالي لوكالة نقطة: إجمالي إيرادات مسجلة $rev د.ع مع نشاط مستمر في خط المشاريع. يُنصح بمتابعة تحصيل الدفعات المستحقة وتوسيع حزم الخدمات لتأمين تدفقات نقدية مستمرة.';
  }

  static String contractTitleFallback(OsAiContractInput input) {
    final target = input.targetName.trim().isEmpty
        ? 'الطرف الثاني'
        : input.targetName.trim();
    final template = input.templateTitle.trim().isNotEmpty
        ? input.templateTitle.trim()
        : (input.contractTitle.trim().isNotEmpty
            ? input.contractTitle.trim()
            : 'خدمات إبداعية');
    return 'عقد $template — $target';
  }

  static String contractScopeFallback(OsAiContractInput input) {
    final target = input.targetName.trim().isEmpty
        ? 'العميل'
        : input.targetName.trim();
    final title = input.contractTitle.trim().isNotEmpty
        ? input.contractTitle.trim()
        : 'الخدمات الإبداعية';
    final value = input.totalValue.toStringAsFixed(0);
    final money = input.currency.trim().toUpperCase() == 'USD'
        ? '$value \$'
        : '$value د.ع';
    return 'يلتزم الطرف الأول (وكالة نقطة) بتنفيذ $title للطرف الثاني ($target) وفق المواصفات المعتمدة، بقيمة إجمالية قدرها $money، وتشمل المخرجات الإبداعية والتنسيق والمتابعة حتى الاعتماد النهائي.';
  }

  static String contractClauseFallback(OsAiContractInput input) {
    final clauseTitle = input.clauseTitle.trim().isEmpty
        ? 'بند تعاقدي'
        : input.clauseTitle.trim();
    return 'اتفق الطرفان على $clauseTitle بما يتوافق مع القوانين العراقية النافذة وبنود هذا العقد، ويلتزمان بتنفيذه بحسن نية ودون إخلال بالحقوق والالتزامات المتبادلة.';
  }

  static String localFinancialInsight(OsAiFinancialSummaryInput data) {
    final rev = data.totalRevenue.toStringAsFixed(0);
    final conv = data.clientCount > 0
        ? ((data.wonClients / data.clientCount) * 100).round()
        : 0;
    return 'يُظهر الأداء المالي لوكالة نقطة استقراراً تشغيلياً ملحوظاً بإجمالي مطالبات وفواتير مسجلة $rev د.ع، مع نسبة إغلاق صفقات بلغت $conv% وإدارة ${data.activeProjects} مشاريع جارية ونشطة. يُنصح بالتركيز على تحصيل الدفعات المستحقة وتوسيع باقات الإنتاج والتسويق لتعظيم التدفقات النقدية.';
  }

  /// Parses `{ success, ...settings }` from get/save-settings responses.
  static OsAiSettingsStatus? parseSettingsFromResponse(dynamic data) {
    if (data is! Map) return null;
    final map = Map<String, dynamic>.from(data);
    if (map['success'] != true) return null;
    return OsAiSettingsStatus.fromJson(map);
  }

  /// Parses `{ success, text }` from the os-ai Edge Function response body.
  static String? parseTextFromResponse(dynamic data) {
    if (data is! Map) return null;
    final map = Map<String, dynamic>.from(data);
    if (map['success'] != true) return null;
    final text = map['text'];
    if (text is! String) return null;
    final trimmed = text.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  Future<String> generateServiceDescription({
    required String serviceName,
    required String categoryLabel,
  }) async {
    final name = serviceName.trim().isEmpty ? 'خدمة إبداعية' : serviceName.trim();
    final category = categoryLabel.trim().isEmpty
        ? 'الإنتاج الإبداعي'
        : categoryLabel.trim();

    try {
      final text = await _invoke(
        body: {
          'action': 'service-description',
          'serviceName': name,
          'category': category,
        },
      );
      if (text != null) return text;
    } catch (e, st) {
      appLog('OsAiService.generateServiceDescription failed: $e\n$st');
    }
    return serviceDescriptionFallback(name);
  }

  Future<String> generateContractTitle({required OsAiContractInput input}) {
    return _generateContractField(field: 'title', input: input);
  }

  Future<String> generateContractScope({required OsAiContractInput input}) {
    return _generateContractField(field: 'scope', input: input);
  }

  Future<String> generateContractClause({required OsAiContractInput input}) {
    return _generateContractField(field: 'clause', input: input);
  }

  Future<String> _generateContractField({
    required String field,
    required OsAiContractInput input,
  }) async {
    try {
      final text = await _invoke(
        body: {
          'action': 'contract-field',
          'field': field,
          'context': input.toJson(),
        },
      );
      if (text != null) return text;
    } catch (e, st) {
      appLog('OsAiService._generateContractField($field) failed: $e\n$st');
    }
    switch (field) {
      case 'title':
        return contractTitleFallback(input);
      case 'scope':
        return contractScopeFallback(input);
      case 'clause':
        return contractClauseFallback(input);
      default:
        return '';
    }
  }

  Future<OsAiSettingsStatus> loadSettings() async {
    try {
      final data = await _invokeRaw(
        body: {'action': 'get-settings'},
      );
      final status = parseSettingsFromResponse(data);
      if (status != null) return status;
    } catch (e, st) {
      appLog('OsAiService.loadSettings failed: $e\n$st');
    }
    return OsAiSettingsStatus.empty();
  }

  Future<OsAiSettingsStatus?> saveGeminiApiKey(String apiKey) async {
    try {
      final data = await _invokeRaw(
        body: {
          'action': 'save-settings',
          'geminiApiKey': apiKey.trim(),
        },
      );
      if (data is Map &&
          data['errorCode'] == 'ERR_INVALID_API_KEY') {
        return null;
      }
      return parseSettingsFromResponse(data);
    } catch (e, st) {
      appLog('OsAiService.saveGeminiApiKey failed: $e\n$st');
      return null;
    }
  }

  Future<String> summarizeFinancials({
    required OsAiFinancialSummaryInput data,
  }) async {
    try {
      final text = await _invoke(
        body: {
          'action': 'summarize',
          'data': data.toJson(),
        },
      );
      if (text != null) return text;
    } catch (e, st) {
      appLog('OsAiService.summarizeFinancials failed: $e\n$st');
    }
    return financialSummaryFallback(data);
  }

  Future<String?> _invoke({required Map<String, dynamic> body}) async {
    final data = await _invokeRaw(body: body);
    return parseTextFromResponse(data);
  }

  Future<dynamic> _invokeRaw({required Map<String, dynamic> body}) async {
    final firebaseIdToken = await FirebaseAuth.instance.currentUser?.getIdToken();
    if (firebaseIdToken == null || firebaseIdToken.isEmpty) {
      throw StateError('Not authenticated');
    }

    final res = await EdgeFunctionRateLimiter.instance.run(() {
      return Supabase.instance.client.functions.invoke(
        _functionName,
        headers: <String, String>{
          'x-firebase-id-token': 'Bearer $firebaseIdToken',
        },
        body: body,
      );
    });

    final data = res.data;
    if (res.status == 403 ||
        (data is Map && data['errorCode'] == 'ERR_FORBIDDEN')) {
      throw StateError('Forbidden');
    }

    return data;
  }
}
