import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/Os/OsActiveCardProviderStatus.dart';
import 'package:point/Models/Os/OsAlqasehSettingsStatus.dart';
import 'package:point/Models/Os/OsPaytabsSettingsStatus.dart';
import 'package:point/Models/Os/OsWalletToggleStatus.dart';
import 'package:point/Services/os_alqaseh_service.dart';
import 'package:point/Services/os_card_payment_service.dart';
import 'package:point/Services/os_paytabs_service.dart';
import 'package:point/Services/os_qicard_service.dart';
import 'package:point/Services/os_zaincash_service.dart';
import 'package:point/Utils/app_theme_extension.dart';
import 'package:point/View/Os/Settings/os_payment_method_card.dart';
import 'package:point/View/Os/Settings/os_payment_method_credentials_dialog.dart';
import 'package:point/View/Os/os_snackbar.dart';

/// Prefer up to 3 equal-height cards per row; shrink only when the row is tight.
const double _kMinCardWidth = 300;
const int _kMaxColumns = 3;

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
        OsZaincashService.instance.loadSettings(force: true),
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
      onZaincashSaved: (_) async {
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

  OsWalletToggleStatus _walletStatus(String method) {
    if (method == 'zaincash') return _active.zaincash;
    return _active.qicard;
  }

  String _walletSectionTitle(String method) {
    if (method == 'zaincash') {
      return AppLocaleKeys.osSettingsZaincashSection.tr;
    }
    return AppLocaleKeys.osSettingsQicardSection.tr;
  }

  String _walletNotConfiguredMessage(String method) {
    if (method == 'zaincash') {
      return AppLocaleKeys.errorsZaincashNotConfigured.tr;
    }
    return AppLocaleKeys.errorsQicardNotConfigured.tr;
  }

  String _walletBankRequiredMessage(String method) {
    if (method == 'zaincash') {
      return AppLocaleKeys.osSettingsZaincashBankRequired.tr;
    }
    return AppLocaleKeys.osSettingsQicardBankRequired.tr;
  }

  String _walletToggleSavedMessage(String method) {
    if (method == 'zaincash') {
      return AppLocaleKeys.osSettingsZaincashToggleSaved.tr;
    }
    return AppLocaleKeys.osSettingsQicardToggleSaved.tr;
  }

  OsPaymentMethodKind _walletCredentialsKind(String method) {
    if (method == 'zaincash') return OsPaymentMethodKind.zaincash;
    return OsPaymentMethodKind.qicard;
  }

  Future<void> _setWallet(String method, bool enabled) async {
    final wallet = _walletStatus(method);
    if (enabled && !wallet.configured) {
      OsSnackbar.error(
        _walletSectionTitle(method),
        _walletNotConfiguredMessage(method),
      );
      await _openCredentials(_walletCredentialsKind(method));
      return;
    }

    final bankId = wallet.bankAccountId.trim();
    if (enabled && bankId.isEmpty) {
      OsSnackbar.error(
        _walletSectionTitle(method),
        _walletBankRequiredMessage(method),
      );
      return;
    }

    setState(() => _busyMethod = method);
    try {
      final status = await OsCardPaymentService.instance.setWalletEnabled(
        method: method,
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
          _walletSectionTitle(method),
          _walletToggleSavedMessage(method),
        );
      }
    } finally {
      if (mounted) setState(() => _busyMethod = '');
    }
  }

  Future<void> _onGatewayBankChanged(String? id) async {
    if (id == null) return;
    setState(() {
      _active = _active.copyWith(defaultBankAccountId: id);
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

  Future<void> _onWalletBankChanged(String method, String? id) async {
    if (id == null) return;
    final wallet = _walletStatus(method);
    setState(() {
      _active = _active.copyWith(
        qicard: method == 'qicard'
            ? OsWalletToggleStatus(
                enabled: wallet.enabled,
                bankAccountId: id,
                configured: wallet.configured,
              )
            : _active.qicard,
        zaincash: method == 'zaincash'
            ? OsWalletToggleStatus(
                enabled: wallet.enabled,
                bankAccountId: id,
                configured: wallet.configured,
              )
            : _active.zaincash,
      );
    });
    if (!_walletStatus(method).enabled) return;

    setState(() => _busyMethod = method);
    try {
      final status = await OsCardPaymentService.instance.setWalletEnabled(
        method: method,
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
    required String iconAsset,
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
      iconAsset: iconAsset,
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
    final zaincashBank = _active.zaincash.bankAccountId.isEmpty
        ? null
        : _active.zaincash.bankAccountId;

    final cards = [
      _card(
        iconAsset: 'assets/images/paytabs.png',
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
        iconAsset: 'assets/images/alqaseh.png',
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
        iconAsset: 'assets/images/qicard.png',
        title: AppLocaleKeys.osSettingsQicardSection.tr,
        subtitle: AppLocaleKeys.osSettingsPaymentMethodsQicardSubtitle.tr,
        configured: _active.qicard.configured,
        configuredLabel: AppLocaleKeys.osSettingsQicardConfigured.tr,
        notConfiguredLabel: AppLocaleKeys.osSettingsQicardNotConfigured.tr,
        enabled: _active.qicard.enabled,
        busyId: 'qicard',
        onEnabledChanged: (v) => _setWallet('qicard', v),
        bankAccountId: qicardBank,
        onBankChanged: (id) => _onWalletBankChanged('qicard', id),
        credentialsKind: OsPaymentMethodKind.qicard,
      ),
      _card(
        iconAsset: 'assets/images/zaincash.png',
        title: AppLocaleKeys.osSettingsZaincashSection.tr,
        subtitle: AppLocaleKeys.osSettingsPaymentMethodsZaincashSubtitle.tr,
        configured: _active.zaincash.configured,
        configuredLabel: AppLocaleKeys.osSettingsZaincashConfigured.tr,
        notConfiguredLabel: AppLocaleKeys.osSettingsZaincashNotConfigured.tr,
        enabled: _active.zaincash.enabled,
        busyId: 'zaincash',
        onEnabledChanged: (v) => _setWallet('zaincash', v),
        bankAccountId: zaincashBank,
        onBankChanged: (id) => _onWalletBankChanged('zaincash', id),
        credentialsKind: OsPaymentMethodKind.zaincash,
      ),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
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
            const gap = 12.0;
            final maxW = constraints.maxWidth;
            final columns = ((maxW + gap) / (_kMinCardWidth + gap))
                .floor()
                .clamp(1, _kMaxColumns);

            final rows = <Widget>[];
            for (var i = 0; i < cards.length; i += columns) {
              final end = (i + columns).clamp(0, cards.length);
              final rowCards = cards.sublist(i, end);
              final isLast = end >= cards.length;

              rows.add(
                Padding(
                  padding: EdgeInsets.only(bottom: isLast ? 0 : gap),
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var j = 0; j < rowCards.length; j++) ...[
                          if (j > 0) const SizedBox(width: gap),
                          Expanded(child: rowCards[j]),
                        ],
                        // Keep card width consistent on a short last row.
                        for (var j = rowCards.length; j < columns; j++) ...[
                          const SizedBox(width: gap),
                          const Expanded(child: SizedBox.shrink()),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: rows,
            );
          },
        ),
      ],
    );
  }
}
