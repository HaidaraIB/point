import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/OsCrmController.dart';
import 'package:point/Controller/OsFinanceController.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Services/os_ai_service.dart';

/// Dashboard AI financial insight panel (point_os parity).
class OsAiInsightPanel extends StatefulWidget {
  const OsAiInsightPanel({super.key});

  @override
  State<OsAiInsightPanel> createState() => _OsAiInsightPanelState();
}

class _OsAiInsightPanelState extends State<OsAiInsightPanel> {
  late String _insight;
  bool _isGenerating = false;
  bool _autoFetched = false;

  OsAiFinancialSummaryInput _buildInput({bool recalculating = false}) {
    final finance = Get.find<OsFinanceController>();
    final crm = Get.find<OsCrmController>();
    return OsAiFinancialSummaryInput(
      totalRevenue: finance.totalInvoiced,
      clientCount: crm.clients.length,
      wonClients: crm.wonClientsCount,
      activeProjects: crm.pipelineActiveCount,
      recalculating: recalculating,
    );
  }

  @override
  void initState() {
    super.initState();
    _insight = OsAiService.localFinancialInsight(_buildInput());
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoFetchOnce());
  }

  Future<void> _autoFetchOnce() async {
    if (_autoFetched) return;
    _autoFetched = true;
    await _fetchInsight(recalculating: false);
  }

  Future<void> _fetchInsight({required bool recalculating}) async {
    if (_isGenerating) return;
    setState(() => _isGenerating = true);
    try {
      final input = _buildInput(recalculating: recalculating);
      final text = await OsAiService.instance.summarizeFinancials(data: input);
      if (mounted && text.trim().isNotEmpty) {
        setState(() => _insight = text);
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            const Color(0xFF312E81),
            const Color(0xFF1E1B4B),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF4338CA).withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF312E81).withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.bolt_outlined,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  AppLocaleKeys.osAiDashboardTitle.tr,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 120, maxHeight: 180),
            child: SingleChildScrollView(
              child: Text(
                _insight,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.88),
                  fontSize: 13,
                  height: 1.55,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: _isGenerating
                ? null
                : () => _fetchInsight(recalculating: true),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: BorderSide(color: Colors.white.withValues(alpha: 0.35)),
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isGenerating) ...[
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Text(
                  _isGenerating
                      ? AppLocaleKeys.osAiDashboardGenerating.tr
                      : AppLocaleKeys.osAiDashboardRegenerate.tr,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
