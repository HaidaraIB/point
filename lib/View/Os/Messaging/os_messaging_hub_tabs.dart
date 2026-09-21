import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/OsWhatsappHubController.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/ClientModel.dart';
import 'package:point/Models/Os/OsInvoiceModel.dart';
import 'package:point/Models/Os/OsWhatsappLogModel.dart';
import 'package:point/Models/Os/os_whatsapp_enums.dart';
import 'package:point/Utils/app_theme_extension.dart';
import 'package:point/View/Os/EmailHub/OsEmailHubPage.dart';
import 'package:point/View/Os/EmailHub/os_email_hub_form_widgets.dart';
import 'package:point/View/Os/Messaging/os_whatsapp_log_display.dart';
import 'package:point/View/Os/Messaging/os_whatsapp_message_preview.dart';
import 'package:point/View/Shared/phone_number_text.dart';
import 'package:point/View/Shared/responsive.dart';

List<Widget> osMessagingHubTemplateFields(
  BuildContext context,
  OsWhatsappHubController hub,
) {
  final t = hub.selectedTemplate;
  if (t == null) return const [];
  final widgets = <Widget>[];
  if (hub.headerParameters.isNotEmpty || hub.bodyParameters.isNotEmpty) {
    widgets.add(
      Text(
        AppLocaleKeys.osMessagingHubTemplateParams.tr,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: context.appTheme.secondaryText,
          fontSize: 12,
        ),
      ),
    );
    widgets.add(const SizedBox(height: 8));
  }
  for (var i = 0; i < hub.headerParameters.length; i++) {
    final index = i;
    widgets.add(
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: osEmailHubTextField(
          context,
          label: AppLocaleKeys.osMessagingHubHeaderParam.trParams({
            'index': '${index + 1}',
          }),
          value: hub.headerParameters[index],
          onChanged: (v) {
            hub.headerParameters[index] = v;
            hub.headerParameters.refresh();
          },
        ),
      ),
    );
  }
  for (var i = 0; i < hub.bodyParameters.length; i++) {
    final index = i;
    widgets.add(
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: osEmailHubTextField(
          context,
          label: AppLocaleKeys.osMessagingHubBodyParam.trParams({
            'index': '${index + 1}',
          }),
          value: hub.bodyParameters[index],
          onChanged: (v) {
            hub.bodyParameters[index] = v;
            hub.bodyParameters.refresh();
          },
        ),
      ),
    );
  }
  return widgets;
}

Widget osMessagingHubSessionHintBanner(
  BuildContext context,
  OsWhatsappHubController hub,
) {
  final theme = context.appTheme;
  return Obx(() {
    final blocked = hub.isSessionSendBlocked(OsWhatsappHubSendMode.session);
    final checking = hub.isCheckingSessionWindow.value;
    final open = hub.sessionWindowOpen.value;
    final color = checking
        ? theme.secondaryText
        : (open
            ? const Color(0xFF059669)
            : (blocked ? const Color(0xFFE11D48) : theme.secondaryText));
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              hub.buildSessionWindowHintText(),
              style: TextStyle(
                fontSize: 12,
                height: 1.45,
                color: theme.secondaryText,
              ),
            ),
          ),
        ],
      ),
    );
  });
}

Widget osMessagingHubSendModeChips({
  required BuildContext context,
  required String selectedMode,
  required ValueChanged<String> onModeChanged,
  required bool templateEnabled,
}) {
  final theme = context.appTheme;
  return Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      ChoiceChip(
        label: Text(AppLocaleKeys.osMessagingHubSendModeTemplate.tr),
        selected: selectedMode == OsWhatsappHubSendMode.template,
        onSelected: templateEnabled
            ? (_) => onModeChanged(OsWhatsappHubSendMode.template)
            : null,
        selectedColor: theme.accentText.withValues(alpha: 0.18),
      ),
      ChoiceChip(
        label: Text(AppLocaleKeys.osMessagingHubSendModeSession.tr),
        selected: selectedMode == OsWhatsappHubSendMode.session,
        onSelected: (_) => onModeChanged(OsWhatsappHubSendMode.session),
        selectedColor: theme.accentText.withValues(alpha: 0.18),
      ),
    ],
  );
}

Widget osMessagingHubPreviewBox(
  BuildContext context,
  OsWhatsappHubController hub,
) {
  final theme = context.appTheme;
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        AppLocaleKeys.osMessagingHubPreview.tr,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: theme.secondaryText,
        ),
      ),
      const SizedBox(height: 6),
      Obx(
        () {
          final t = hub.selectedTemplate;
          final doc = hub.previewDocumentFilename;
          final docInHeader = t?.hasDocumentHeader == true;
          final main = osMessagingHubWhatsappPreview(
            context,
            t,
            headerParameters: hub.headerParameters.toList(),
            bodyParameters: hub.bodyParameters.toList(),
            documentFilename: docInHeader ? doc : null,
          );
          if (hub.previewShowsFollowUpInvoicePdf &&
              doc != null &&
              doc.isNotEmpty) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                main,
                const SizedBox(height: 8),
                osWhatsappSessionHubPreview(
                  context,
                  text: '',
                  documentFilename: doc,
                ),
              ],
            );
          }
          return main;
        },
      ),
    ],
  );
}

class OsMessagingHubSendTab extends StatelessWidget {
  const OsMessagingHubSendTab({super.key, required this.hub});

  final OsWhatsappHubController hub;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (hub.isLoadingTemplates.value &&
          hub.templates.isEmpty &&
          !hub.isApiReady) {
        return const Center(child: CircularProgressIndicator());
      }

      final sessionOnly = hub.crmSafeTemplates.isEmpty;
      final crmMode = sessionOnly
          ? OsWhatsappHubSendMode.session
          : hub.crmSendMode.value;

      return OsEmailHubDispatchPanel(
        icon: Icons.chat_outlined,
        title: AppLocaleKeys.osMessagingHubTabSend.tr,
        subtitle: AppLocaleKeys.osMessagingHubSubtitle.tr,
        isSending: hub.isSending.value,
        sendEnabled: !hub.isSessionSendBlocked(crmMode),
        onSend: hub.sendFromSendTab,
        sendLabel: AppLocaleKeys.osMessagingHubSend.tr,
        children: _formFields(
          context,
          sessionOnly: sessionOnly,
          crmMode: crmMode,
        ),
      );
    });
  }

  List<Widget> _formFields(
    BuildContext context, {
    required bool sessionOnly,
    required String crmMode,
  }) {
    final clients = hub.clients;
    ClientModel? selectedClient;
    final cid = hub.selectedClientId.value;
    if (cid != null) {
      selectedClient = hub.clientById(cid);
    }

    return [
      if (clients.isNotEmpty)
        osEmailHubDocumentDropdown<ClientModel>(
          context: context,
          label: AppLocaleKeys.osMessagingHubSelectClient.tr,
          value: selectedClient,
          items: clients,
          itemLabel: (c) => c.name?.trim().isNotEmpty == true
              ? c.name!.trim()
              : (c.company?.trim() ?? c.id ?? ''),
          onChanged: (c) => hub.selectClient(c?.id),
        ),
      const SizedBox(height: 12),
      osEmailHubTextField(
        context,
        label: AppLocaleKeys.osMessagingHubRecipientPhone.tr,
        value: hub.recipientPhone.value,
        onChanged: (v) => hub.recipientPhone.value = v,
        keyboardType: TextInputType.phone,
      ),
      const SizedBox(height: 12),
      if (!sessionOnly) ...[
        osMessagingHubSendModeChips(
          context: context,
          selectedMode: hub.crmSendMode.value,
          onModeChanged: hub.setCrmSendMode,
          templateEnabled: hub.crmSafeTemplates.isNotEmpty,
        ),
        const SizedBox(height: 12),
      ],
      if (crmMode == OsWhatsappHubSendMode.session) ...[
        osMessagingHubSessionHintBanner(context, hub),
        const SizedBox(height: 12),
        osEmailHubTextField(
          context,
          label: AppLocaleKeys.osMessagingHubSessionMessage.tr,
          value: hub.sessionMessageText.value,
          onChanged: (v) => hub.sessionMessageText.value = v,
          maxLines: 5,
        ),
        const SizedBox(height: 12),
        Text(
          AppLocaleKeys.osMessagingHubPreview.tr,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: context.appTheme.secondaryText,
          ),
        ),
        const SizedBox(height: 6),
        osWhatsappSessionHubPreview(
          context,
          text: hub.sessionMessageText.value,
        ),
      ] else ...[
        if (hub.crmSafeTemplates.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              AppLocaleKeys.osMessagingHubNoTemplates.tr,
              style: TextStyle(color: context.appTheme.secondaryText),
            ),
          )
        else ...[
          osEmailHubDocumentDropdown<OsWhatsappTemplateModel>(
            context: context,
            label: AppLocaleKeys.osMessagingHubSelectTemplate.tr,
            value: hub.selectedTemplate,
            items: hub.crmSafeTemplates,
            itemLabel: (t) => '${t.name} (${t.language})',
            onChanged: (t) => hub.selectTemplate(t?.name),
          ),
          const SizedBox(height: 12),
          ...osMessagingHubTemplateFields(context, hub),
          const SizedBox(height: 12),
          osMessagingHubPreviewBox(context, hub),
        ],
      ],
    ];
  }
}

class OsMessagingHubInvoicesTab extends StatelessWidget {
  const OsMessagingHubInvoicesTab({super.key, required this.hub});

  final OsWhatsappHubController hub;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (hub.isLoadingTemplates.value && hub.templates.isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }
      final invoices = hub.unpaidInvoices;
      if (invoices.isEmpty) {
        return OsEmailHubDispatchPanel(
          icon: Icons.receipt_long_outlined,
          title: AppLocaleKeys.osMessagingHubTabInvoices.tr,
          subtitle: AppLocaleKeys.osMessagingHubInvoiceSubtitle.tr,
          isSending: hub.isSending.value,
          onSend: () async {},
          emptyMessage: AppLocaleKeys.osMessagingHubNoInvoices.tr,
          children: const [],
        );
      }

      final sessionOnly = !hub.canUseInvoiceTemplateMode;
      final invoiceMode = sessionOnly
          ? OsWhatsappHubSendMode.session
          : hub.invoiceSendMode.value;

      final inv = hub.selectedInvoice;
      return OsEmailHubDispatchPanel(
        icon: Icons.receipt_long_outlined,
        title: AppLocaleKeys.osMessagingHubTabInvoices.tr,
        subtitle: AppLocaleKeys.osMessagingHubInvoiceSubtitle.tr,
        isSending: hub.isSending.value,
        sendEnabled: !hub.isSessionSendBlocked(invoiceMode),
        onSend: hub.sendFromInvoiceTab,
        sendLabel: AppLocaleKeys.osMessagingHubSend.tr,
        children: [
          if (!sessionOnly) ...[
            osMessagingHubSendModeChips(
              context: context,
              selectedMode: hub.invoiceSendMode.value,
              onModeChanged: hub.setInvoiceSendMode,
              templateEnabled: true,
            ),
            const SizedBox(height: 12),
          ],
          osEmailHubDocumentDropdown<OsInvoiceModel>(
            context: context,
            label: AppLocaleKeys.osMessagingHubSelectInvoice.tr,
            value: inv,
            items: invoices,
            itemLabel: hub.invoiceListLabel,
            onChanged: (v) => hub.selectInvoice(v?.id),
          ),
          const SizedBox(height: 12),
          osEmailHubTextField(
            context,
            label: AppLocaleKeys.osMessagingHubRecipientPhone.tr,
            value: hub.recipientPhone.value,
            onChanged: (v) => hub.recipientPhone.value = v,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 12),
          if (invoiceMode == OsWhatsappHubSendMode.session) ...[
            osMessagingHubSessionHintBanner(context, hub),
            const SizedBox(height: 12),
            osEmailHubTextField(
              context,
              label: AppLocaleKeys.osMessagingHubSessionMessage.tr,
              value: hub.sessionMessageText.value,
              onChanged: (v) => hub.sessionMessageText.value = v,
              maxLines: 5,
            ),
            const SizedBox(height: 12),
            Text(
              AppLocaleKeys.osMessagingHubPreview.tr,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: context.appTheme.secondaryText,
              ),
            ),
            const SizedBox(height: 6),
            osWhatsappSessionHubPreview(
              context,
              text: hub.sessionMessageText.value,
              documentFilename: hub.sessionPreviewDocumentFilename,
            ),
          ] else ...[
            osEmailHubDocumentDropdown<OsWhatsappTemplateModel>(
              context: context,
              label: AppLocaleKeys.osMessagingHubSelectTemplate.tr,
              value: hub.selectedInvoiceSafeTemplate,
              items: hub.invoiceSafeTemplates,
              itemLabel: (t) => '${t.name} (${t.language})',
              onChanged: (t) => hub.selectTemplate(t?.name),
            ),
            const SizedBox(height: 12),
            ...osMessagingHubTemplateFields(context, hub),
            const SizedBox(height: 12),
            osMessagingHubPreviewBox(context, hub),
          ],
        ],
      );
    });
  }
}

class OsMessagingHubLogsTab extends StatelessWidget {
  const OsMessagingHubLogsTab({super.key, required this.hub});

  final OsWhatsappHubController hub;

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    final compact = Responsive.isMobile(context);
    return Obx(() {
      final items = hub.logs;
      if (items.isEmpty) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.history_rounded,
                  size: 48,
                  color: theme.mutedText.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  AppLocaleKeys.osMessagingHubLogsEmpty.tr,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: theme.secondaryText,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        );
      }

      return ListView.separated(
        padding: EdgeInsets.fromLTRB(
          compact ? 12 : 16,
          12,
          compact ? 12 : 16,
          24,
        ),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          return _WhatsappLogEntryCard(
            log: items[index],
            templates: hub.templates.toList(),
          );
        },
      );
    });
  }
}

class _WhatsappLogEntryCard extends StatelessWidget {
  const _WhatsappLogEntryCard({
    required this.log,
    required this.templates,
  });

  final OsWhatsappLogModel log;
  final List<OsWhatsappTemplateModel> templates;

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    final failed = log.status == OsWhatsappLogStatus.failed;
    final accent = failed ? const Color(0xFFE11D48) : const Color(0xFF059669);
    final category = osWhatsappLogCategoryLabel(log.type);
    final errorText = failed && log.errorMessage.isNotEmpty
        ? whatsappLogErrorForUi(log.errorMessage)
        : null;

    return Material(
      color: theme.cardSurface,
      elevation: 0,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.border),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(11),
            border: BorderDirectional(
              start: BorderSide(color: accent, width: 3),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    _WhatsappLogStatusChip(failed: failed),
                    const SizedBox(width: 8),
                    _WhatsappLogCategoryChip(label: category),
                    if (osWhatsappLogAttachmentFilename(log) != null) ...[
                      const SizedBox(width: 8),
                      _WhatsappLogAttachmentChip(
                        label: osWhatsappLogAttachmentFilename(log)!,
                      ),
                    ],
                    const Spacer(),
                    Text(
                      formatWhatsappLogDate(log.sentAt),
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.mutedText,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      log.type.toUpperCase() == OsWhatsappCategory.invoice
                          ? Icons.receipt_long_outlined
                          : Icons.chat_outlined,
                      size: 20,
                      color: theme.accentText,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (log.recipientName.trim().isNotEmpty)
                            Text(
                              log.recipientName.trim(),
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: theme.primaryText,
                              ),
                            ),
                          if (log.recipientPhone.trim().isNotEmpty) ...[
                            if (log.recipientName.trim().isNotEmpty)
                              const SizedBox(height: 2),
                            PhoneNumberText(
                              log.recipientPhone,
                              style: TextStyle(
                                fontSize: 13,
                                color: theme.secondaryText,
                              ),
                            ),
                          ],
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                Icons.article_outlined,
                                size: 14,
                                color: theme.mutedText,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  osWhatsappLogTemplateLabel(log.templateName),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: theme.secondaryText,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (log.preview.trim().isNotEmpty ||
                    osWhatsappTemplateForLog(templates, log) != null) ...[
                  const SizedBox(height: 10),
                  osWhatsappLogMessagePreview(context, log, templates),
                ],
                if (errorText != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE11D48).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFFE11D48).withValues(alpha: 0.22),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          size: 18,
                          color: Color(0xFFE11D48),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            errorText,
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.4,
                              color: theme.primaryText,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WhatsappLogStatusChip extends StatelessWidget {
  const _WhatsappLogStatusChip({required this.failed});

  final bool failed;

  @override
  Widget build(BuildContext context) {
    final color =
        failed ? const Color(0xFFE11D48) : const Color(0xFF059669);
    final bg = color.withValues(alpha: 0.12);
    final label = failed
        ? AppLocaleKeys.osMessagingHubStatusFailed.tr
        : AppLocaleKeys.osMessagingHubStatusSent.tr;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            failed ? Icons.cancel_rounded : Icons.check_circle_rounded,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _WhatsappLogCategoryChip extends StatelessWidget {
  const _WhatsappLogCategoryChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.panelTint,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: theme.border),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: theme.secondaryText,
        ),
      ),
    );
  }
}

class _WhatsappLogAttachmentChip extends StatelessWidget {
  const _WhatsappLogAttachmentChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFEA0038).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: const Color(0xFFEA0038).withValues(alpha: 0.28),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.picture_as_pdf_rounded,
            size: 14,
            color: Color(0xFFEA0038),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFFEA0038),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
