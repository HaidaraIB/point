import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Utils/app_theme_extension.dart';
import 'package:point/View/Os/os_button_styles.dart';

/// Vertical gap between credential form controls (all payment dialogs).
const double kOsPaymentCredentialsFieldGap = 16;

Widget osPaymentCredentialsSecretPreview(
  BuildContext context,
  String translatedLine,
) {
  return Text(
    translatedLine,
    style: TextStyle(
      fontSize: 12,
      color: context.appTheme.mutedText,
    ),
  );
}

Widget osPaymentCredentialsEnvironmentField({
  required BuildContext context,
  required String environment,
  required ValueChanged<String> onEnvironmentSelected,
}) {
  final theme = context.appTheme;
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        AppLocaleKeys.osSettingsEnvironmentLabel.tr,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: theme.secondaryText,
        ),
      ),
      const SizedBox(height: 8),
      SegmentedButton<String>(
        segments: [
          ButtonSegment(
            value: 'test',
            label: Text(AppLocaleKeys.osSettingsEnvironmentTest.tr),
          ),
          ButtonSegment(
            value: 'live',
            label: Text(AppLocaleKeys.osSettingsEnvironmentLive.tr),
          ),
        ],
        selected: {environment},
        onSelectionChanged: (values) => onEnvironmentSelected(values.first),
      ),
    ],
  );
}

Widget osPaymentCredentialsSandboxButton({
  required BuildContext context,
  required VoidCallback onPressed,
  required String label,
}) {
  final theme = context.appTheme;
  return Align(
    alignment: AlignmentDirectional.centerStart,
    child: OutlinedButton.icon(
      onPressed: onPressed,
      style: OsButtonStyles.outlinedCompact(theme),
      icon: const Icon(Icons.science_outlined, size: 18),
      label: Text(label),
    ),
  );
}

Widget osPaymentCredentialsSaveRow({
  required BuildContext context,
  required bool saving,
  required VoidCallback onSave,
  required String label,
}) {
  return Align(
    alignment: AlignmentDirectional.centerEnd,
    child: FilledButton.icon(
      onPressed: saving ? null : onSave,
      style: OsButtonStyles.primaryCompact(),
      icon: saving
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.save_outlined, size: 18),
      label: Text(label),
    ),
  );
}

Widget osPaymentCredentialsObscureToggle({
  required bool obscure,
  required VoidCallback onToggle,
}) {
  return IconButton(
    onPressed: onToggle,
    icon: Icon(
      obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
      size: 18,
    ),
  );
}
