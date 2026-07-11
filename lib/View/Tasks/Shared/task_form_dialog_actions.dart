import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Utils/AppColors.dart';

/// Standard Save + Cancel row for task/update form dialogs.
class TaskFormDialogActions extends StatelessWidget {
  const TaskFormDialogActions({
    super.key,
    required this.onSave,
    required this.isLoading,
    this.onCancel,
    this.saveLabel,
    this.padding = const EdgeInsets.all(16),
  });

  final VoidCallback? onSave;
  final bool isLoading;
  final VoidCallback? onCancel;
  final String? saveLabel;
  final EdgeInsets padding;

  static const double buttonGap = 12;
  static const BorderRadius buttonRadius = BorderRadius.all(Radius.circular(24));

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: buttonRadius),
                padding: const EdgeInsets.symmetric(vertical: 20),
              ),
              onPressed: isLoading ? null : onSave,
              child: isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    )
                  : Text(
                      saveLabel ?? 'common.save'.tr,
                      style: TextStyle(color: Colors.white),
                    ),
            ),
          ),
          const SizedBox(width: buttonGap),
          Expanded(
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: buttonRadius),
                padding: const EdgeInsets.symmetric(vertical: 20),
              ),
              onPressed: onCancel ?? () => Navigator.pop(context),
              child: Text('common.cancel'.tr),
            ),
          ),
        ],
      ),
    );
  }
}
