import 'dart:convert';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/Os/OsQicardSettingsStatus.dart';
import 'package:point/Models/Os/qicard_config.dart';
import 'package:point/Services/os_qicard_service.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/Utils/app_log.dart';
import 'package:point/Utils/app_theme_extension.dart';
import 'package:point/View/Os/Settings/os_payment_credentials_form.dart';
import 'package:point/View/Os/os_button_styles.dart';
import 'package:point/View/Os/os_form_dialog.dart';
import 'package:point/View/Os/os_snackbar.dart';

class OsQicardSettingsPanel extends StatefulWidget {
  const OsQicardSettingsPanel({
    super.key,
    this.embedded = false,
    this.compact = false,
    this.onSettingsSaved,
  });

  final bool embedded;
  final bool compact;
  final ValueChanged<OsQicardSettingsStatus>? onSettingsSaved;

  @override
  State<OsQicardSettingsPanel> createState() => _OsQicardSettingsPanelState();
}

class _OsQicardSettingsPanelState extends State<OsQicardSettingsPanel>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _terminalIdCtrl = TextEditingController();
  final _liveApiBaseCtrl = TextEditingController();
  final _webhookKeyCtrl = TextEditingController();

  final _usernameFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _terminalIdFocus = FocusNode();
  final _liveApiBaseFocus = FocusNode();
  final _webhookKeyFocus = FocusNode();

  var _loading = true;
  var _saving = false;
  var _obscurePassword = true;
  var _environment = 'test';
  var _currency = 'IQD';
  OsQicardSettingsStatus _status = OsQicardSettingsStatus.empty();

  /// Set after a save attempt so required-field errors appear.
  var _submitted = false;

  /// Rejected .pem file; shown until the field is edited.
  String? _pemFileError;

  static const _currencies = ['IQD'];

  @override
  void initState() {
    super.initState();
    // Validation for these fields is shown on blur, so rebuild on focus change.
    _liveApiBaseFocus.addListener(_rebuild);
    _webhookKeyFocus.addListener(_rebuild);
    final cached = OsQicardService.instance.cachedSettings;
    if (cached != null) {
      _applyStatus(cached);
      _loading = false;
      return;
    }
    _load();
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _terminalIdCtrl.dispose();
    _liveApiBaseCtrl.dispose();
    _webhookKeyCtrl.dispose();
    _usernameFocus.dispose();
    _passwordFocus.dispose();
    _terminalIdFocus.dispose();
    _liveApiBaseFocus.dispose();
    _webhookKeyFocus.dispose();
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  void _applyStatus(OsQicardSettingsStatus status) {
    _status = status;
    _environment = status.environment.isEmpty ? 'test' : status.environment;
    _currency = status.currency.isEmpty ? 'IQD' : status.currency;
    _usernameCtrl.text = status.username;
    _terminalIdCtrl.text = status.terminalId;
    _liveApiBaseCtrl.text = status.liveApiBase;
    _passwordCtrl.clear();
    _webhookKeyCtrl.text = status.webhookPublicKey;
    _submitted = false;
    _pemFileError = null;
  }

  // --- validation -----------------------------------------------------------

  String? _requiredError(TextEditingController ctrl) =>
      _submitted && ctrl.text.trim().isEmpty
          ? AppLocaleKeys.commonRequired.tr
          : null;

  String? get _usernameError => _requiredError(_usernameCtrl);

  /// Blank keeps the saved password, so it is only required when none exists.
  String? get _passwordError =>
      _status.hasPassword ? null : _requiredError(_passwordCtrl);

  String? get _terminalIdError => _requiredError(_terminalIdCtrl);

  String? get _liveApiBaseError {
    if (_environment != 'live') return null;
    if (isValidQicardBaseUrl(_liveApiBaseCtrl.text)) return null;
    if (!_submitted && _liveApiBaseFocus.hasFocus) return null;
    return AppLocaleKeys.osSettingsQicardLiveApiBaseInvalid.tr;
  }

  QicardPemCheck get _pemCheck => checkQicardPublicKeyPem(_webhookKeyCtrl.text);

  String? get _webhookKeyError {
    if (_pemFileError != null) return _pemFileError;
    switch (_pemCheck) {
      case QicardPemCheck.privateKey:
        // Shown immediately: a private key must not sit in the form.
        return AppLocaleKeys.osSettingsQicardWebhookKeyPrivate.tr;
      case QicardPemCheck.invalid:
        if (!_submitted && _webhookKeyFocus.hasFocus) return null;
        return AppLocaleKeys.osSettingsQicardWebhookKeyInvalid.tr;
      case QicardPemCheck.empty:
      case QicardPemCheck.valid:
        return null;
    }
  }

  /// Status line under the key field when there is no error.
  ({String text, Color? color}) _webhookKeyHelper(BuildContext context) {
    final saved = cleanQicardPem(_status.webhookPublicKey);
    final current = cleanQicardPem(_webhookKeyCtrl.text);
    final dark = Theme.of(context).brightness == Brightness.dark;
    if (_pemCheck == QicardPemCheck.valid) {
      if (current == saved) {
        return (
          text: AppLocaleKeys.osSettingsQicardWebhookKeySavedActive.tr,
          color: dark ? const Color(0xFF6EE7B7) : AppColors.success,
        );
      }
      return (
        text: AppLocaleKeys.osSettingsQicardWebhookKeyUnsaved.tr,
        color: context.appTheme.accentText,
      );
    }
    if (current.isEmpty && saved.isNotEmpty) {
      return (
        text: AppLocaleKeys.osSettingsQicardWebhookKeyWillRemove.tr,
        color: dark ? const Color(0xFFFBBF24) : AppColors.caution,
      );
    }
    return (text: AppLocaleKeys.osSettingsQicardWebhookKeyHint.tr, color: null);
  }

  // --- actions --------------------------------------------------------------

  Future<void> _loadPemFile() async {
    try {
      final file = await FilePicker.pickFile();
      if (file == null || !mounted) return;
      final text = cleanQicardPem(
        utf8.decode(await file.readAsBytes(), allowMalformed: true),
      );
      if (!mounted) return;
      final check = checkQicardPublicKeyPem(text);
      setState(() {
        if (check == QicardPemCheck.valid) {
          _webhookKeyCtrl.text = text;
          _pemFileError = null;
        } else {
          // Leave the field untouched; never load a private key into the form.
          _pemFileError = check == QicardPemCheck.privateKey
              ? AppLocaleKeys.osSettingsQicardWebhookKeyPrivate.tr
              : AppLocaleKeys.osSettingsQicardWebhookKeyInvalid.tr;
        }
      });
    } catch (e, st) {
      appLog('OsQicardSettingsPanel._loadPemFile failed: $e\n$st');
      if (mounted) {
        setState(
          () =>
              _pemFileError = AppLocaleKeys.osSettingsQicardWebhookKeyFileError.tr,
        );
      }
    }
  }

  void _clearWebhookKey() {
    setState(() {
      _webhookKeyCtrl.clear();
      _pemFileError = null;
    });
    _webhookKeyFocus.requestFocus();
  }

  void _restoreWebhookKey() {
    setState(() {
      _webhookKeyCtrl.text = _status.webhookPublicKey;
      _pemFileError = null;
    });
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final status = await OsQicardService.instance.loadSettings(force: true);
      if (!mounted) return;
      setState(() =>
          _applyStatus(status ?? OsQicardSettingsStatus.empty()));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applySandboxCredentials() {
    setState(() {
      _environment = 'test';
      _usernameCtrl.text = 'paymentgatewaytest';
      _passwordCtrl.text = 'WHaNFE5C3qlChqNbAzH4';
      _terminalIdCtrl.text = '237984';
    });
  }

  Future<void> _save() async {
    setState(() {
      _submitted = true;
      // A rejected file is not in the field; don't block saving on it.
      _pemFileError = null;
    });
    final invalid = <(String?, FocusNode)>[
      (_usernameError, _usernameFocus),
      (_passwordError, _passwordFocus),
      (_terminalIdError, _terminalIdFocus),
      (_liveApiBaseError, _liveApiBaseFocus),
      (_webhookKeyError, _webhookKeyFocus),
    ].where((e) => e.$1 != null);
    if (invalid.isNotEmpty) {
      invalid.first.$2.requestFocus();
      return;
    }

    setState(() => _saving = true);
    try {
      final status = await OsQicardService.instance.saveSettings(
        environment: _environment,
        username: _usernameCtrl.text.trim(),
        password: _passwordCtrl.text.trim().isEmpty
            ? null
            : _passwordCtrl.text.trim(),
        terminalId: _terminalIdCtrl.text.trim(),
        currency: _currency,
        // Empty clears the override; the server then uses the live default.
        liveApiBase: _environment == 'live'
            ? _liveApiBaseCtrl.text.trim()
            : null,
        // Public key is shown in full, so the field is the source of truth.
        webhookPublicKey: cleanQicardPem(_webhookKeyCtrl.text),
      );
      if (!mounted) return;
      if (status == null) {
        OsSnackbar.error(
          AppLocaleKeys.osSettingsQicardSection.tr,
          AppLocaleKeys.errorsServer.tr,
        );
        return;
      }
      setState(() => _applyStatus(status));
      widget.onSettingsSaved?.call(status);
      OsSnackbar.success(
        AppLocaleKeys.osSettingsQicardSection.tr,
        AppLocaleKeys.osSettingsQicardSaved.tr,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final theme = context.appTheme;
    final configured =
        _status.hasPassword && _status.username.isNotEmpty && _status.terminalId.isNotEmpty;
    final keyHelper = _webhookKeyHelper(context);
    final sectionLabelStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      color: theme.secondaryText,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!widget.compact) ...[
          Text(
            AppLocaleKeys.osSettingsQicardDescription.tr,
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: theme.secondaryText,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            configured
                ? AppLocaleKeys.osSettingsQicardConfigured.tr
                : AppLocaleKeys.osSettingsQicardNotConfigured.tr,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color:
                  configured ? const Color(0xFF059669) : theme.secondaryText,
            ),
          ),
          if (_status.passwordPreview.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              AppLocaleKeys.osSettingsQicardPasswordPreview.trParams({
                'preview': _status.passwordPreview,
              }),
              style: TextStyle(fontSize: 12, color: theme.secondaryText),
            ),
          ],
          const SizedBox(height: 16),
        ] else if (_status.passwordPreview.isNotEmpty) ...[
          osPaymentCredentialsSecretPreview(
            context,
            AppLocaleKeys.osSettingsQicardPasswordPreview.trParams({
              'preview': _status.passwordPreview,
            }),
          ),
          const SizedBox(height: kOsPaymentCredentialsFieldGap),
        ],
        osPaymentCredentialsEnvironmentField(
          context: context,
          environment: _environment,
          onEnvironmentSelected: (next) async {
            setState(() => _environment = next);
            final status = await OsQicardService.instance.loadSettings(
              force: true,
              environment: next,
            );
            if (!mounted || status == null) return;
            setState(() => _applyStatus(status));
          },
        ),
        const SizedBox(height: kOsPaymentCredentialsFieldGap),
        osTypedTextField(
          controller: _usernameCtrl,
          focusNode: _usernameFocus,
          onChanged: (_) => _rebuild(),
          decoration: osDialogFieldDecoration(context).copyWith(
            labelText: AppLocaleKeys.osSettingsQicardUsername.tr,
            errorText: _usernameError,
          ),
        ),
        const SizedBox(height: kOsPaymentCredentialsFieldGap),
        osTypedTextField(
          controller: _passwordCtrl,
          focusNode: _passwordFocus,
          obscureText: _obscurePassword,
          onChanged: (_) => _rebuild(),
          decoration: osDialogFieldDecoration(context).copyWith(
            labelText: AppLocaleKeys.osSettingsQicardPassword.tr,
            hintText: AppLocaleKeys.osSettingsQicardPasswordHint.tr,
            errorText: _passwordError,
            suffixIcon: osPaymentCredentialsObscureToggle(
              obscure: _obscurePassword,
              onToggle: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
        ),
        const SizedBox(height: kOsPaymentCredentialsFieldGap),
        osTypedTextField(
          controller: _terminalIdCtrl,
          focusNode: _terminalIdFocus,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (_) => _rebuild(),
          decoration: osDialogFieldDecoration(context).copyWith(
            labelText: AppLocaleKeys.osSettingsQicardTerminalId.tr,
            errorText: _terminalIdError,
          ),
        ),
        // Fills the three fields above, so it sits right under them.
        if (_environment == 'test') ...[
          const SizedBox(height: 12),
          osPaymentCredentialsSandboxButton(
            context: context,
            onPressed: _applySandboxCredentials,
            label: AppLocaleKeys.osSettingsQicardUseSandbox.tr,
          ),
        ],
        if (_environment == 'live') ...[
          const SizedBox(height: kOsPaymentCredentialsFieldGap),
          osTypedTextField(
            controller: _liveApiBaseCtrl,
            focusNode: _liveApiBaseFocus,
            keyboardType: TextInputType.url,
            forceLtrInput: true,
            onChanged: (_) => _rebuild(),
            decoration: osDialogFieldDecoration(context).copyWith(
              labelText: AppLocaleKeys.osSettingsQicardLiveApiBase.tr,
              // Live preview of the URL actually called, then usage hint.
              helperText: [
                if (isValidQicardBaseUrl(_liveApiBaseCtrl.text))
                  AppLocaleKeys.osSettingsQicardLiveApiBaseEffective.trParams({
                    'url': qicardEffectiveLiveApiRoot(_liveApiBaseCtrl.text),
                  }),
                AppLocaleKeys.osSettingsQicardLiveApiBaseHint.tr,
              ].join('\n'),
              helperMaxLines: 5,
              errorText: _liveApiBaseError,
              errorMaxLines: 3,
            ),
          ),
        ],
        const SizedBox(height: kOsPaymentCredentialsFieldGap),
        DropdownButtonFormField<String>(
          initialValue: _currency,
          decoration: osDialogFieldDecoration(context).copyWith(
            labelText: AppLocaleKeys.osSettingsQicardCurrency.tr,
          ),
          items: [
            for (final c in _currencies)
              DropdownMenuItem(value: c, child: Text(c)),
          ],
          onChanged: (v) => setState(() => _currency = v ?? 'IQD'),
        ),
        const SizedBox(height: kOsPaymentCredentialsFieldGap + 8),
        Text(
          AppLocaleKeys.osSettingsQicardWebhookSection.tr,
          style: sectionLabelStyle,
        ),
        const SizedBox(height: 8),
        _QicardPemField(
          controller: _webhookKeyCtrl,
          focusNode: _webhookKeyFocus,
          enabled: !_saving,
          label: AppLocaleKeys.osSettingsQicardWebhookKey.tr,
          helperText: keyHelper.text,
          helperColor: keyHelper.color,
          errorText: _webhookKeyError,
          onChanged: () => setState(() => _pemFileError = null),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: _saving ? null : _loadPemFile,
              style: OsButtonStyles.outlinedCompact(theme),
              icon: const Icon(Icons.upload_file_outlined, size: 18),
              label: Text(AppLocaleKeys.osSettingsQicardWebhookKeyLoadPem.tr),
            ),
            if (_webhookKeyCtrl.text.isNotEmpty || _pemFileError != null)
              TextButton.icon(
                onPressed: _saving ? null : _clearWebhookKey,
                icon: const Icon(Icons.clear_rounded, size: 18),
                label: Text(AppLocaleKeys.osSettingsQicardWebhookKeyClear.tr),
              ),
            // Undo for Clear / edits: bring back what is saved on the server.
            if (_status.webhookPublicKey.isNotEmpty &&
                cleanQicardPem(_webhookKeyCtrl.text) !=
                    cleanQicardPem(_status.webhookPublicKey))
              TextButton.icon(
                onPressed: _saving ? null : _restoreWebhookKey,
                icon: const Icon(Icons.undo_rounded, size: 18),
                label: Text(AppLocaleKeys.osSettingsQicardWebhookKeyRestore.tr),
              ),
          ],
        ),
        const SizedBox(height: kOsPaymentCredentialsFieldGap + 8),
        osPaymentCredentialsSaveRow(
          context: context,
          saving: _saving,
          onSave: _save,
          label: AppLocaleKeys.osSettingsQicardSave.tr,
        ),
      ],
    );
  }
}

/// Multi-line PEM input: monospace, always LTR, no soft wrapping (long lines
/// scroll horizontally inside the field instead of widening the dialog).
class _QicardPemField extends StatefulWidget {
  const _QicardPemField({
    required this.controller,
    required this.focusNode,
    required this.label,
    required this.helperText,
    this.helperColor,
    this.errorText,
    this.enabled = true,
    this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String label;
  final String helperText;
  final Color? helperColor;
  final String? errorText;
  final bool enabled;
  final VoidCallback? onChanged;

  @override
  State<_QicardPemField> createState() => _QicardPemFieldState();
}

class _QicardPemFieldState extends State<_QicardPemField> {
  final _hScroll = ScrollController();
  var _hovering = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_rebuild);
    widget.controller.addListener(_rebuild);
    // Re-measure once Roboto Mono is available (first frame may use fallback).
    GoogleFonts.pendingFonts([
      GoogleFonts.robotoMono(),
    ]).then((_) => _rebuild(), onError: (_) {});
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_rebuild);
    widget.controller.removeListener(_rebuild);
    _hScroll.dispose();
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // letterSpacing pinned so the measurement below matches what the field
    // renders (the theme's input text style would otherwise add spacing).
    final style = GoogleFonts.robotoMono(
      fontSize: 12,
      height: 1.45,
      letterSpacing: 0,
      color: widget.enabled ? null : Theme.of(context).disabledColor,
    );
    final text = widget.controller.text;
    final longest = text
        .split('\n')
        .fold<int>(0, (a, line) => math.max(a, line.length));
    final painter = TextPainter(
      // 'M' is the widest glyph, so this never under-measures even if the
      // monospace font has not loaded yet. Room for a 64-char PEM line,
      // plus two glyphs of slack for the caret.
      text: TextSpan(text: 'M' * (math.max(longest, 64) + 2), style: style),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final contentWidth = painter.width;
    painter.dispose();

    final decoration = osDialogFieldDecoration(context)
        .copyWith(
          labelText: widget.label,
          helperText: widget.helperText,
          helperMaxLines: 3,
          helperStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: widget.helperColor,
            fontWeight: widget.helperColor == null ? null : FontWeight.w600,
          ),
          errorText: widget.errorText,
          errorMaxLines: 3,
          enabled: widget.enabled,
        )
        .applyDefaults(Theme.of(context).inputDecorationTheme);
    final padding =
        decoration.contentPadding?.resolve(Directionality.of(context)) ??
        EdgeInsets.zero;

    // Label/helper follow the UI direction; only the key text is forced LTR.
    return LayoutBuilder(
      builder: (context, constraints) {
        final innerWidth = constraints.maxWidth - padding.horizontal;
        return MouseRegion(
          cursor: widget.enabled
              ? SystemMouseCursors.text
              : SystemMouseCursors.basic,
          onEnter: (_) => setState(() => _hovering = true),
          onExit: (_) => setState(() => _hovering = false),
          child: GestureDetector(
            // Taps on the padding/label focus the field like a normal input.
            onTap: widget.enabled ? widget.focusNode.requestFocus : null,
            child: InputDecorator(
              isFocused: widget.focusNode.hasFocus,
              isHovering: _hovering && widget.enabled,
              isEmpty: text.isEmpty,
              decoration: decoration,
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: Scrollbar(
                  controller: _hScroll,
                  child: SingleChildScrollView(
                    controller: _hScroll,
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: math.max(innerWidth, contentWidth),
                      // Gives screen readers the field's label.
                      child: MergeSemantics(
                        child: Semantics(
                          label: widget.label,
                          child: TextField(
                            controller: widget.controller,
                            focusNode: widget.focusNode,
                            enabled: widget.enabled,
                            style: style,
                            textDirection: TextDirection.ltr,
                            keyboardType: TextInputType.multiline,
                            autocorrect: false,
                            enableSuggestions: false,
                            minLines: 5,
                            maxLines: 9,
                            onChanged: (_) => widget.onChanged?.call(),
                            // The outer InputDecorator draws the field chrome;
                            // keep the theme's input style off the inner field.
                            decoration:
                                const InputDecoration.collapsed(
                                  hintText: null,
                                  border: InputBorder.none,
                                ).copyWith(
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  disabledBorder: InputBorder.none,
                                  filled: false,
                                ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
