import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/EmployeeModel.dart';
import 'package:point/Utils/app_theme_extension.dart';
import 'package:point/View/Mobile/Shared/VideoCart.dart';
import 'package:point/View/Os/Expenses/os_expense_receipt_upload.dart';
import 'package:point/View/Os/os_snackbar.dart';
import 'package:point/View/Shared/InputText.dart';
import 'package:point/View/Shared/safe_network_image.dart';

/// Editable identity & residence fields for the admin employee form.
class EmployeeIdentityResidenceFields extends StatefulWidget {
  const EmployeeIdentityResidenceFields({
    super.key,
    required this.birthDateController,
    required this.addressController,
    required this.nationalIdNumberController,
    required this.residenceCardNumberController,
    required this.nationalIdCardUrl,
    required this.residenceCardUrl,
    required this.onNationalIdCardUrlChanged,
    required this.onResidenceCardUrlChanged,
    required this.birthDate,
    required this.onBirthDateChanged,
    this.employeeId,
  });

  final TextEditingController birthDateController;
  final TextEditingController addressController;
  final TextEditingController nationalIdNumberController;
  final TextEditingController residenceCardNumberController;
  final String? nationalIdCardUrl;
  final String? residenceCardUrl;
  final ValueChanged<String?> onNationalIdCardUrlChanged;
  final ValueChanged<String?> onResidenceCardUrlChanged;
  final DateTime? birthDate;
  final ValueChanged<DateTime?> onBirthDateChanged;
  final String? employeeId;

  @override
  State<EmployeeIdentityResidenceFields> createState() =>
      _EmployeeIdentityResidenceFieldsState();
}

class _EmployeeIdentityResidenceFieldsState
    extends State<EmployeeIdentityResidenceFields> {
  var _uploadingNational = false;
  var _uploadingResidence = false;

  Future<void> _pickBirthDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: widget.birthDate ?? DateTime(1995),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );
    if (picked == null) return;
    widget.onBirthDateChanged(picked);
    widget.birthDateController.text =
        '${picked.year.toString().padLeft(4, '0')}-'
        '${picked.month.toString().padLeft(2, '0')}-'
        '${picked.day.toString().padLeft(2, '0')}';
  }

  Future<void> _uploadCard({required bool national}) async {
    final file = await OsDocumentImageUpload.pick(source: ImageSource.gallery);
    if (file == null) return;
    setState(() {
      if (national) {
        _uploadingNational = true;
      } else {
        _uploadingResidence = true;
      }
    });
    try {
      final bytes = await file.readAsBytes();
      final prefix = national
          ? 'employee-national-${widget.employeeId ?? 'new'}'
          : 'employee-residence-${widget.employeeId ?? 'new'}';
      final url = await OsDocumentImageUpload.upload(
        fileNamePrefix: prefix,
        bytes: bytes,
      );
      if (url == null) {
        OsSnackbar.error(
          AppLocaleKeys.employeesIdentitySection.tr,
          AppLocaleKeys.osCommonSaveFailed.tr,
        );
        return;
      }
      if (national) {
        widget.onNationalIdCardUrlChanged(url);
      } else {
        widget.onResidenceCardUrlChanged(url);
      }
    } finally {
      if (mounted) {
        setState(() {
          _uploadingNational = false;
          _uploadingResidence = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          AppLocaleKeys.employeesIdentitySection.tr,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: theme.primaryText,
          ),
        ),
        const SizedBox(height: 12),
        InputText(
          labelText: AppLocaleKeys.employeesBirthDate.tr,
          hintText: AppLocaleKeys.employeesBirthDateHint.tr,
          height: 42,
          controller: widget.birthDateController,
          readOnly: true,
          borderRadius: 5,
          suffixIcon: Icon(
            Icons.calendar_today_outlined,
            size: 18,
            color: theme.mutedText,
          ),
          onTap: _pickBirthDate,
        ),
        InputText(
          labelText: AppLocaleKeys.employeesAddress.tr,
          hintText: AppLocaleKeys.employeesAddressHint.tr,
          height: 42,
          controller: widget.addressController,
          borderRadius: 5,
        ),
        InputText(
          labelText: AppLocaleKeys.employeesNationalIdNumber.tr,
          hintText: AppLocaleKeys.employeesNationalIdNumberHint.tr,
          height: 42,
          controller: widget.nationalIdNumberController,
          textInputType: TextInputType.number,
          borderRadius: 5,
        ),
        _ScanRow(
          label: AppLocaleKeys.employeesNationalIdCard.tr,
          url: widget.nationalIdCardUrl,
          uploading: _uploadingNational,
          onUpload: () => _uploadCard(national: true),
          onRemove: () => widget.onNationalIdCardUrlChanged(null),
        ),
        InputText(
          labelText: AppLocaleKeys.employeesResidenceCardNumber.tr,
          hintText: AppLocaleKeys.employeesResidenceCardNumberHint.tr,
          height: 42,
          controller: widget.residenceCardNumberController,
          borderRadius: 5,
        ),
        _ScanRow(
          label: AppLocaleKeys.employeesResidenceCard.tr,
          url: widget.residenceCardUrl,
          uploading: _uploadingResidence,
          onUpload: () => _uploadCard(national: false),
          onRemove: () => widget.onResidenceCardUrlChanged(null),
        ),
      ],
    );
  }
}

class _ScanRow extends StatelessWidget {
  const _ScanRow({
    required this.label,
    required this.url,
    required this.uploading,
    required this.onUpload,
    required this.onRemove,
  });

  final String label;
  final String? url;
  final bool uploading;
  final VoidCallback onUpload;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    final hasUrl = url != null && url!.trim().isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: theme.secondaryText,
            ),
          ),
          const SizedBox(height: 8),
          if (hasUrl)
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 64,
                    height: 64,
                    child: InkWell(
                      onTap: () => Get.to(() => ImagePreviewPage(url: url!)),
                      child: SafeNetworkImage(
                        url!,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: uploading ? null : onUpload,
                  child: Text(AppLocaleKeys.employeesIdentityUpload.tr),
                ),
                TextButton(
                  onPressed: uploading ? null : onRemove,
                  child: Text(AppLocaleKeys.employeesIdentityRemove.tr),
                ),
              ],
            )
          else
            OutlinedButton.icon(
              onPressed: uploading ? null : onUpload,
              icon: uploading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.upload_file_outlined, size: 18),
              label: Text(AppLocaleKeys.employeesIdentityUpload.tr),
            ),
        ],
      ),
    );
  }
}

/// Read-only identity block for the employee self-profile.
class EmployeeIdentityResidenceReadOnly extends StatelessWidget {
  const EmployeeIdentityResidenceReadOnly({super.key, required this.employee});

  final EmployeeModel employee;

  @override
  Widget build(BuildContext context) {
    if (!employee.hasIdentityOrResidence) {
      return const SizedBox.shrink();
    }
    final theme = context.appTheme;
    String fmtDate(DateTime? d) {
      if (d == null) return AppLocaleKeys.osCommonDash.tr;
      return '${d.year.toString().padLeft(4, '0')}-'
          '${d.month.toString().padLeft(2, '0')}-'
          '${d.day.toString().padLeft(2, '0')}';
    }

    Widget row(String label, String value) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: theme.mutedText,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value.trim().isEmpty ? AppLocaleKeys.osCommonDash.tr : value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: theme.primaryText,
              ),
            ),
          ],
        ),
      );
    }

    Widget scan(String label, String? url) {
      final u = url?.trim() ?? '';
      if (u.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
            InkWell(
              onTap: () => Get.to(() => ImagePreviewPage(url: u)),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 120,
                  height: 80,
                  child: SafeNetworkImage(u, fit: BoxFit.cover),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.panelTint,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            AppLocaleKeys.employeesIdentityViewOnly.tr,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: theme.primaryText,
            ),
          ),
          const SizedBox(height: 12),
          row(
            AppLocaleKeys.employeesBirthDate.tr,
            fmtDate(employee.birthDate),
          ),
          row(
            AppLocaleKeys.employeesAddress.tr,
            employee.address ?? '',
          ),
          row(
            AppLocaleKeys.employeesNationalIdNumber.tr,
            employee.nationalIdNumber ?? '',
          ),
          scan(
            AppLocaleKeys.employeesNationalIdCard.tr,
            employee.nationalIdCardUrl,
          ),
          row(
            AppLocaleKeys.employeesResidenceCardNumber.tr,
            employee.residenceCardNumber ?? '',
          ),
          scan(
            AppLocaleKeys.employeesResidenceCard.tr,
            employee.residenceCardUrl,
          ),
        ],
      ),
    );
  }
}
