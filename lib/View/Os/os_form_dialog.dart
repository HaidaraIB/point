import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/Utils/app_theme_extension.dart';

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
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
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
                              textStyle: const TextStyle(
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
    required this.actions,
    this.asCard = false,
  });

  final String? title;
  final String? subtitle;
  final IconData? icon;
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

    final actionsDesktop = Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.end,
      children: actions,
    );

    final actionsMobile = actions.isEmpty
        ? const SizedBox.shrink()
        : Row(
            children: [
              for (var i = 0; i < actions.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    width: double.infinity,
                    child: actions[i],
                  ),
                ),
              ],
            ],
          );

    final content = narrow
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (icon != null || title != null || subtitle != null)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, color: theme.accentText, size: 22),
                      const SizedBox(width: 10),
                    ],
                    if (title != null || subtitle != null)
                      Expanded(child: titleColumn()),
                  ],
                ),
              if (title != null || subtitle != null) const SizedBox(height: 12),
              actionsMobile,
            ],
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, color: theme.accentText, size: 22),
                const SizedBox(width: 10),
              ],
              if (title != null || subtitle != null)
                Expanded(child: titleColumn())
              else
                const Spacer(),
              actionsDesktop,
            ],
          );

    if (!asCard) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
        child: content,
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
      child: Container(
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
