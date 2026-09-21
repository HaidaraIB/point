import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/Os/OsWhatsappLogModel.dart';
import 'package:point/Models/Os/os_whatsapp_enums.dart';
import 'package:point/Utils/app_theme_extension.dart';
import 'package:point/View/Os/Messaging/os_whatsapp_log_display.dart';

class WhatsappTemplateButtonPreview {
  const WhatsappTemplateButtonPreview({
    required this.type,
    required this.text,
    this.url,
    this.phoneNumber,
  });

  final String type;
  final String text;
  final String? url;
  final String? phoneNumber;
}

class WhatsappTemplatePreviewContent {
  const WhatsappTemplatePreviewContent({
    this.headerFormat,
    this.headerText,
    this.bodyText = '',
    this.footerText,
    this.buttons = const [],
    this.documentLabel,
  });

  final String? headerFormat;
  final String? headerText;
  final String bodyText;
  final String? footerText;
  final List<WhatsappTemplateButtonPreview> buttons;
  final String? documentLabel;

  static WhatsappTemplatePreviewContent fromTemplate(OsWhatsappTemplateModel t) {
    String? headerFormat;
    String? headerText;
    var bodyText = t.previewBodyText();
    String? footerText;
    final buttons = <WhatsappTemplateButtonPreview>[];

    for (final raw in t.components) {
      final comp = _componentMap(raw);
      if (comp == null) continue;
      final type = (comp['type'] as String?)?.toUpperCase() ?? '';
      if (type == 'HEADER') {
        headerFormat = (comp['format'] as String?)?.toUpperCase() ?? 'TEXT';
        if (headerFormat == 'TEXT') {
          headerText = (comp['text'] as String?)?.trim();
        }
      } else if (type == 'BODY') {
        final text = (comp['text'] as String?)?.trim();
        if (text != null && text.isNotEmpty) bodyText = text;
      } else if (type == 'FOOTER') {
        footerText = (comp['text'] as String?)?.trim();
      } else if (type == 'CALL_PERMISSION_REQUEST') {
        buttons.add(
          WhatsappTemplateButtonPreview(
            type: 'CALL_PERMISSION_REQUEST',
            text: (comp['text'] as String?)?.trim() ?? '',
          ),
        );
      } else if (type == 'BUTTONS') {
        final list = comp['buttons'];
        if (list is List) {
          for (final btn in list) {
            final btnMap = _componentMap(btn);
            if (btnMap == null) continue;
            buttons.add(
              WhatsappTemplateButtonPreview(
                type: (btnMap['type'] as String?)?.toUpperCase() ?? '',
                text: (btnMap['text'] as String?)?.trim() ?? '',
                url: (btnMap['url'] as String?)?.trim(),
                phoneNumber: (btnMap['phone_number'] as String?)?.trim(),
              ),
            );
          }
        }
      }
    }

    return WhatsappTemplatePreviewContent(
      headerFormat: headerFormat,
      headerText: headerText,
      bodyText: bodyText,
      footerText: footerText,
      buttons: buttons,
    );
  }

  WhatsappTemplatePreviewContent applyParameters({
    List<String> headerParameters = const [],
    List<String> bodyParameters = const [],
    String? documentLabel,
  }) {
    return WhatsappTemplatePreviewContent(
      headerFormat: headerFormat,
      headerText: _substitute(headerText ?? '', headerParameters),
      bodyText: _substitute(bodyText, bodyParameters),
      footerText: footerText,
      buttons: buttons,
      documentLabel: documentLabel,
    );
  }

  static Map<String, dynamic>? _componentMap(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return null;
  }

  static String _substitute(String text, List<String> params) {
    var out = text;
    for (var i = 0; i < params.length; i++) {
      out = out.replaceAll('{{${i + 1}}}', params[i]);
    }
    return out;
  }
}

/// WhatsApp-style template message preview (header, body, footer, buttons).
class OsWhatsappMessagePreview extends StatelessWidget {
  const OsWhatsappMessagePreview({
    super.key,
    required this.content,
  });

  final WhatsappTemplatePreviewContent content;

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final chatBg = isDark ? const Color(0xFF0B141A) : const Color(0xFFE5DDD5);
    final bubbleColor = isDark ? const Color(0xFF1F2C34) : Colors.white;
    final metaColor = isDark ? const Color(0xFF8696A0) : const Color(0xFF667781);
    final linkColor = isDark ? const Color(0xFF53BDEB) : const Color(0xFF027EB5);
    final primaryText =
        isDark ? const Color(0xFFE9EDEF) : const Color(0xFF111B21);

    final hasHeader = _hasHeaderBlock(content);
    final hasBody = content.bodyText.trim().isNotEmpty;
    final hasFooter =
        content.footerText != null && content.footerText!.trim().isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: chatBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.border.withValues(alpha: 0.6)),
      ),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: Material(
            color: bubbleColor,
            elevation: 0,
            borderRadius: BorderRadius.circular(8),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasHeader)
                  _HeaderSection(
                    content: content,
                    metaColor: metaColor,
                    primaryText: primaryText,
                  ),
                if (hasBody || hasFooter)
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      10,
                      hasHeader ? 6 : 10,
                      10,
                      hasFooter ? 4 : 8,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (hasBody)
                          Text(
                            content.bodyText.trim(),
                            style: TextStyle(
                              fontSize: 14.5,
                              height: 1.35,
                              color: primaryText,
                            ),
                          ),
                        if (hasFooter) ...[
                          if (hasBody) const SizedBox(height: 6),
                          Text(
                            content.footerText!.trim(),
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.3,
                              color: metaColor,
                            ),
                          ),
                        ],
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Align(
                            alignment: AlignmentDirectional.centerEnd,
                            child: Text(
                              _fakeTime(),
                              style: TextStyle(
                                fontSize: 11,
                                color: metaColor,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (content.buttons.isNotEmpty)
                  ...content.buttons.map(
                    (btn) => _ButtonRow(
                      button: btn,
                      linkColor: linkColor,
                      dividerColor: theme.border.withValues(alpha: 0.5),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool _hasHeaderBlock(WhatsappTemplatePreviewContent c) {
    final fmt = c.headerFormat?.toUpperCase();
    if (fmt == 'DOCUMENT') return true;
    if (fmt == 'IMAGE' || fmt == 'VIDEO') return true;
    if (fmt == 'TEXT' && (c.headerText ?? '').trim().isNotEmpty) return true;
    return false;
  }

  String _fakeTime() {
    final now = DateTime.now();
    final h = now.hour.toString().padLeft(2, '0');
    final m = now.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class _HeaderSection extends StatelessWidget {
  const _HeaderSection({
    required this.content,
    required this.metaColor,
    required this.primaryText,
  });

  final WhatsappTemplatePreviewContent content;
  final Color metaColor;
  final Color primaryText;

  @override
  Widget build(BuildContext context) {
    final fmt = content.headerFormat?.toUpperCase() ?? 'TEXT';
    if (fmt == 'DOCUMENT') {
      final name = content.documentLabel?.trim().isNotEmpty == true
          ? content.documentLabel!.trim()
          : AppLocaleKeys.osMessagingHubPreviewDocument.tr;
      return Container(
        color: const Color(0xFF8696A0).withValues(alpha: 0.12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFEA0038).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Icon(
                Icons.picture_as_pdf_rounded,
                color: Color(0xFFEA0038),
                size: 26,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: primaryText,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'PDF',
                    style: TextStyle(fontSize: 11, color: metaColor),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    if (fmt == 'IMAGE' || fmt == 'VIDEO') {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: ColoredBox(
          color: const Color(0xFF8696A0).withValues(alpha: 0.2),
          child: Icon(
            fmt == 'VIDEO' ? Icons.videocam_outlined : Icons.image_outlined,
            size: 40,
            color: metaColor,
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
      child: Text(
        content.headerText!.trim(),
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          height: 1.3,
          color: primaryText,
        ),
      ),
    );
  }
}

class _ButtonRow extends StatelessWidget {
  const _ButtonRow({
    required this.button,
    required this.linkColor,
    required this.dividerColor,
  });

  final WhatsappTemplateButtonPreview button;
  final Color linkColor;
  final Color dividerColor;

  @override
  Widget build(BuildContext context) {
    final type = button.type;
    IconData icon;
    String label;

    switch (type) {
      case 'URL':
        icon = Icons.open_in_new_rounded;
        label = button.text.isNotEmpty
            ? button.text
            : AppLocaleKeys.osMessagingHubPreviewBtnUrl.tr;
      case 'PHONE_NUMBER':
        icon = Icons.phone_rounded;
        label = button.text.isNotEmpty
            ? button.text
            : (button.phoneNumber ?? AppLocaleKeys.osMessagingHubPreviewBtnCall.tr);
      case 'CALL_PERMISSION_REQUEST':
        icon = Icons.phone_in_talk_rounded;
        label = button.text.isNotEmpty
            ? button.text
            : AppLocaleKeys.osMessagingHubPreviewBtnCallPermission.tr;
      case 'VOICE_CALL':
        icon = Icons.call_rounded;
        label = button.text.isNotEmpty
            ? button.text
            : AppLocaleKeys.osMessagingHubPreviewBtnCall.tr;
      case 'QUICK_REPLY':
        icon = Icons.reply_rounded;
        label = button.text.isNotEmpty
            ? button.text
            : AppLocaleKeys.osMessagingHubPreviewBtnQuickReply.tr;
      default:
        icon = Icons.touch_app_outlined;
        label = button.text.isNotEmpty ? button.text : type;
    }

    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: dividerColor)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: linkColor),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: linkColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Widget osWhatsappSessionHubPreview(
  BuildContext context, {
  required String text,
  String? documentFilename,
}) {
  final trimmed = text.trim();
  if (trimmed.isEmpty && (documentFilename == null || documentFilename.isEmpty)) {
    final theme = context.appTheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.panelTint,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.border),
      ),
      child: Text(
        '—',
        style: TextStyle(color: theme.secondaryText),
      ),
    );
  }
  final content = WhatsappTemplatePreviewContent(
    headerFormat:
        documentFilename != null && documentFilename.isNotEmpty ? 'DOCUMENT' : null,
    bodyText: trimmed,
    documentLabel: documentFilename,
  );
  return OsWhatsappMessagePreview(content: content);
}

Widget osMessagingHubWhatsappPreview(
  BuildContext context,
  OsWhatsappTemplateModel? template, {
  List<String> headerParameters = const [],
  List<String> bodyParameters = const [],
  String? documentFilename,
}) {
  final theme = context.appTheme;
  if (template == null) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.panelTint,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.border),
      ),
      child: Text(
        '—',
        style: TextStyle(color: theme.secondaryText),
      ),
    );
  }

  final base = WhatsappTemplatePreviewContent.fromTemplate(template);
  final content = base.applyParameters(
    headerParameters: headerParameters,
    bodyParameters: bodyParameters,
    documentLabel: template.hasDocumentHeader ? documentFilename : null,
  );

  return OsWhatsappMessagePreview(content: content);
}

OsWhatsappTemplateModel? osWhatsappTemplateForLog(
  List<OsWhatsappTemplateModel> templates,
  OsWhatsappLogModel log,
) {
  final name = log.templateName.trim().toLowerCase();
  if (name.isEmpty) return null;
  final lang = log.languageCode.trim().toLowerCase();
  OsWhatsappTemplateModel? fallback;
  for (final t in templates) {
    if (t.name.trim().toLowerCase() != name) continue;
    fallback ??= t;
    if (lang.isEmpty) return t;
    if (t.language.trim().toLowerCase() == lang) return t;
  }
  return fallback;
}

Widget osWhatsappLogMessagePreview(
  BuildContext context,
  OsWhatsappLogModel log,
  List<OsWhatsappTemplateModel> templates,
) {
  final theme = context.appTheme;
  final attach = osWhatsappLogAttachmentFilename(log);

  if (log.templateName.trim().toUpperCase() ==
      OsWhatsappLogTemplateName.session) {
    return osWhatsappSessionHubPreview(
      context,
      text: log.preview.trim(),
      documentFilename: attach,
    );
  }

  final template = osWhatsappTemplateForLog(templates, log);
  if (template != null) {
    final base = WhatsappTemplatePreviewContent.fromTemplate(template);
    final body = log.preview.trim();
    final useDocHeader = template.hasDocumentHeader && attach != null;
    final content = WhatsappTemplatePreviewContent(
      headerFormat: useDocHeader ? 'DOCUMENT' : base.headerFormat,
      headerText: useDocHeader ? null : base.headerText,
      bodyText: body.isNotEmpty ? body : base.bodyText,
      footerText: base.footerText,
      buttons: base.buttons,
      documentLabel: useDocHeader ? attach : base.documentLabel,
    );
    final followUp = osWhatsappLogShowsFollowUpAttachment(template, log);
    if (followUp && attach != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OsWhatsappMessagePreview(content: content),
          const SizedBox(height: 8),
          osWhatsappSessionHubPreview(
            context,
            text: '',
            documentFilename: attach,
          ),
        ],
      );
    }
    return OsWhatsappMessagePreview(content: content);
  }

  if (attach != null) {
    return osWhatsappSessionHubPreview(
      context,
      text: log.preview.trim(),
      documentFilename: attach,
    );
  }

  if (log.preview.trim().isEmpty) return const SizedBox.shrink();
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: theme.panelTint,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: theme.border),
    ),
    child: Text(
      log.preview.trim(),
      maxLines: 6,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 13,
        height: 1.45,
        color: theme.primaryText,
      ),
    ),
  );
}
