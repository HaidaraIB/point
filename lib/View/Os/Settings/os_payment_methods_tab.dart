import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/Os/OsActiveCardProviderStatus.dart';
import 'package:point/Models/Os/OsAlqasehSettingsStatus.dart';
import 'package:point/Models/Os/OsPaytabsSettingsStatus.dart';
import 'package:point/Models/Os/OsQicardSettingsStatus.dart';
import 'package:point/Services/os_alqaseh_service.dart';
import 'package:point/Services/os_card_payment_service.dart';
import 'package:point/Services/os_paytabs_service.dart';
import 'package:point/Services/os_qicard_service.dart';
import 'package:point/Utils/app_theme_extension.dart';
import 'package:point/View/Os/Settings/os_payment_method_card.dart';
import 'package:point/View/Os/Settings/os_payment_method_credentials_dialog.dart';
import 'package:point/View/Os/os_snackbar.dart';

const double _kPaymentMethodsMaxWidth = 920;
const double _kTwoColumnMinWidth = 640;

class OsPaymentMethodsTab extends StatefulWidget {
  const OsPaymentMethodsTab({super.key});

  @override
  State<OsPaymentMethodsTab> createState() => _OsPaymentMethodsTabState();
}

class _OsPaymentMethodsTabState extends State<OsPaymentMethodsTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  var _loading = true;
  var _busyMethod = '';
  OsActiveCardProviderStatus _active = OsActiveCardProviderStatus.empty();
  OsPaytabsSettingsStatus _paytabs = OsPaytabsSettingsStatus.empty();
  OsAlqasehSettingsStatus _alqaseh = OsAlqasehSettingsStatus.empty();

  @override
  void initState() {
    super.initState();
    _load();
  }

  bool _paytabsConfigured(OsPaytabsSettingsStatus s) =>
      s.hasServerKey && s.profileId.isNotEmpty;

  bool _alqasehConfigured(OsAlqasehSettingsStatus s) =>
      s.hasClientSecret && s.clientId.isNotEmpty;

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        OsCardPaymentService.instance.loadActiveProvider(force: true),
        OsPaytabsService.instance.loadSettings(force: true),
        OsAlqasehService.instance.loadSettings(force: true),
        OsQicardService.instance.loadSettings(force: true),
      ]);
      if (!mounted) return;
      setState(() {
        _active = results[0] as OsActiveCardProviderStatus? ??
            OsActiveCardProviderStatus.empty();
        _paytabs = results[1] as OsPaytabsSettingsStatus? ??
            OsPaytabsSettingsStatus.empty();
        _alqaseh = results[2] as OsAlqasehSettingsStatus? ??
            OsAlqasehSettingsStatus.empty();
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openCredentials(OsPaymentMethodKind kind) {
    return showOsPaymentMethodCredentialsDialog(
      context: context,
      kind: kind,
      onPaytabsSaved: (s) => setState(() => _paytabs = s),
      onAlqasehSaved: (s) => setState(() => _alqaseh = s),
      onQicardSaved: () async {
        final status = await OsCardPaymentService.instance
            .loadActiveProvider(force: true);
        if (mounted && status != null) setState(() => _active = status);
      },
    );
  }

  Future<void> _setGateway(String provider, bool enabled) async {
    final bankId = _active.defaultBankAccountId.trim();

    if (enabled) {
      if (provider == 'paytabs' && !_paytabsConfigured(_paytabs)) {
        OsSnackbar.error(
          AppLocaleKeys.osSettingsPaytabsSection.tr,
          AppLocaleKeys.osSettingsCardProviderPaytabsNotConfigured.tr,
        );
        await _openCredentials(OsPaymentMethodKind.paytabs);
        return;
      }
      if (provider == 'alqaseh' && !_alqasehConfigured(_alqaseh)) {
        OsSnackbar.error(
          AppLocaleKeys.osSettingsAlqasehSection.tr,
          AppLocaleKeys.osSettingsCardProviderAlqasehNotConfigured.tr,
        );
        await _openCredentials(OsPaymentMethodKind.alqaseh);
        return;
      }
      if (bankId.isEmpty) {
        OsSnackbar.error(
          AppLocaleKeys.osSettingsCardProviderSection.tr,
          AppLocaleKeys.osSettingsCardProviderBankRequired.tr,
        );
        return;
      }
    }

    setState(() => _busyMethod = provider);
    try {
      final status = await OsCardPaymentService.instance.setActiveProvider(
        provider: enabled ? provider : 'none',
        defaultBankAccountId: bankId,
      );
      if (!mounted) return;
      if (status == null) {
        OsSnackbar.error(
          AppLocaleKeys.osSettingsTabPaymentMethods.tr,
          AppLocaleKeys.errorsServer.tr,
        );
        return;
      }
      setState(() => _active = status);
      if (enabled) {
        OsSnackbar.success(
          AppLocaleKeys.osSettingsTabPaymentMethods.tr,
          AppLocaleKeys.osSettingsCardProviderSaved.tr,
        );
      }
    } finally {
      if (mounted) setState(() => _busyMethod = '');
    }
  }

  Future<void> _setQicard(bool enabled) async {
    if (enabled && !_active.qicard.configured) {
      OsSnackbar.error(
        AppLocaleKeys.osSettingsQicardSection.tr,
        AppLocaleKeys.errorsQicardNotConfigured.tr,
      );
      await _openCredentials(OsPaymentMethodKind.qicard);
      return;
    }

    final bankId = _active.qicard.bankAccountId.trim();
    if (enabled && bankId.isEmpty) {
      OsSnackbar.error(
        AppLocaleKeys.osSettingsQicardSection.tr,
        AppLocaleKeys.osSettingsQicardBankRequired.tr,
      );
      return;
    }

    setState(() => _busyMethod = 'qicard');
    try {
      final status = await OsCardPaymentService.instance.setQicardEnabled(
        enabled: enabled,
        bankAccountId: bankId,
      );
      if (!mounted) return;
      if (status == null) {
        OsSnackbar.error(
          AppLocaleKeys.osSettingsTabPaymentMethods.tr,
          AppLocaleKeys.errorsServer.tr,
        );
        return;
      }
      setState(() => _active = status);
      if (enabled) {
        OsSnackbar.success(
          AppLocaleKeys.osSettingsQicardSection.tr,
          AppLocaleKeys.osSettingsQicardToggleSaved.tr,
        );
      }
    } finally {
      if (mounted) setState(() => _busyMethod = '');
    }
  }

  Future<void> _onGatewayBankChanged(String? id) async {
    if (id == null) return;
    setState(() {
      _active = OsActiveCardProviderStatus(
        provider: _active.provider,
        defaultBankAccountId: id,
        qicard: _active.qicard,
        enabledMethods: _active.enabledMethods,
      );
    });
    if (_active.provider == 'none') return;

    setState(() => _busyMethod = _active.provider);
    try {
      final status = await OsCardPaymentService.instance.setActiveProvider(
        provider: _active.provider,
        defaultBankAccountId: id,
      );
      if (!mounted) return;
      if (status != null) setState(() => _active = status);
    } finally {
      if (mounted) setState(() => _busyMethod = '');
    }
  }

  Future<void> _onQicardBankChanged(String? id) async {
    if (id == null) return;
    setState(() {
      _active = OsActiveCardProviderStatus(
        provider: _active.provider,
        defaultBankAccountId: _active.defaultBankAccountId,
        qicard: OsQicardToggleStatus(
          enabled: _active.qicard.enabled,
          bankAccountId: id,
          configured: _active.qicard.configured,
        ),
        enabledMethods: _active.enabledMethods,
      );
    });
    if (!_active.qicard.enabled) return;

    setState(() => _busyMethod = 'qicard');
    try {
      final status = await OsCardPaymentService.instance.setQicardEnabled(
        enabled: true,
        bankAccountId: id,
      );
      if (!mounted) return;
      if (status != null) setState(() => _active = status);
    } finally {
      if (mounted) setState(() => _busyMethod = '');
    }
  }

  OsPaymentMethodCard _card({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool configured,
    required String configuredLabel,
    required String notConfiguredLabel,
    required bool enabled,
    required String busyId,
    required ValueChanged<bool> onEnabledChanged,
    required String? bankAccountId,
    required ValueChanged<String?> onBankChanged,
    required OsPaymentMethodKind credentialsKind,
  }) {
    return OsPaymentMethodCard(
      icon: icon,
      title: title,
      subtitle: subtitle,
      configured: configured,
      configuredLabel: configuredLabel,
      notConfiguredLabel: notConfiguredLabel,
      enabled: enabled,
      switchBusy: _busyMethod == busyId,
      onEnabledChanged: onEnabledChanged,
      bankAccountId: bankAccountId,
      onBankAccountChanged: onBankChanged,
      onEditCredentials: () => _openCredentials(credentialsKind),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final theme = context.appTheme;
    final gatewayBank = _active.defaultBankAccountId.isEmpty
        ? null
        : _active.defaultBankAccountId;
    final qicardBank = _active.qicard.bankAccountId.isEmpty
        ? null
        : _active.qicard.bankAccountId;

    final cards = [
      _card(
        icon: Icons.credit_card_outlined,
        title: AppLocaleKeys.osSettingsPaytabsSection.tr,
        subtitle: AppLocaleKeys.osSettingsPaymentMethodsPaytabsSubtitle.tr,
        configured: _paytabsConfigured(_paytabs),
        configuredLabel: AppLocaleKeys.osSettingsPaytabsConfigured.tr,
        notConfiguredLabel: AppLocaleKeys.osSettingsPaytabsNotConfigured.tr,
        enabled: _active.provider == 'paytabs',
        busyId: 'paytabs',
        onEnabledChanged: (v) => _setGateway('paytabs', v),
        bankAccountId: gatewayBank,
        onBankChanged: _onGatewayBankChanged,
        credentialsKind: OsPaymentMethodKind.paytabs,
      ),
      _card(
        icon: Icons.account_balance_outlined,
        title: AppLocaleKeys.osSettingsAlqasehSection.tr,
        subtitle: AppLocaleKeys.osSettingsPaymentMethodsAlqasehSubtitle.tr,
        configured: _alqasehConfigured(_alqaseh),
        configuredLabel: AppLocaleKeys.osSettingsAlqasehConfigured.tr,
        notConfiguredLabel: AppLocaleKeys.osSettingsAlqasehNotConfigured.tr,
        enabled: _active.provider == 'alqaseh',
        busyId: 'alqaseh',
        onEnabledChanged: (v) => _setGateway('alqaseh', v),
        bankAccountId: gatewayBank,
        onBankChanged: _onGatewayBankChanged,
        credentialsKind: OsPaymentMethodKind.alqaseh,
      ),
      _card(
        icon: Icons.qr_code_2_outlined,
        title: AppLocaleKeys.osSettingsQicardSection.tr,
        subtitle: AppLocaleKeys.osSettingsPaymentMethodsQicardSubtitle.tr,
        configured: _active.qicard.configured,
        configuredLabel: AppLocaleKeys.osSettingsQicardConfigured.tr,
        notConfiguredLabel: AppLocaleKeys.osSettingsQicardNotConfigured.tr,
        enabled: _active.qicard.enabled,
        busyId: 'qicard',
        onEnabledChanged: _setQicard,
        bankAccountId: qicardBank,
        onBankChanged: _onQicardBankChanged,
        credentialsKind: OsPaymentMethodKind.qicard,
      ),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _kPaymentMethodsMaxWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  AppLocaleKeys.osSettingsPaymentMethodsGatewayHint.tr,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: theme.secondaryText,
                  ),
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= _kTwoColumnMinWidth;
                    const gap = 12.0;
                    final cardWidth = wide
                        ? (constraints.maxWidth - gap) / 2
                        : constraints.maxWidth;

                    final sized = cards
                        .map(
                          (c) => SizedBox(width: cardWidth, child: c),
                        )
                        .toList();

                    if (wide) {
                      return Wrap(
                        spacing: gap,
                        runSpacing: gap,
                        children: sized,
                      );
                    }
                    return Column(
                      children: [
                        for (var i = 0; i < sized.length; i++) ...[
                          if (i > 0) const SizedBox(height: gap),
                          sized[i],
                        ],
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
