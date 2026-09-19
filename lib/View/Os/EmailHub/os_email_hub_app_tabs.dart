import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Localization/notify_locale.dart';
import 'package:point/Services/email/app_email_html_composer.dart';
import 'package:point/Services/email/app_notification_email_samples.dart';
import 'package:point/Services/email/email_html_builders.dart';
import 'package:point/Utils/app_theme_extension.dart';
import 'package:point/View/Os/EmailHub/html_email_preview.dart';
import 'package:point/View/Os/os_button_styles.dart';

/// Preview-only tab for app notification emails in a category.
class OsEmailHubNotificationCategoryTab extends StatefulWidget {
  const OsEmailHubNotificationCategoryTab({
    super.key,
    required this.categoryKey,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String categoryKey;
  final String title;
  final String subtitle;
  final IconData icon;

  @override
  State<OsEmailHubNotificationCategoryTab> createState() =>
      _OsEmailHubNotificationCategoryTabState();
}

class _OsEmailHubNotificationCategoryTabState
    extends State<OsEmailHubNotificationCategoryTab> {
  late String _selectedType;
  var _locale = NotifyLocale.normalize(Get.locale?.languageCode);

  @override
  void initState() {
    super.initState();
    _selectedType = _defaultTypeForCategory(widget.categoryKey);
  }

  @override
  void didUpdateWidget(OsEmailHubNotificationCategoryTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.categoryKey != widget.categoryKey) {
      setState(() => _selectedType = _defaultTypeForCategory(widget.categoryKey));
    }
  }

  String _defaultTypeForCategory(String categoryKey) {
    final types = AppNotificationEmailSamples.emailTypesForCategory(categoryKey);
    return types.isNotEmpty ? types.first : '';
  }

  @override
  Widget build(BuildContext context) {
    final types = AppNotificationEmailSamples.emailTypesForCategory(
      widget.categoryKey,
    );
    if (types.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            AppLocaleKeys.osEmailHubAppNotificationsPushOnly.tr,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.appTheme.secondaryText,
              fontSize: 15,
            ),
          ),
        ),
      );
    }

    final selectedType = types.contains(_selectedType)
        ? _selectedType
        : types.first;
    if (!types.contains(_selectedType)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || types.contains(_selectedType)) return;
        setState(() => _selectedType = types.first);
      });
    }

    final sample = AppNotificationEmailSamples.sampleForType(
      selectedType,
      locale: _locale,
    );
    final html = AppEmailHtmlComposer.notification(
      title: sample.title,
      body: sample.body,
      recipientLabel: NotifyLocale.tr(
        _locale,
        AppLocaleKeys.osEmailHubPreviewSampleUser,
      ),
      actionText: sample.actionText,
      details: sample.emailDetails,
      languageCode: _locale,
    );

    return OsEmailHubPreviewPanel(
      icon: widget.icon,
      title: widget.title,
      subtitle: widget.subtitle,
      controls: [
        DropdownButtonFormField<String>(
          key: ValueKey('${widget.categoryKey}-$selectedType'),
          initialValue: selectedType,
          decoration: _dropdownDecoration(context),
          items: types
              .map(
                (type) => DropdownMenuItem(
                  value: type,
                  child: Text(
                    type,
                    style: const TextStyle(fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(growable: false),
          onChanged: (value) {
            if (value == null) return;
            setState(() => _selectedType = value);
          },
        ),
        const SizedBox(height: 12),
        _LocaleToggle(
          locale: _locale,
          onChanged: (locale) => setState(() => _locale = locale),
        ),
      ],
      preview: HtmlEmailPreview(
        key: ValueKey('${widget.categoryKey}-$selectedType-$_locale'),
        html: html,
      ),
    );
  }
}

/// Preview-only tab for scheduled chat unread digest emails.
class OsEmailHubChatDigestTab extends StatefulWidget {
  const OsEmailHubChatDigestTab({super.key});

  @override
  State<OsEmailHubChatDigestTab> createState() => _OsEmailHubChatDigestTabState();
}

class _OsEmailHubChatDigestTabState extends State<OsEmailHubChatDigestTab> {
  var _locale = NotifyLocale.normalize(Get.locale?.languageCode);

  @override
  Widget build(BuildContext context) {
    final intro = NotifyLocale.tr(
      _locale,
      AppLocaleKeys.emailTemplateChatDigestIntro,
    );
    final rows = [
      EmailChatDigestRow(
        count: 3,
        label: NotifyLocale.tr(
          _locale,
          AppLocaleKeys.osEmailHubPreviewChatTeamSample,
        ),
      ),
      EmailChatDigestRow(
        count: 1,
        label: NotifyLocale.tr(
          _locale,
          AppLocaleKeys.osEmailHubPreviewChatClientSample,
        ),
      ),
    ];
    final html = AppEmailHtmlComposer.chatDigest(
      intro: intro,
      rows: rows,
      languageCode: _locale,
    );

    return OsEmailHubPreviewPanel(
      icon: Icons.forum_outlined,
      title: AppLocaleKeys.pushTestCategoryChat.tr,
      subtitle: AppLocaleKeys.osEmailHubChatDigestSubtitle.tr,
      controls: [
        _LocaleToggle(
          locale: _locale,
          onChanged: (locale) => setState(() => _locale = locale),
        ),
      ],
      preview: HtmlEmailPreview(
        key: ValueKey('chat-digest-$_locale'),
        html: html,
      ),
    );
  }
}

/// Preview-only tab for topic broadcast emails (plain wrapper).
class OsEmailHubBroadcastTab extends StatefulWidget {
  const OsEmailHubBroadcastTab({super.key});

  @override
  State<OsEmailHubBroadcastTab> createState() => _OsEmailHubBroadcastTabState();
}

class _OsEmailHubBroadcastTabState extends State<OsEmailHubBroadcastTab> {
  var _locale = NotifyLocale.normalize(Get.locale?.languageCode);

  @override
  Widget build(BuildContext context) {
    final body = NotifyLocale.tr(
      _locale,
      AppLocaleKeys.osEmailHubPreviewBroadcastBody,
    );
    final html = AppEmailHtmlComposer.plainWrapper(
      body: body,
      languageCode: _locale,
    );

    return OsEmailHubPreviewPanel(
      icon: Icons.campaign_outlined,
      title: AppLocaleKeys.pushTestCategoryBroadcast.tr,
      subtitle: AppLocaleKeys.osEmailHubBroadcastSubtitle.tr,
      controls: [
        _LocaleToggle(
          locale: _locale,
          onChanged: (locale) => setState(() => _locale = locale),
        ),
      ],
      preview: HtmlEmailPreview(
        key: ValueKey('broadcast-$_locale'),
        html: html,
      ),
    );
  }
}

class OsEmailHubPreviewPanel extends StatelessWidget {
  const OsEmailHubPreviewPanel({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.controls,
    required this.preview,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<Widget> controls;
  final Widget preview;

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    final formCard = Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.cardSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: theme.accentText),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: theme.primaryText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.secondaryText,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...controls,
          const SizedBox(height: 8),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: FilledButton.icon(
              onPressed: null,
              style: OsButtonStyles.secondaryCompact(theme),
              icon: const Icon(Icons.visibility_outlined, size: 18),
              label: Text(AppLocaleKeys.osEmailHubPreviewOnly.tr),
            ),
          ),
        ],
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 960;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: formCard),
                  const SizedBox(width: 16),
                  Expanded(child: preview),
                ],
              )
            else ...[
              formCard,
              const SizedBox(height: 16),
              preview,
            ],
          ],
        );
      },
    );
  }
}

class _LocaleToggle extends StatelessWidget {
  const _LocaleToggle({required this.locale, required this.onChanged});

  final String locale;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<String>(
      segments: [
        ButtonSegment(
          value: 'ar',
          label: Text(AppLocaleKeys.osEmailHubPreviewLocaleAr.tr),
        ),
        ButtonSegment(
          value: 'en',
          label: Text(AppLocaleKeys.osEmailHubPreviewLocaleEn.tr),
        ),
      ],
      selected: {locale},
      onSelectionChanged: (values) {
        if (values.isEmpty) return;
        onChanged(values.first);
      },
    );
  }
}

InputDecoration _dropdownDecoration(BuildContext context) {
  final theme = context.appTheme;
  return InputDecoration(
    labelText: AppLocaleKeys.osEmailHubAppNotificationsSelectType.tr,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: theme.border),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
  );
}
