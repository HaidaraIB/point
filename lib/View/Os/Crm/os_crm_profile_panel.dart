import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:point/Controller/OsCrmController.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/ClientModel.dart';
import 'package:point/Models/Os/os_crm_enums.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/Utils/app_theme_extension.dart';
import 'package:point/Models/Os/os_crm_activity.dart';
import 'package:point/View/Os/Crm/os_crm_client_form_dialog.dart';
import 'package:point/View/Os/Crm/os_crm_labels.dart';
import 'package:point/View/Os/Crm/os_crm_stage_change.dart';
import 'package:point/View/Os/Contracts/os_legal_contract_form_dialog.dart';
import 'package:point/View/Os/Invoices/os_invoice_form_dialog.dart';
import 'package:point/View/Os/Quotations/os_quotation_form_dialog.dart';
import 'package:point/View/Os/os_button_styles.dart';
import 'package:point/View/Os/os_finance_format.dart';
import 'package:point/View/Os/os_form_dialog.dart';
import 'package:point/View/Os/os_snackbar.dart';
import 'package:url_launcher/url_launcher.dart';

class OsCrmProfilePanel extends StatefulWidget {
  const OsCrmProfilePanel({
    super.key,
    required this.client,
    required this.onBack,
  });

  final ClientModel client;
  final VoidCallback onBack;

  @override
  State<OsCrmProfilePanel> createState() => _OsCrmProfilePanelState();
}

class _OsCrmProfilePanelState extends State<OsCrmProfilePanel> {
  late final TextEditingController _noteCtrl;
  var _savingNote = false;

  @override
  void initState() {
    super.initState();
    _noteCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  OsCrmController get _crm => Get.find<OsCrmController>();

  String get _company => _crm.displayCompany(widget.client);

  Future<void> _changeStage(String newStage) async {
    final current = _crm.effectiveStage(widget.client);
    await confirmAndApplyCrmStageChange(
      context,
      currentStage: current,
      newStage: newStage,
      onApply: () => _crm.updateStage(widget.client.id!, newStage),
    );
  }

  Future<void> _saveNote() async {
    final id = widget.client.id;
    if (id == null || id.isEmpty) return;
    setState(() => _savingNote = true);
    final ok = await _crm.appendNote(id, _noteCtrl.text);
    setState(() => _savingNote = false);
    if (ok) {
      _noteCtrl.clear();
      OsSnackbar.success(
        AppLocaleKeys.osCrmNotesSave.tr,
        _company,
      );
    }
  }

  Future<void> _launch(Uri uri) async {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) {
      OsSnackbar.error(
        AppLocaleKeys.osCommonDash.tr,
        AppLocaleKeys.osCommonSaveFailed.tr,
      );
    }
  }

  Future<void> _launchWhatsapp(String phone) async {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return;
    await _launch(Uri.parse('https://wa.me/$digits'));
  }

  Future<void> _logTouchpoint(String type) async {
    final id = widget.client.id;
    if (id == null || id.isEmpty) return;
    final ok = await _crm.logActivity(id, type, '');
    if (ok) {
      OsSnackbar.success(AppLocaleKeys.osCrmSaved.tr, _company);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final client = _crm.clientById(widget.client.id) ?? widget.client;
      return _buildBody(context, client);
    });
  }

  Widget _buildBody(BuildContext context, ClientModel client) {
    final theme = context.appTheme;
    final stage = _crm.effectiveStage(client);
    final activities = _crm.activityTimeline(client);
    final leadSource = osCrmLeadSourceDisplay(client.leadSource);
    final initial = _company.isNotEmpty ? _company[0].toUpperCase() : '?';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: widget.onBack,
              icon: const Icon(Icons.arrow_back, size: 18),
              label: Text(AppLocaleKeys.osCrmBack.tr),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: osCrmStageColor(stage).withValues(alpha: 0.15),
                child: Text(
                  initial,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: osCrmStageColor(stage),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _company,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: theme.primaryText,
                      ),
                    ),
                    if ((client.name ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        client.name!,
                        style: TextStyle(
                          fontSize: 14,
                          color: theme.secondaryText,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      DateFormat.yMMMd().format(client.createdAt),
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.mutedText,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<String>(
                  key: ValueKey(stage),
                  initialValue: stage,
                  isExpanded: true,
                  decoration: osFinanceFieldDecoration(
                    AppLocaleKeys.osCrmStage.tr,
                  ),
                  items: [
                    for (final s in OsCrmStage.ordered)
                      DropdownMenuItem(
                        value: s,
                        child: osCrmStageMenuItemLabel(s),
                      ),
                  ],
                  onChanged: (v) {
                    if (v != null) _changeStage(v);
                  },
                ),
              ),
            ],
          ),
          if (stage == OsCrmStage.won) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF059669).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFF059669).withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    color: Color(0xFF059669),
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      AppLocaleKeys.osCrmWonBanner.tr,
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.primaryText,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: () => Get.toNamed('/clients'),
                    style: OsButtonStyles.secondaryCompact(theme),
                    child: Text(AppLocaleKeys.osCrmOpenInClients.tr),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, c) {
              final cols = c.maxWidth >= 900 ? 4 : (c.maxWidth >= 560 ? 2 : 1);
              return GridView.count(
                crossAxisCount: cols,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: cols == 1 ? 3.2 : 2.3,
                children: [
                  _KpiCard(
                    title: AppLocaleKeys.osCrmBalance.tr,
                    value: OsFinanceFormat.money(client.balance ?? 0),
                    color: AppColors.caution,
                  ),
                  _KpiCard(
                    title: AppLocaleKeys.osCrmRevenue.tr,
                    value: OsFinanceFormat.money(client.totalRevenue ?? 0),
                    color: AppColors.primary,
                  ),
                  _KpiCard(
                    title: AppLocaleKeys.osCrmAssignee.tr,
                    value: (client.assignedTo ?? AppLocaleKeys.osCommonDash.tr),
                    color: theme.primaryText,
                  ),
                  _KpiCard(
                    title: AppLocaleKeys.osCrmLeadSource.tr,
                    value: leadSource ?? AppLocaleKeys.osCommonDash.tr,
                    color: const Color(0xFF0EA5E9),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: [
              if ((client.phone ?? '').trim().isNotEmpty) ...[
                FilledButton.icon(
                  onPressed: () => _launch(
                    Uri(scheme: 'tel', path: client.phone!.trim()),
                  ),
                  style: OsButtonStyles.secondaryCompact(theme),
                  icon: const Icon(Icons.phone_outlined, size: 16),
                  label: Text(AppLocaleKeys.osCrmCall.tr),
                ),
                FilledButton.icon(
                  onPressed: () => _launchWhatsapp(client.phone!.trim()),
                  style: OsButtonStyles.secondaryCompact(theme),
                  icon: const Icon(Icons.chat_outlined, size: 16),
                  label: Text(AppLocaleKeys.osCrmWhatsapp.tr),
                ),
                OutlinedButton.icon(
                  onPressed: () => _logTouchpoint(OsCrmActivityType.call),
                  icon: const Icon(Icons.history_rounded, size: 16),
                  label: Text(AppLocaleKeys.osCrmActivityLogCall.tr),
                ),
                OutlinedButton.icon(
                  onPressed: () => _logTouchpoint(OsCrmActivityType.whatsapp),
                  icon: const Icon(Icons.history_rounded, size: 16),
                  label: Text(AppLocaleKeys.osCrmActivityLogWhatsapp.tr),
                ),
              ],
              if ((client.email ?? '').trim().isNotEmpty)
                FilledButton.icon(
                  onPressed: () => _launch(
                    Uri(scheme: 'mailto', path: client.email!.trim()),
                  ),
                  style: OsButtonStyles.secondaryCompact(theme),
                  icon: const Icon(Icons.email_outlined, size: 16),
                  label: Text(AppLocaleKeys.osCrmEmailAction.tr),
                ),
              FilledButton.icon(
                onPressed: () => showOsCrmClientFormDialog(
                  context,
                  existing: client,
                ),
                style: OsButtonStyles.secondaryCompact(theme),
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: Text(AppLocaleKeys.osCrmEdit.tr),
              ),
              FilledButton.icon(
                onPressed: () => showOsQuotationFormDialog(
                  context,
                  initialClientId: client.id,
                ),
                style: OsButtonStyles.secondaryCompact(theme),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: Text(AppLocaleKeys.osCrmCreateQuotation.tr),
              ),
              FilledButton.icon(
                onPressed: () => showOsInvoiceFormDialog(
                  context,
                  initialClientId: client.id,
                ),
                style: OsButtonStyles.primaryCompact(),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: Text(AppLocaleKeys.osCrmCreateInvoice.tr),
              ),
              FilledButton.icon(
                onPressed: () => showOsLegalContractFormDialog(
                  context,
                  initialClientId: client.id,
                ),
                style: OsButtonStyles.secondaryCompact(theme),
                icon: const Icon(Icons.description_outlined, size: 16),
                label: Text(AppLocaleKeys.osCrmCreateContract.tr),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            AppLocaleKeys.osCrmActivityTitle.tr,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: theme.primaryText,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _noteCtrl,
            maxLines: 3,
            decoration: osFinanceFieldDecoration(
              AppLocaleKeys.osCrmNotes.tr,
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: FilledButton.icon(
              onPressed: _savingNote ? null : _saveNote,
              style: OsButtonStyles.primaryCompact(),
              icon: _savingNote
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined, size: 16),
              label: Text(AppLocaleKeys.osCrmNotesSave.tr),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            constraints: const BoxConstraints(maxHeight: 250),
            decoration: BoxDecoration(
              border: Border.all(color: theme.border),
              borderRadius: BorderRadius.circular(12),
            ),
            child: activities.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      AppLocaleKeys.osCrmActivityEmpty.tr,
                      style: TextStyle(color: theme.mutedText),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: activities.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final activity = activities[i];
                      final color = osCrmActivityColor(activity.type);
                      final isLatest = i == 0;
                      return Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isLatest
                              ? color.withValues(alpha: 0.08)
                              : theme.inputFill,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isLatest
                                ? color.withValues(alpha: 0.25)
                                : theme.border,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              osCrmActivityIcon(activity.type),
                              size: 18,
                              color: color,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    osCrmActivitySummary(activity),
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: theme.primaryText,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    DateFormat.yMMMd()
                                        .add_jm()
                                        .format(activity.at),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: theme.mutedText,
                                    ),
                                  ),
                                  if ((activity.performedBy ?? '')
                                      .trim()
                                      .isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      activity.performedBy!,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: theme.secondaryText,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.title,
    required this.value,
    required this.color,
  });

  final String title;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: TextStyle(fontSize: 12, color: theme.secondaryText),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
