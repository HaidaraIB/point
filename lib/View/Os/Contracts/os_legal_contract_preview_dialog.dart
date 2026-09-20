import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:point/Controller/OsLegalContractsController.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/Os/OsContractSettings.dart';
import 'package:point/Models/Os/OsLegalContractModel.dart';
import 'package:point/Models/Os/os_legal_contract_enums.dart';
import 'package:point/Services/firestore/firestore_os_finance_api.dart';
import 'package:point/Services/os_stamp_settings.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/Utils/app_theme_extension.dart';
import 'package:point/View/Os/Contracts/os_legal_contract_labels.dart';
import 'package:point/View/Os/Contracts/os_legal_contract_print.dart';
import 'package:point/View/Os/Contracts/os_legal_contract_print_text.dart';
import 'package:point/View/Os/Contracts/os_legal_contract_share.dart';
import 'package:point/View/Os/EmailHub/html_email_preview.dart';
import 'package:point/View/Os/EmailHub/os_email_hub_helpers.dart';
import 'package:point/View/Os/os_button_styles.dart';
import 'package:point/View/Os/os_finance_status_widgets.dart';
import 'package:point/View/Os/os_form_dialog.dart';
import 'package:point/View/Os/os_invoice_stamp.dart';

Future<void> showOsLegalContractPreviewDialog(
  BuildContext context,
  OsLegalContractModel contract,
) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (_) => _OsLegalContractPreviewDialog(contract: contract),
  );
}

class _OsLegalContractPreviewDialog extends StatefulWidget {
  const _OsLegalContractPreviewDialog({required this.contract});

  final OsLegalContractModel contract;

  @override
  State<_OsLegalContractPreviewDialog> createState() =>
      _OsLegalContractPreviewDialogState();
}

class _OsLegalContractPreviewDialogState
    extends State<_OsLegalContractPreviewDialog> {
  var _copied = false;
  var _emailSending = false;
  var _emailSuccess = false;

  OsLegalContractsController get _ctrl =>
      Get.find<OsLegalContractsController>();

  OsLegalContractModel get _contract {
    for (final c in _ctrl.contracts) {
      if (c.id == widget.contract.id) return c;
    }
    return widget.contract;
  }

  OsContractSettings get _settings => _ctrl.settings.value;

  Future<void> _previewEmail(OsLegalContractModel contract) async {
    final html = await buildOsLegalContractEmailHtml(contract);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720, maxHeight: 640),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  AppLocaleKeys.osEmailHubPreviewTitle.tr,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: context.appTheme.primaryText,
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(child: HtmlEmailPreview(html: html, minHeight: 480)),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(AppLocaleKeys.osInvoicesOk.tr),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _sendEmail(OsLegalContractModel contract) async {
    if (_emailSending) return;
    final email = contract.partyTwoEmail.trim();
    if (email.isEmpty) {
      await sendOsLegalContractEmail(contract);
      return;
    }
    if (!await confirmSendEmail(recipientEmail: email)) return;
    setState(() {
      _emailSending = true;
      _emailSuccess = false;
    });
    final ok = await sendOsLegalContractEmail(
      contract,
      skipSendConfirm: true,
    );
    if (!mounted) return;
    setState(() {
      _emailSending = false;
      _emailSuccess = ok;
    });
    if (ok) {
      Future<void>.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _emailSuccess = false);
      });
    }
  }

  Future<void> _copyText() async {
    await Clipboard.setData(
      ClipboardData(text: buildOsLegalContractPlainText(_contract, _settings)),
    );
    setState(() => _copied = true);
    Future<void>.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  Future<void> _changeStatus(String status) async {
    if (status == _contract.status) return;
    final ok = await _ctrl.updateStatus(_contract.id, status);
    if (ok && mounted) setState(() {});
  }

  String _partyOneName() => _contract.partyOneName.isNotEmpty
      ? _contract.partyOneName
      : _settings.agencyLegalName;

  String _partyOneRep() => _contract.partyOneRep.isNotEmpty
      ? _contract.partyOneRep
      : _settings.agencyAuthorizedSignatory;

  String _partyOneTitle() => _contract.partyOneTitle.isNotEmpty
      ? _contract.partyOneTitle
      : _settings.agencySignatoryTitle;

  String _partyOneAddress() => _contract.partyOneAddress.isNotEmpty
      ? _contract.partyOneAddress
      : _settings.agencyHeadquarters;

  String _partyTwoRoleLabel() {
    switch (_contract.targetType) {
      case OsLegalContractTargetType.client:
        return AppLocaleKeys.osLegalContractPartyTwoRoleClient.tr;
      case OsLegalContractTargetType.employee:
        return AppLocaleKeys.osLegalContractPartyTwoRoleEmployee.tr;
      case OsLegalContractTargetType.freelancer:
        return AppLocaleKeys.osLegalContractPartyTwoRoleFreelancer.tr;
      default:
        return AppLocaleKeys.osLegalContractPreviewPartyTwo.tr;
    }
  }

  String _undef(String value) =>
      value.trim().isEmpty ? AppLocaleKeys.osCommonUndefined.tr : value.trim();

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    final narrow = MediaQuery.sizeOf(context).width < 720;
    final contract = _contract;
    final settings = _settings;
    final start = FirestoreOsFinanceApi.formatDate(contract.startDate);
    final end = contract.endDate == null
        ? AppLocaleKeys.osCommonNa.tr
        : FirestoreOsFinanceApi.formatDate(contract.endDate!);

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: narrow ? 12 : 24,
        vertical: narrow ? 16 : 24,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 920,
          maxHeight: MediaQuery.sizeOf(context).height * 0.96,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _actionBar(context, theme, narrow, contract),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  narrow ? 16 : 24,
                  16,
                  narrow ? 16 : 24,
                  24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _documentHeader(theme, contract, settings, start),
                    const SizedBox(height: 20),
                    _partiesSection(theme, contract, settings),
                    const SizedBox(height: 20),
                    if (contract.scopeOfWork.trim().isNotEmpty) ...[
                      _sectionHeading(
                        theme,
                        Icons.description_outlined,
                        AppLocaleKeys.osLegalContractScopeOfWork.tr,
                      ),
                      const SizedBox(height: 8),
                      _boxedText(theme, contract.scopeOfWork.trim()),
                      const SizedBox(height: 20),
                    ],
                    _timelineGrid(theme, contract, start, end),
                    const SizedBox(height: 20),
                    _financialSection(theme, contract),
                    const SizedBox(height: 20),
                    _clausesSection(theme, contract),
                    if (contract.customTerms.trim().isNotEmpty) ...[
                      const SizedBox(height: 20),
                      _customTermsSection(theme, contract.customTerms.trim()),
                    ],
                    const SizedBox(height: 20),
                    _jurisdictionSection(theme, contract),
                    const SizedBox(height: 24),
                    _signaturesSection(theme, contract, settings),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionBar(
    BuildContext context,
    AppThemeExtension theme,
    bool narrow,
    OsLegalContractModel contract,
  ) {
    final titleIcon = Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        Icons.balance,
        color: theme.accentText,
        size: 22,
      ),
    );

    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              AppLocaleKeys.osLegalContractPreviewViewerTitle.tr,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: narrow ? 14 : 16,
                color: theme.primaryText,
              ),
            ),
            OsLegalContractStatusBadge(status: contract.status),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          '${contract.contractNumber} • ${contract.governingLaw}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11,
            fontFamily: 'monospace',
            color: theme.secondaryText,
          ),
        ),
      ],
    );

    final toolbarActions = _previewToolbarActions(
      context,
      theme,
      narrow,
      contract,
      showClose: !narrow,
    );

    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, narrow ? 12 : 8, 12),
      decoration: BoxDecoration(
        color: theme.elevatedSurface.withValues(alpha: 0.5),
        border: Border(bottom: BorderSide(color: theme.border)),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: narrow
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    titleIcon,
                    const SizedBox(width: 10),
                    Expanded(child: titleBlock),
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 40,
                        minHeight: 40,
                      ),
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close, color: theme.primaryText),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                toolbarActions,
              ],
            )
          : Row(
              children: [
                titleIcon,
                const SizedBox(width: 10),
                Expanded(child: titleBlock),
                toolbarActions,
              ],
            ),
    );
  }

  Widget _previewToolbarActions(
    BuildContext context,
    AppThemeExtension theme,
    bool narrow,
    OsLegalContractModel contract, {
    required bool showClose,
  }) {
    final children = <Widget>[
      IconButton(
        tooltip: AppLocaleKeys.osLegalContractPreviewCopyText.tr,
        onPressed: _copyText,
        icon: Icon(
          _copied ? Icons.check : Icons.copy_outlined,
          color: _copied ? AppColors.success : theme.secondaryText,
        ),
      ),
      IconButton(
        tooltip: AppLocaleKeys.osEmailHubPreviewTitle.tr,
        onPressed: () => _previewEmail(contract),
        icon: Icon(Icons.visibility_outlined, color: theme.secondaryText),
      ),
      if (narrow)
        IconButton(
          tooltip: AppLocaleKeys.osLegalContractEmailSend.tr,
          onPressed: _emailSending ? null : () => _sendEmail(contract),
          icon: _emailSending
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: theme.accentText,
                  ),
                )
              : Icon(
                  _emailSuccess ? Icons.check : Icons.send_outlined,
                  color: _emailSuccess ? AppColors.success : theme.secondaryText,
                ),
        )
      else
        FilledButton.icon(
          onPressed: _emailSending ? null : () => _sendEmail(contract),
          style: OsButtonStyles.secondaryCompact(theme),
          icon: _emailSending
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: theme.accentText,
                  ),
                )
              : Icon(
                  _emailSuccess ? Icons.check : Icons.send_outlined,
                  size: 18,
                  color: _emailSuccess ? AppColors.success : theme.accentText,
                ),
          label: Text(
            _emailSending
                ? AppLocaleKeys.osLegalContractEmailSending.tr
                : _emailSuccess
                    ? AppLocaleKeys.osLegalContractEmailSentShort.tr
                    : AppLocaleKeys.osLegalContractEmailSend.tr,
          ),
        ),
      if (!narrow) ...[
        const SizedBox(width: 6),
        SizedBox(
          width: 168,
          child: DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: contract.status,
            dropdownColor: theme.elevatedSurface,
            icon: Icon(Icons.expand_more, color: theme.secondaryText),
            decoration: osToolbarCompactFieldDecoration(context),
            selectedItemBuilder: (_) => osLegalContractStatusSelectedItems(),
            items: osLegalContractStatusDropdownItems(),
            onChanged: (v) {
              if (v != null) _changeStatus(v);
            },
          ),
        ),
        const SizedBox(width: 6),
      ],
      if (narrow)
        IconButton(
          tooltip: AppLocaleKeys.osLegalContractPrint.tr,
          onPressed: () => printOsLegalContract(contract),
          icon: Icon(Icons.print_outlined, color: theme.secondaryText),
        )
      else
        FilledButton.icon(
          onPressed: () => printOsLegalContract(contract),
          style: OsButtonStyles.printCompact(theme),
          icon: const Icon(Icons.print_outlined, size: 18),
          label: Text(AppLocaleKeys.osLegalContractPrint.tr),
        ),
      if (showClose)
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.close, color: theme.primaryText),
        ),
    ];

    if (narrow) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const SizedBox(width: 4),
              children[i],
            ],
          ],
        ),
      );
    }

    return Row(mainAxisSize: MainAxisSize.min, children: children);
  }

  Widget _documentHeader(
    AppThemeExtension theme,
    OsLegalContractModel contract,
    OsContractSettings settings,
    String start,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: theme.primaryText, width: 2),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: LayoutBuilder(
              builder: (context, c) {
                final stacked = c.maxWidth < 640;
                final agency = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            settings.agencyLegalName,
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              color: theme.primaryText,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (settings.agencyHeadquarters.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        settings.agencyHeadquarters,
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.secondaryText,
                        ),
                      ),
                    ],
                    if (settings.agencyCommercialReg.isNotEmpty ||
                        settings.agencyTaxNumber.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        [
                          if (settings.agencyCommercialReg.isNotEmpty)
                            '${AppLocaleKeys.osLegalContractSettingsCommercialReg.tr}: ${settings.agencyCommercialReg}',
                          if (settings.agencyTaxNumber.isNotEmpty)
                            '${AppLocaleKeys.osLegalContractSettingsTax.tr}: ${settings.agencyTaxNumber}',
                        ].join(' • '),
                        style: TextStyle(
                          fontSize: 10,
                          fontFamily: 'monospace',
                          color: theme.mutedText,
                        ),
                      ),
                    ],
                  ],
                );
                final docBox = Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: theme.border),
                    borderRadius: BorderRadius.circular(12),
                    color: theme.elevatedSurface.withValues(alpha: 0.4),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppLocaleKeys.osLegalContractPreviewDocNumber.tr,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: theme.secondaryText,
                        ),
                      ),
                      Text(
                        contract.contractNumber,
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontFamily: 'monospace',
                          color: theme.accentText,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${AppLocaleKeys.osLegalContractEffectiveDate.tr}: $start',
                        style: TextStyle(fontSize: 10, color: theme.mutedText),
                      ),
                    ],
                  ),
                );
                if (stacked) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [agency, const SizedBox(height: 12), docBox],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: agency),
                    const SizedBox(width: 16),
                    SizedBox(width: 220, child: docBox),
                  ],
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: theme.elevatedSurface.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.border),
          ),
          child: Column(
            children: [
              Text(
                contract.title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: theme.primaryText,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                AppLocaleKeys.osLegalContractPreviewCertifiedPer.trParams({
                  'law': contract.governingLaw,
                }),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: theme.secondaryText,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _partiesSection(
    AppThemeExtension theme,
    OsLegalContractModel contract,
    OsContractSettings settings,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.elevatedSurface.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionHeading(
            theme,
            Icons.business_outlined,
            AppLocaleKeys.osLegalContractPreviewPartiesSection.tr,
            showBorder: true,
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, c) {
              final stacked = c.maxWidth < 640;
              final partyOne = _partyCard(
                theme,
                title: AppLocaleKeys.osLegalContractPartyOneRole.tr,
                lines: [
                  _detailLine(
                    theme,
                    AppLocaleKeys.osLegalContractPartyCommercialName.tr,
                    _partyOneName(),
                  ),
                  _detailLine(
                    theme,
                    AppLocaleKeys.osLegalContractPartyRepresents.tr,
                    '${_partyOneRep()} (${_partyOneTitle()})',
                  ),
                  _detailLine(
                    theme,
                    AppLocaleKeys.osLegalContractPartyHeadquarters.tr,
                    _partyOneAddress(),
                  ),
                  _detailLine(
                    theme,
                    AppLocaleKeys.osLegalContractPartyPhone.tr,
                    _undef(
                      contract.partyOnePhone.isNotEmpty
                          ? contract.partyOnePhone
                          : settings.agencyPhone,
                    ),
                    ltr:
                        contract.partyOnePhone.isNotEmpty ||
                        settings.agencyPhone.isNotEmpty,
                  ),
                  _detailLine(
                    theme,
                    AppLocaleKeys.osLegalContractPartyEmail.tr,
                    _undef(
                      contract.partyOneEmail.isNotEmpty
                          ? contract.partyOneEmail
                          : settings.agencyEmail,
                    ),
                  ),
                ],
              );
              final partyTwo = _partyCard(
                theme,
                title: _partyTwoRoleLabel(),
                lines: [
                  _detailLine(
                    theme,
                    AppLocaleKeys.osLegalContractPartyName.tr,
                    contract.targetName,
                  ),
                  if (contract.partyTwoCompany.isNotEmpty)
                    _detailLine(
                      theme,
                      AppLocaleKeys.osLegalContractPartyCompany.tr,
                      contract.partyTwoCompany,
                    ),
                  if (contract.partyTwoJobTitle.isNotEmpty)
                    _detailLine(
                      theme,
                      AppLocaleKeys.osLegalContractPartyJobTitle.tr,
                      contract.partyTwoJobTitle,
                    ),
                  if (contract.partyTwoNationalId.isNotEmpty)
                    _detailLine(
                      theme,
                      AppLocaleKeys.osLegalContractPartyNationalId.tr,
                      contract.partyTwoNationalId,
                    ),
                  _detailLine(
                    theme,
                    AppLocaleKeys.osLegalContractPartyAddress.tr,
                    _undef(contract.partyTwoAddress),
                  ),
                  _detailLine(
                    theme,
                    AppLocaleKeys.osLegalContractPartyPhone.tr,
                    _undef(contract.partyTwoPhone),
                    ltr: contract.partyTwoPhone.isNotEmpty,
                  ),
                  _detailLine(
                    theme,
                    AppLocaleKeys.osLegalContractPartyEmail.tr,
                    _undef(contract.partyTwoEmail),
                  ),
                ],
              );
              if (stacked) {
                return Column(
                  children: [partyOne, const SizedBox(height: 12), partyTwo],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: partyOne),
                  const SizedBox(width: 12),
                  Expanded(child: partyTwo),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          Text(
            AppLocaleKeys.osLegalContractPreviewPreambleIntro.tr,
            style: TextStyle(
              fontSize: 11,
              fontStyle: FontStyle.italic,
              height: 1.5,
              color: theme.secondaryText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _partyCard(
    AppThemeExtension theme, {
    required String title,
    required List<Widget> lines,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.cardSurface,
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
              color: theme.accentText,
            ),
          ),
          const SizedBox(height: 8),
          ...lines,
        ],
      ),
    );
  }

  Widget _detailLine(
    AppThemeExtension theme,
    String label,
    String value, {
    bool ltr = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: RichText(
        text: TextSpan(
          style: TextStyle(
            fontSize: 11,
            color: theme.secondaryText,
            height: 1.4,
          ),
          children: [
            TextSpan(
              text: '$label: ',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: theme.mutedText,
              ),
            ),
            TextSpan(
              text: value,
              style: TextStyle(
                color: theme.primaryText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        textDirection: ltr ? TextDirection.ltr : null,
      ),
    );
  }

  Widget _timelineGrid(
    AppThemeExtension theme,
    OsLegalContractModel contract,
    String start,
    String end,
  ) {
    final tiles = <Widget>[
      _timelineTile(
        theme,
        AppLocaleKeys.osLegalContractPreviewTimelineStart.tr,
        start,
      ),
      _timelineTile(
        theme,
        AppLocaleKeys.osLegalContractPreviewTimelineEnd.tr,
        end,
      ),
      if (contract.probationPeriodDays != null)
        _timelineTile(
          theme,
          AppLocaleKeys.osLegalContractProbationDays.tr,
          '${contract.probationPeriodDays}',
        ),
      _timelineTile(
        theme,
        AppLocaleKeys.osLegalContractNoticeDays.tr,
        '${contract.noticePeriodDays ?? 30}',
      ),
    ];

    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth >= 640 ? 4 : 2;
        final itemW = (c.maxWidth - (cols - 1) * 8) / cols;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final tile in tiles) SizedBox(width: itemW, child: tile),
          ],
        );
      },
    );
  }

  Widget _timelineTile(AppThemeExtension theme, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.cardSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 10, color: theme.mutedText)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 12,
              color: theme.primaryText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _financialSection(
    AppThemeExtension theme,
    OsLegalContractModel contract,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _sectionHeading(
                theme,
                Icons.payments_outlined,
                AppLocaleKeys.osLegalContractPreviewFinancialSection.tr,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.success.withValues(alpha: 0.35),
                ),
              ),
              child: Text(
                '${AppLocaleKeys.osLegalContractTotalValue.tr}: ${osLegalContractMoneyLabel(contract.totalValue, contract.currency)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  color: AppColors.success,
                ),
              ),
            ),
          ],
        ),
        if (contract.salaryMonthly != null && contract.salaryMonthly! > 0) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppColors.success.withValues(alpha: 0.25),
              ),
            ),
            child: Text(
              AppLocaleKeys.osLegalContractSalaryMonthlyNote.trParams({
                'amount': osLegalContractMoneyLabel(
                  contract.salaryMonthly!,
                  contract.currency,
                ),
              }),
              style: TextStyle(
                fontSize: 11,
                color: theme.secondaryText,
                height: 1.4,
              ),
            ),
          ),
        ],
        if (contract.paymentTerms.isNotEmpty) ...[
          const SizedBox(height: 12),
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: theme.border),
              borderRadius: BorderRadius.circular(12),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 36,
                dataRowMinHeight: 40,
                dataRowMaxHeight: 56,
                columns: [
                  DataColumn(
                    label: Text(
                      AppLocaleKeys.osLegalContractPaymentMilestone.tr,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                        color: theme.secondaryText,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      AppLocaleKeys.osLegalContractPaymentPercent.tr,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                        color: theme.secondaryText,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      AppLocaleKeys.osLegalContractPaymentAmount.tr,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                        color: theme.secondaryText,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      AppLocaleKeys.osLegalContractPaymentDue.tr,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                        color: theme.secondaryText,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      AppLocaleKeys.osLegalContractStatus.tr,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                        color: theme.secondaryText,
                      ),
                    ),
                  ),
                ],
                rows: [
                  for (final p in contract.paymentTerms)
                    DataRow(
                      cells: [
                        DataCell(Text(p.milestone)),
                        DataCell(Text('${p.percentage.toStringAsFixed(0)}%')),
                        DataCell(
                          Text(
                            osLegalContractMoneyLabel(
                              p.amount,
                              contract.currency,
                            ),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: AppColors.success,
                            ),
                          ),
                        ),
                        DataCell(Text(p.dueDateDescription)),
                        DataCell(
                          Text(
                            p.isPaid
                                ? AppLocaleKeys
                                      .osLegalContractPaymentStatusPaid
                                      .tr
                                : AppLocaleKeys
                                      .osLegalContractPaymentStatusDue
                                      .tr,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: p.isPaid
                                  ? AppColors.success
                                  : AppColors.caution,
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _clausesSection(
    AppThemeExtension theme,
    OsLegalContractModel contract,
  ) {
    final clauses = contract.enabledClauses;
    if (clauses.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionHeading(
          theme,
          Icons.balance,
          AppLocaleKeys.osLegalContractPreviewClausesSection.tr,
          showBorder: true,
        ),
        const SizedBox(height: 12),
        for (final clause in clauses) ...[
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.elevatedSurface.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        clause.title,
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                          color: theme.primaryText,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  clause.content,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.55,
                    color: theme.secondaryText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _customTermsSection(AppThemeExtension theme, String text) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocaleKeys.osLegalContractPreviewCustomSection.tr,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 12,
              color: theme.primaryText,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              height: 1.5,
              color: theme.secondaryText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _jurisdictionSection(
    AppThemeExtension theme,
    OsLegalContractModel contract,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.elevatedSurface.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.border),
      ),
      child: Column(
        children: [
          Text(
            AppLocaleKeys.osLegalContractPreviewJurisdictionSection.tr,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 12,
              color: theme.primaryText,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppLocaleKeys.osLegalContractPreviewJurisdictionBody.trParams({
              'law': contract.governingLaw,
              'jurisdiction': contract.jurisdiction,
            }),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              height: 1.5,
              color: theme.secondaryText,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            AppLocaleKeys.osLegalContractPreviewJurisdictionCopies.tr,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10, color: theme.mutedText),
          ),
        ],
      ),
    );
  }

  Widget _signaturesSection(
    AppThemeExtension theme,
    OsLegalContractModel contract,
    OsContractSettings settings,
  ) {
    final showStamp =
        settings.enableDigitalStamp &&
        Get.isRegistered<OsStampSettingsController>() &&
        Get.find<OsStampSettingsController>().stampEnabled.value;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: theme.primaryText, width: 2)),
      ),
      child: Padding(
        padding: const EdgeInsets.only(top: 20),
        child: LayoutBuilder(
          builder: (context, c) {
            final stacked = c.maxWidth < 560;
            final sigOne = _signatureBlock(
              theme,
              title: AppLocaleKeys.osLegalContractPreviewPartyOne.tr,
              subtitle: _partyOneRep(),
              showStamp: showStamp,
            );
            final sigTwo = _signatureBlock(
              theme,
              title: contract.targetName,
              subtitle: AppLocaleKeys.osLegalContractPreviewPartyTwo.tr,
              showStamp: false,
            );
            if (stacked) {
              return Column(
                children: [sigOne, const SizedBox(height: 12), sigTwo],
              );
            }
            return Row(
              children: [
                Expanded(child: sigOne),
                const SizedBox(width: 16),
                Expanded(child: sigTwo),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _signatureBlock(
    AppThemeExtension theme, {
    required String title,
    required String subtitle,
    required bool showStamp,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.border),
      ),
      child: Column(
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 12,
              color: theme.primaryText,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10, color: theme.mutedText),
          ),
          SizedBox(
            height: 72,
            child: Center(
              child: showStamp ? const OsInvoiceStamp(compact: true) : null,
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: theme.border)),
            ),
            child: Text(
              AppLocaleKeys.osLegalContractPreviewOfficial.tr,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10, color: theme.mutedText),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeading(
    AppThemeExtension theme,
    IconData icon,
    String label, {
    bool showBorder = false,
  }) {
    final row = Row(
      children: [
        Icon(icon, size: 16, color: theme.accentText),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: theme.primaryText,
            ),
          ),
        ),
      ],
    );
    if (!showBorder) return row;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        row,
        const SizedBox(height: 8),
        Divider(color: theme.border, height: 1),
      ],
    );
  }

  Widget _boxedText(AppThemeExtension theme, String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.elevatedSurface.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.border),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          height: 1.55,
          color: theme.secondaryText,
        ),
      ),
    );
  }
}
