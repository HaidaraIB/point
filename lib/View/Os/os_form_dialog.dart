import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/Utils/app_theme_extension.dart';
import 'package:point/Utils/text_input_bidi.dart';

InputDecoration osFinanceFieldDecoration(
  String label, {
  String? hint,
}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.35)),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
  );
}

/// Sized dialog shell used by OS account/voucher forms (point_os style).
Future<bool?> showOsFormDialog({
  required BuildContext context,
  required String title,
  required Widget Function(
    BuildContext context,
    void Function(VoidCallback fn) setLocal,
  ) builder,
  IconData? titleIcon,
  String? saveLabel,
  IconData saveIcon = Icons.save_outlined,
  double maxWidth = 560,
  bool showSave = true,
  List<Widget>? headerActions,
}) {
  final narrow = MediaQuery.sizeOf(context).width < 600;
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (context, setLocal) {
          final theme = context.appTheme;
          final size = MediaQuery.sizeOf(context);
          final viewInsets = MediaQuery.viewInsetsOf(context);
          final maxH = size.height * (narrow ? 0.92 : 0.88) - viewInsets.bottom;
          return Dialog(
            insetPadding: EdgeInsets.symmetric(
              horizontal: narrow ? 12 : 28,
              vertical: narrow ? 16 : 28,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: AnimatedPadding(
              duration: const Duration(milliseconds: 100),
              padding: EdgeInsets.only(bottom: viewInsets.bottom),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: maxWidth,
                  maxHeight: maxH.clamp(280, size.height),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
                      child: Row(
                        children: [
                          if (titleIcon != null) ...[
                            Icon(titleIcon, color: theme.accentText, size: 24),
                            const SizedBox(width: 10),
                          ],
                          Expanded(
                            child: Text(
                              title,
                              style: TextStyle(
                                fontSize: narrow ? 17 : 20,
                                fontWeight: FontWeight.w800,
                                color: theme.primaryText,
                              ),
                            ),
                          ),
                          if (headerActions != null) ...headerActions,
                          IconButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            icon: Icon(
                              Icons.close,
                              color: theme.secondaryText,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 20),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                        child: builder(context, setLocal),
                      ),
                    ),
                    if (showSave)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                        child: SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () => Navigator.pop(ctx, true),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              textStyle: Theme.of(context)
                                  .textTheme
                                  .labelLarge
                                  ?.copyWith(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            icon: Icon(saveIcon, size: 20),
                            label: Text(
                              saveLabel ?? AppLocaleKeys.osCommonSave.tr,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

class OsTabToolbar extends StatelessWidget {
  const OsTabToolbar({
    super.key,
    this.title,
    this.subtitle,
    this.icon,
    this.leading,
    this.actions = const [],
    this.asCard = false,
  });

  final String? title;
  final String? subtitle;
  final IconData? icon;
  final Widget? leading;
  final List<Widget> actions;
  final bool asCard;

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    final narrow = MediaQuery.sizeOf(context).width < 640;

    Widget titleColumn() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Text(
              title!,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: theme.primaryText,
              ),
            ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: TextStyle(fontSize: 13, color: theme.secondaryText),
            ),
          ],
        ],
      );
    }

    final actionsCluster = actions.isEmpty
        ? const SizedBox.shrink()
        : Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: actions,
          );

    final hasTitle = title != null || subtitle != null;

    final content = narrow
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (icon != null || hasTitle || leading != null)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, color: theme.accentText, size: 22),
                      const SizedBox(width: 10),
                    ],
                    if (leading != null) ...[
                      Expanded(child: leading!),
                      if (hasTitle) const SizedBox(width: 12),
                    ],
                    if (hasTitle) Expanded(child: titleColumn()),
                  ],
                ),
              if (actions.isNotEmpty) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: actionsCluster,
                ),
              ],
            ],
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, color: theme.accentText, size: 22),
                const SizedBox(width: 10),
              ],
              if (leading != null)
                Expanded(
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: leading!,
                  ),
                ),
              if (hasTitle) Expanded(child: titleColumn()),
              if (!hasTitle && leading == null) const Spacer(),
              if (actions.isNotEmpty) ...[
                const SizedBox(width: 16),
                actionsCluster,
              ],
            ],
          );

    if (!asCard) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
        child: SizedBox(width: double.infinity, child: content),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.cardSurface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: theme.border),
        ),
        child: content,
      ),
    );
  }
}

InputDecoration osDialogFieldDecoration(
  BuildContext context, {
  String? hint,
  String? suffixText,
  Widget? prefixIcon,
}) {
  final theme = context.appTheme;
  return InputDecoration(
    filled: true,
    fillColor: theme.inputFill,
    hintText: hint,
    suffixText: suffixText,
    prefixIcon: prefixIcon,
    hintStyle: TextStyle(
      color: theme.mutedText,
      fontWeight: FontWeight.w600,
    ),
    suffixStyle: TextStyle(
      color: theme.mutedText,
      fontWeight: FontWeight.w800,
    ),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: theme.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
  );
}

/// Matches [OsButtonStyles.secondaryCompact] for toolbar dropdowns.
InputDecoration osToolbarCompactFieldDecoration(BuildContext context) {
  final theme = context.appTheme;
  return InputDecoration(
    filled: true,
    fillColor: theme.elevatedSurface,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: theme.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.primary, width: 1.2),
    ),
  );
}

/// [TextField] with paragraph direction from typed content, not UI locale.
Widget osTypedTextField({
  required TextEditingController controller,
  required InputDecoration decoration,
  ValueChanged<String>? onChanged,
  TextInputType? keyboardType,
  int? maxLines = 1,
  int? minLines,
  bool readOnly = false,
  VoidCallback? onTap,
  TextInputAction? textInputAction,
  ValueChanged<String>? onSubmitted,
  List<TextInputFormatter>? inputFormatters,
  TextStyle? style,
  TextAlignVertical? textAlignVertical,
  String? hintText,
  bool obscureText = false,
  bool enabled = true,
  FocusNode? focusNode,
  TextAlign textAlign = TextAlign.start,
  bool autofocus = false,
}) =>
    typedDirectionTextField(
      controller: controller,
      decoration: decoration,
      onChanged: onChanged,
      keyboardType: keyboardType,
      maxLines: maxLines,
      minLines: minLines,
      readOnly: readOnly,
      onTap: onTap,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      inputFormatters: inputFormatters,
      style: style,
      textAlignVertical: textAlignVertical,
      hintText: hintText,
      obscureText: obscureText,
      enabled: enabled,
      focusNode: focusNode,
      textAlign: textAlign,
      autofocus: autofocus,
    );

/// [TextFormField] with paragraph direction from typed content, not UI locale.
Widget osTypedTextFormField({
  required TextEditingController controller,
  required InputDecoration decoration,
  ValueChanged<String>? onChanged,
  String? Function(String?)? validator,
  TextInputType? keyboardType,
  int? maxLines = 1,
  int? minLines,
  bool readOnly = false,
  VoidCallback? onTap,
  TextInputAction? textInputAction,
  ValueChanged<String>? onFieldSubmitted,
  List<TextInputFormatter>? inputFormatters,
  TextStyle? style,
  TextAlignVertical? textAlignVertical,
  String? hintText,
  bool obscureText = false,
  bool enabled = true,
  FocusNode? focusNode,
  TextAlign textAlign = TextAlign.start,
  int? maxLength,
}) =>
    typedDirectionTextFormField(
      controller: controller,
      decoration: decoration,
      onChanged: onChanged,
      validator: validator,
      keyboardType: keyboardType,
      maxLines: maxLines,
      minLines: minLines,
      readOnly: readOnly,
      onTap: onTap,
      textInputAction: textInputAction,
      onFieldSubmitted: onFieldSubmitted,
      inputFormatters: inputFormatters,
      style: style,
      textAlignVertical: textAlignVertical,
      hintText: hintText,
      obscureText: obscureText,
      enabled: enabled,
      focusNode: focusNode,
      textAlign: textAlign,
      maxLength: maxLength,
    );

class OsDialogFrame extends StatelessWidget {
  const OsDialogFrame({
    super.key,
    required this.title,
    required this.body,
    required this.onClose,
    this.icon,
    this.closeEnabled = true,
    this.maxWidth = 460,
  });

  final String title;
  final Widget body;
  final VoidCallback onClose;
  final IconData? icon;
  final bool closeEnabled;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    return Dialog(
      backgroundColor: theme.cardSurface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 14, 14, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon, color: theme.accentText, size: 22),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: theme.primaryText,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: closeEnabled ? onClose : null,
                    icon: Icon(Icons.close, color: theme.secondaryText),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 8, right: 8),
                child: body,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Save + cancel row used by OS create/edit dialogs (Point OS style).
class OsFormDialogActions extends StatelessWidget {
  const OsFormDialogActions({
    super.key,
    required this.saveLabel,
    required this.onSave,
    required this.onCancel,
    this.saving = false,
    this.saveColor,
    this.saveIcon = Icons.save_outlined,
  });

  final String saveLabel;
  final VoidCallback onSave;
  final VoidCallback onCancel;
  final bool saving;
  final Color? saveColor;
  final IconData saveIcon;

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: SizedBox(
            height: 52,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: saveColor ?? AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              onPressed: saving ? null : onSave,
              icon: saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(saveIcon, size: 18),
              label: Text(saveLabel, textAlign: TextAlign.center),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: SizedBox(
            height: 52,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: theme.unselected,
                foregroundColor: theme.secondaryText,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              onPressed: saving ? null : onCancel,
              child: Text('cancel'.tr),
            ),
          ),
        ),
      ],
    );
  }
}

class OsEmptyState extends StatelessWidget {
  const OsEmptyState({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            color: theme.mutedText,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
