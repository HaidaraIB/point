import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/OsLegalContractsController.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/Os/OsContractSettings.dart';
import 'package:point/Models/Os/OsContractTemplate.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/Utils/app_theme_extension.dart';
import 'package:point/View/Os/Contracts/os_legal_contract_form_dialog.dart';
import 'package:point/View/Os/os_button_styles.dart';

class OsLegalContractsTemplatesTab extends StatelessWidget {
  const OsLegalContractsTemplatesTab({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    final ctrl = Get.find<OsLegalContractsController>();
    final settings = ctrl.settings.value;
    final templates = ctrl.templates;
    final pad = compact ? 12.0 : 16.0;

    return ListView(
      padding: EdgeInsets.fromLTRB(pad, pad, pad, 24),
      children: [
        _lawBanner(theme, settings, forceStacked: compact),
        const SizedBox(height: 20),
        Text(
          AppLocaleKeys.osLegalContractTemplateCatalog.tr,
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 16,
            color: theme.primaryText,
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, c) {
            final twoCol = c.maxWidth >= 900;
            final itemWidth =
                twoCol ? (c.maxWidth - 14) / 2 : c.maxWidth;
            return Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [
                for (final t in templates)
                  SizedBox(
                    width: itemWidth,
                    child: _templateCatalogCard(context, theme, t),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _lawBanner(
    AppThemeExtension theme,
    OsContractSettings settings, {
    bool forceStacked = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.15),
            theme.elevatedSurface,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocaleKeys.osLegalContractLawBannerTitle.tr,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: theme.primaryText,
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, c) {
              final wide = !forceStacked && c.maxWidth >= 700;
              final cards = [
                _lawCard(theme, AppLocaleKeys.osLegalContractLawLabor.tr,
                    settings.defaultLaborLawRef),
                _lawCard(theme, AppLocaleKeys.osLegalContractLawCivil.tr,
                    settings.defaultCivilLawRef),
                _lawCard(theme, AppLocaleKeys.osLegalContractLawCopyright.tr,
                    settings.defaultCopyrightLawRef),
              ];
              if (wide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < cards.length; i++) ...[
                      if (i > 0) const SizedBox(width: 10),
                      Expanded(child: cards[i]),
                    ],
                  ],
                );
              }
              return Column(
                children: [
                  for (var i = 0; i < cards.length; i++) ...[
                    if (i > 0) const SizedBox(height: 10),
                    cards[i],
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _lawCard(AppThemeExtension theme, String title, String body) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.cardSurface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 12,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: TextStyle(fontSize: 11, color: theme.secondaryText, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _templateCatalogCard(
    BuildContext context,
    AppThemeExtension theme,
    OsContractTemplate t,
  ) {
    final clausePreview = t.clauses.take(4).toList();
    final remaining = t.clauses.length - clausePreview.length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (t.subType.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    t.subType,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              const Spacer(),
              Text(
                AppLocaleKeys.osLegalContractClausesCount.trParams({
                  'count': '${t.clauses.length}',
                }),
                style: TextStyle(fontSize: 10, color: theme.mutedText),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            t.suggestedTitle.isNotEmpty ? t.suggestedTitle : t.name,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 14,
              color: theme.primaryText,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            t.description,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: theme.secondaryText),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.elevatedSurface.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocaleKeys.osLegalContractLegalBasis.tr,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: theme.secondaryText,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  t.governingLaw,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: theme.secondaryText),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final c in clausePreview)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.elevatedSurface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: theme.border),
                  ),
                  child: Text(
                    c.title.split(':').first.trim(),
                    style: TextStyle(fontSize: 10, color: theme.secondaryText),
                  ),
                ),
              if (remaining > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.elevatedSurface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    AppLocaleKeys.osLegalContractMoreArticles.trParams({
                      'count': '$remaining',
                    }),
                    style: TextStyle(fontSize: 10, color: theme.secondaryText),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (t.defaultDurationMonths != null)
                Expanded(
                  child: Text(
                    AppLocaleKeys.osLegalContractTypicalDuration.trParams({
                      'months': '${t.defaultDurationMonths}',
                    }),
                    style: TextStyle(fontSize: 11, color: theme.secondaryText),
                  ),
                ),
              FilledButton.icon(
                onPressed: () => showOsLegalContractFormDialog(
                  context,
                  template: t,
                ),
                style: OsButtonStyles.primaryCompact(),
                icon: const Icon(Icons.arrow_back, size: 16),
                label: Text(AppLocaleKeys.osLegalContractStartDraft.tr),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
