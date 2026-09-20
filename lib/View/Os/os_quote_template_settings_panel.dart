import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Services/os_quote_template_settings.dart';
import 'package:point/Utils/app_theme_extension.dart';
import 'package:point/View/Os/os_form_dialog.dart';

/// Default header/footer text for digital quotation previews and print.
class OsQuoteTemplateSettingsPanel extends StatefulWidget {
  const OsQuoteTemplateSettingsPanel({super.key});

  @override
  State<OsQuoteTemplateSettingsPanel> createState() =>
      _OsQuoteTemplateSettingsPanelState();
}

class _OsQuoteTemplateSettingsPanelState
    extends State<OsQuoteTemplateSettingsPanel> {
  late final TextEditingController _headerCtrl;
  late final TextEditingController _footerCtrl;
  Worker? _templateWorker;

  OsQuoteTemplateController get _template =>
      Get.find<OsQuoteTemplateController>();

  @override
  void initState() {
    super.initState();
    _headerCtrl = TextEditingController(text: _template.headerText.value);
    _footerCtrl = TextEditingController(text: _template.footerText.value);
    _templateWorker = everAll(
      [_template.headerText, _template.footerText],
      (_) => _syncFromTemplate(),
    );
  }

  @override
  void dispose() {
    _templateWorker?.dispose();
    _headerCtrl.dispose();
    _footerCtrl.dispose();
    super.dispose();
  }

  void _syncFromTemplate() {
    final header = _template.headerText.value;
    final footer = _template.footerText.value;
    if (_headerCtrl.text != header) _headerCtrl.text = header;
    if (_footerCtrl.text != footer) _footerCtrl.text = footer;
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;

    Widget headerField() => osTypedTextField(
          controller: _headerCtrl,
          decoration: osFinanceFieldDecoration(
            AppLocaleKeys.osQuotationsTemplateHeader.tr,
          ),
          onChanged: _template.setHeaderText,
        );

    Widget footerField() => osTypedTextField(
          controller: _footerCtrl,
          decoration: osFinanceFieldDecoration(
            AppLocaleKeys.osQuotationsTemplateFooter.tr,
          ),
          onChanged: _template.setFooterText,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          AppLocaleKeys.osSettingsQuotationTemplateDescription.tr,
          style: TextStyle(
            fontSize: 13,
            height: 1.5,
            color: theme.secondaryText,
          ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 640;
            if (wide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: headerField()),
                  const SizedBox(width: 12),
                  Expanded(child: footerField()),
                ],
              );
            }
            return Column(
              children: [
                headerField(),
                const SizedBox(height: 12),
                footerField(),
              ],
            );
          },
        ),
      ],
    );
  }
}
