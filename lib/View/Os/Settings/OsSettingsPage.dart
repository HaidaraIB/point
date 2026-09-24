import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Controller/OsEmailHubController.dart';
import 'package:point/Controller/OsGeneralSettingsController.dart';
import 'package:point/Controller/OsLegalContractsController.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/Os/OsAiSettingsStatus.dart';
import 'package:point/Services/os_ai_service.dart';
import 'package:point/Services/os_alqaseh_service.dart';
import 'package:point/Services/os_card_payment_service.dart';
import 'package:point/Services/os_paytabs_service.dart';
import 'package:point/Services/os_qicard_service.dart';
import 'package:point/Services/os_zaincash_service.dart';
import 'package:point/Services/os_settings_tab_persistence.dart';
import 'package:point/Services/os_whatsapp_service.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/Utils/OsPermissions.dart';
import 'package:point/Utils/app_theme_extension.dart';
import 'package:point/Utils/os_currency.dart';
import 'package:point/View/Os/Contracts/os_legal_contracts_settings_tab.dart';
import 'package:point/View/Os/os_button_styles.dart';
import 'package:point/View/Os/os_form_dialog.dart';
import 'package:point/View/Os/os_page_header.dart';
import 'package:point/View/Os/os_email_settings_panel.dart';
import 'package:point/View/Os/os_print_contact_settings_panel.dart';
import 'package:point/View/Os/os_quote_template_settings_panel.dart';
import 'package:point/View/Os/os_snackbar.dart';
import 'package:point/View/Os/Settings/os_payment_methods_tab.dart';
import 'package:point/View/Os/os_whatsapp_settings_panel.dart';
import 'package:point/View/Os/os_whatsapp_template_settings_panel.dart';
import 'package:point/View/Os/os_stamp_settings_panel.dart';
import 'package:point/View/Shared/ResponsiveScaffold.dart';

class OsSettingsPage extends StatefulWidget {
  const OsSettingsPage({super.key});

  @override
  State<OsSettingsPage> createState() => _OsSettingsPageState();
}

class _OsSettingsPageState extends State<OsSettingsPage>
    with SingleTickerProviderStateMixin {
  final _apiKeyCtrl = TextEditingController();
  var _loading = true;
  var _saving = false;
  var _obscureKey = true;
  OsAiSettingsStatus _status = OsAiSettingsStatus.empty();
  late final TabController _tabController;
  var _integrationsPrefetched = false;
  var _paymentMethodsPrefetched = false;
  var _restoringPrefs = false;

  @override
  void initState() {
    super.initState();
    final initial = OsSettingsTabPersistence.indexFromRoute();
    _tabController = TabController(
      length: 5,
      vsync: this,
      initialIndex: initial,
    );
    _tabController.addListener(_onTabChanged);
    if (!OsSettingsTabPersistence.hasRouteTab()) {
      _restoreSavedTab();
    } else {
      OsSettingsTabPersistence.saveIndex(initial);
    }
    if (initial == 1) {
      _prefetchIntegrations();
    } else if (initial == 2) {
      _prefetchPaymentMethods();
    }
    Get.find<OsGeneralSettingsController>();
    Get.find<OsEmailHubController>();
    Get.find<OsLegalContractsController>();
    _load();
  }

  Future<void> _restoreSavedTab() async {
    final saved = await OsSettingsTabPersistence.loadSavedIndex();
    if (!mounted || saved == _tabController.index) return;
    _restoringPrefs = true;
    _tabController.index = saved;
    _restoringPrefs = false;
    if (saved == 1) {
      _prefetchIntegrations();
    } else if (saved == 2) {
      _prefetchPaymentMethods();
    }
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging || _restoringPrefs) return;
    OsSettingsTabPersistence.saveIndex(_tabController.index);
    if (_tabController.index == 1) {
      _prefetchIntegrations();
    } else if (_tabController.index == 2) {
      _prefetchPaymentMethods();
    }
  }

  Future<void> _prefetchIntegrations() async {
    if (_integrationsPrefetched) return;
    _integrationsPrefetched = true;
    await OsWhatsappService.instance.loadSettings();
  }

  Future<void> _prefetchPaymentMethods() async {
    if (_paymentMethodsPrefetched) return;
    _paymentMethodsPrefetched = true;
    await Future.wait([
      OsCardPaymentService.instance.loadActiveProvider(),
      OsPaytabsService.instance.loadSettings(),
      OsAlqasehService.instance.loadSettings(),
      OsQicardService.instance.loadSettings(),
      OsZaincashService.instance.loadSettings(),
    ]);
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _apiKeyCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final status = await OsAiService.instance.loadSettings();
      if (!mounted) return;
      setState(() {
        _status = status;
        _apiKeyCtrl.clear();
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final key = _apiKeyCtrl.text.trim();
    if (key.isEmpty) {
      OsSnackbar.error(
        AppLocaleKeys.osSettingsTitle.tr,
        AppLocaleKeys.osSettingsAiKeyRequired.tr,
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final status = await OsAiService.instance.saveGeminiApiKey(key);
      if (!mounted) return;
      if (status == null) {
        OsSnackbar.error(
          AppLocaleKeys.osSettingsTitle.tr,
          AppLocaleKeys.osSettingsAiKeyInvalid.tr,
        );
        return;
      }
      setState(() {
        _status = status;
        _apiKeyCtrl.clear();
      });
      OsSnackbar.success(
        AppLocaleKeys.osSettingsTitle.tr,
        AppLocaleKeys.osSettingsAiSaved.tr,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _clearStoredKey() async {
    setState(() => _saving = true);
    try {
      final status = await OsAiService.instance.saveGeminiApiKey('');
      if (!mounted) return;
      if (status == null) {
        OsSnackbar.error(
          AppLocaleKeys.osSettingsTitle.tr,
          AppLocaleKeys.errorsServer.tr,
        );
        return;
      }
      setState(() {
        _status = status;
        _apiKeyCtrl.clear();
      });
      OsSnackbar.success(
        AppLocaleKeys.osSettingsTitle.tr,
        AppLocaleKeys.osSettingsAiCleared.tr,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final emp = Get.find<HomeController>().effectiveEmployee;
    if (!OsPermissions.canAccessOsSettings(emp)) {
      return Scaffold(body: Center(child: Text('errors.forbidden'.tr)));
    }

    final theme = context.appTheme;

    return ResponsiveScaffold(
      selectedTab: 14,
      sideMenu: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OsPageHeader(
            title: AppLocaleKeys.osSettingsTitle.tr,
            subtitle: AppLocaleKeys.osSettingsSubtitle.tr,
            currentRoute: '/os/settings',
          ),
          if (!_loading)
            TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: theme.accentText,
              unselectedLabelColor: theme.mutedText,
              indicatorColor: AppColors.primary,
              labelPadding: const EdgeInsets.symmetric(horizontal: 18),
              tabs: [
                Tab(text: AppLocaleKeys.osSettingsTabGeneral.tr),
                Tab(text: AppLocaleKeys.osSettingsTabIntegrations.tr),
                Tab(text: AppLocaleKeys.osSettingsTabPaymentMethods.tr),
                Tab(text: AppLocaleKeys.osSettingsTabPrintBrand.tr),
                Tab(text: AppLocaleKeys.osSettingsTabLegal.tr),
              ],
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      ListView(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                        children: [
                          _SettingsCard(
                            icon: Icons.auto_awesome,
                            title: AppLocaleKeys.osSettingsAiSection.tr,
                            child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              AppLocaleKeys.osSettingsAiDescription.tr,
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.5,
                                color: theme.secondaryText,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Icon(
                                  _status.hasGeminiKey
                                      ? Icons.check_circle_outline
                                      : Icons.error_outline,
                                  size: 18,
                                  color: _status.hasGeminiKey
                                      ? const Color(0xFF059669)
                                      : const Color(0xFFE11D48),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _status.hasGeminiKey
                                        ? AppLocaleKeys.osSettingsAiConfigured.tr
                                        : AppLocaleKeys
                                            .osSettingsAiNotConfigured.tr,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: theme.primaryText,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (_status.hasGeminiKey &&
                                _status.keyPreview.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                AppLocaleKeys.osSettingsAiKeyPreview.trParams({
                                  'preview': _status.keyPreview,
                                }),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.mutedText,
                                ),
                              ),
                            ],
                            const SizedBox(height: 16),
                            Text(
                              AppLocaleKeys.osSettingsAiKeyLabel.tr,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: theme.secondaryText,
                              ),
                            ),
                            const SizedBox(height: 8),
                            osTypedTextField(
                              controller: _apiKeyCtrl,
                              obscureText: _obscureKey,
                              decoration:
                                  osDialogFieldDecoration(context).copyWith(
                                hintText: AppLocaleKeys.osSettingsAiKeyHint.tr,
                                suffixIcon: IconButton(
                                  onPressed: () => setState(
                                    () => _obscureKey = !_obscureKey,
                                  ),
                                  icon: Icon(
                                    _obscureKey
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                    size: 18,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            if (_status.configuredInFirestore)
                              Row(
                                children: [
                                  Expanded(
                                    child: SizedBox(
                                      width: double.infinity,
                                      child: FilledButton.icon(
                                        onPressed: _saving ? null : _save,
                                        style: OsButtonStyles.primaryCompact(),
                                        icon: _saving
                                            ? const SizedBox(
                                                width: 18,
                                                height: 18,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                ),
                                              )
                                            : const Icon(Icons.save_outlined,
                                                size: 18),
                                        label: Text(
                                          AppLocaleKeys.osSettingsAiSave.tr,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: SizedBox(
                                      width: double.infinity,
                                      child: OutlinedButton.icon(
                                        onPressed:
                                            _saving ? null : _clearStoredKey,
                                        style: OsButtonStyles.outlinedCompact(
                                          theme,
                                        ),
                                        icon: const Icon(Icons.delete_outline,
                                            size: 18),
                                        label: Text(
                                          AppLocaleKeys.osSettingsAiClear.tr,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            else
                              Align(
                                alignment: AlignmentDirectional.centerEnd,
                                child: FilledButton.icon(
                                  onPressed: _saving ? null : _save,
                                  style: OsButtonStyles.primaryCompact(),
                                  icon: _saving
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.save_outlined,
                                          size: 18),
                                  label: Text(
                                    AppLocaleKeys.osSettingsAiSave.tr,
                                  ),
                                ),
                              ),
                          ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          const _OsFinanceSettingsSection(),
                        ],
                      ),
                      ListView(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                        children: [
                          _SettingsCard(
                            icon: Icons.mail_outline,
                            title: AppLocaleKeys.osSettingsEmailSection.tr,
                            child: const OsEmailSettingsPanel(),
                          ),
                          const SizedBox(height: 16),
                          _SettingsCard(
                            icon: Icons.chat_outlined,
                            title: AppLocaleKeys.osSettingsWhatsappSection.tr,
                            child: const OsWhatsappSettingsPanel(),
                          ),
                          const SizedBox(height: 16),
                          _SettingsCard(
                            icon: Icons.view_list_outlined,
                            title:
                                AppLocaleKeys.osSettingsWhatsappTemplatesSection.tr,
                            child: const OsWhatsappTemplateSettingsPanel(),
                          ),
                        ],
                      ),
                      const OsPaymentMethodsTab(),
                      ListView(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                        children: [
                          _SettingsCard(
                            icon: Icons.contact_phone_outlined,
                            title: AppLocaleKeys.osSettingsPrintContactSection.tr,
                            child: const OsPrintContactSettingsPanel(),
                          ),
                          const SizedBox(height: 16),
                          _SettingsCard(
                            icon: Icons.tune,
                            title:
                                AppLocaleKeys.osSettingsQuotationTemplateSection.tr,
                            child: const OsQuoteTemplateSettingsPanel(),
                          ),
                          const SizedBox(height: 16),
                          _SettingsCard(
                            icon: Icons.verified_outlined,
                            title: AppLocaleKeys.osInvoicesStampSection.tr,
                            child: const OsStampSettingsPanel(embedded: true),
                          ),
                        ],
                      ),
                      ListView(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                        children: [
                          _SettingsCard(
                            icon: Icons.gavel_outlined,
                            title: AppLocaleKeys.osLegalContractTabSettings.tr,
                            child: const OsLegalContractsSettingsTab(
                              embedded: true,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _OsFinanceSettingsSection extends StatefulWidget {
  const _OsFinanceSettingsSection();

  @override
  State<_OsFinanceSettingsSection> createState() =>
      _OsFinanceSettingsSectionState();
}

class _OsFinanceSettingsSectionState extends State<_OsFinanceSettingsSection> {
  final _rateCtrl = TextEditingController();
  var _saving = false;
  var _dirty = false;

  OsGeneralSettingsController get _ctrl =>
      Get.find<OsGeneralSettingsController>();

  @override
  void initState() {
    super.initState();
    _syncFromController();
    ever(_ctrl.settings, (_) {
      if (!_dirty && mounted) _syncFromController();
    });
  }

  @override
  void dispose() {
    _rateCtrl.dispose();
    super.dispose();
  }

  void _syncFromController() {
    _rateCtrl.text = _formatRate(_ctrl.usdToIqdRate);
  }

  String _formatRate(double rate) {
    if (rate == rate.roundToDouble()) return rate.toInt().toString();
    return rate.toString();
  }

  Future<void> _save() async {
    final parsed = double.tryParse(_rateCtrl.text.trim());
    if (parsed == null || !isValidUsdToIqdRate(parsed)) {
      OsSnackbar.error(
        AppLocaleKeys.osSettingsFinanceSection.tr,
        AppLocaleKeys.osSettingsFinanceRateInvalid.tr,
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final ok = await _ctrl.saveUsdToIqdRate(parsed);
      if (!mounted) return;
      if (!ok) {
        OsSnackbar.error(
          AppLocaleKeys.osSettingsFinanceSection.tr,
          AppLocaleKeys.errorsServer.tr,
        );
        return;
      }
      setState(() => _dirty = false);
      _syncFromController();
      OsSnackbar.success(
        AppLocaleKeys.osSettingsFinanceSection.tr,
        AppLocaleKeys.osSettingsFinanceSaved.tr,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;

    return _SettingsCard(
      icon: Icons.payments_outlined,
      title: AppLocaleKeys.osSettingsFinanceSection.tr,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            AppLocaleKeys.osSettingsFinanceDescription.tr,
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: theme.secondaryText,
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 640;
              final currencyTile = _CurrencyReadOnlyTile(
                label: AppLocaleKeys.osSettingsFinanceBaseCurrency.tr,
                value: AppLocaleKeys.osSettingsFinanceCurrencyIqd.tr,
              );
              final secondaryTile = _CurrencyReadOnlyTile(
                label: AppLocaleKeys.osSettingsFinanceSecondaryCurrency.tr,
                value: AppLocaleKeys.osSettingsFinanceCurrencyUsd.tr,
              );
              if (narrow) {
                return Column(
                  children: [
                    currencyTile,
                    const SizedBox(height: 12),
                    secondaryTile,
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: currencyTile),
                  const SizedBox(width: 12),
                  Expanded(child: secondaryTile),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          Text(
            AppLocaleKeys.osSettingsFinanceRateLabel.tr,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: theme.secondaryText,
            ),
          ),
          const SizedBox(height: 8),
          osTypedTextField(
            controller: _rateCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            onChanged: (_) => setState(() => _dirty = true),
            decoration: osDialogFieldDecoration(context).copyWith(
              hintText: AppLocaleKeys.osSettingsFinanceRateHint.tr,
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: FilledButton.icon(
              onPressed: _saving ? null : _save,
              style: OsButtonStyles.primaryCompact(),
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined, size: 18),
              label: Text(AppLocaleKeys.osSettingsFinanceSave.tr),
            ),
          ),
        ],
      ),
    );
  }
}

class _CurrencyReadOnlyTile extends StatelessWidget {
  const _CurrencyReadOnlyTile({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: theme.panelTint,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: theme.mutedText,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: theme.primaryText,
                  ),
                ),
              ),
              Icon(Icons.check_circle_outline,
                  size: 18, color: theme.accentText),
            ],
          ),
        ],
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.title,
    required this.child,
    required this.icon,
  });

  final String title;
  final Widget child;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    return Material(
      color: theme.cardSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: theme.accentText),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: theme.primaryText,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}
