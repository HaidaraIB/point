import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:point/View/Os/os_form_dialog.dart';
import 'package:get/get.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Services/os_stamp_settings.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/Utils/app_theme_extension.dart';
import 'package:point/View/Os/os_electronic_stamp.dart';
import 'package:point/View/Os/os_snackbar.dart';

/// Polished stamp settings card (text, color picker, enable, live preview).
class OsStampSettingsPanel extends StatefulWidget {
  const OsStampSettingsPanel({super.key, this.embedded = false});

  /// When true, omits outer card chrome (for use inside [OsSettingsPage]).
  final bool embedded;

  @override
  State<OsStampSettingsPanel> createState() => _OsStampSettingsPanelState();
}

Widget _signaturePreview(String dataUri) {
  final match =
      RegExp(r'^data:image/[^;]+;base64,(.+)$').firstMatch(dataUri.trim());
  if (match == null) return const SizedBox.shrink();
  try {
    final bytes = base64Decode(match.group(1)!);
    return Image.memory(bytes, height: 56, fit: BoxFit.contain);
  } catch (_) {
    return const SizedBox.shrink();
  }
}

class _OsStampSettingsPanelState extends State<OsStampSettingsPanel> {
  late final TextEditingController _textCtrl;
  late final TextEditingController _hexCtrl;

  static const _presets = <Color>[
    Color(0xFF1e1b4b),
    Color(0xFF514091),
    Color(0xFF312E81),
    Color(0xFF0F766E),
    Color(0xFF1D4ED8),
    Color(0xFFBE123C),
    Color(0xFFB45309),
    Color(0xFF334155),
    Color(0xFFC4B5F5),
    Color(0xFF67E8F9),
  ];

  @override
  void initState() {
    super.initState();
    final stamp = Get.find<OsStampSettingsController>();
    _textCtrl = TextEditingController(text: stamp.stampText.value);
    _hexCtrl = TextEditingController(text: stamp.stampColorHex.value);
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _hexCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickSignatureImage(OsStampSettingsController stamp) async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
      maxWidth: 1600,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (bytes.isEmpty) return;
    if (bytes.length > OsStampSettingsController.maxSignatureBytes) {
      OsSnackbar.error(
        AppLocaleKeys.osInvoicesStampSection.tr,
        AppLocaleKeys.osInvoicesStampSignatureTooLarge.tr,
      );
      return;
    }
    final mime = picked.mimeType?.toLowerCase().contains('png') == true
        ? 'image/png'
        : 'image/jpeg';
    final dataUri = 'data:$mime;base64,${base64Encode(bytes)}';
    final ok = await stamp.setSignatureImageDataUri(dataUri);
    if (!ok) {
      OsSnackbar.error(
        AppLocaleKeys.osInvoicesStampSection.tr,
        AppLocaleKeys.osInvoicesStampSignatureTooLarge.tr,
      );
      return;
    }
    if (mounted) setState(() {});
  }

  Future<void> _openColorPicker(OsStampSettingsController stamp) async {
    var draft = stamp.stampColor;
    final picked = await showDialog<Color>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            final theme = context.appTheme;
            final hsv = HSVColor.fromColor(draft);
            return AlertDialog(
              title: Text(AppLocaleKeys.osInvoicesStampColor.tr),
              content: SizedBox(
                width: 340,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: draft,
                          shape: BoxShape.circle,
                          border: Border.all(color: theme.border, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: draft.withValues(alpha: 0.35),
                              blurRadius: 12,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      AppLocaleKeys.osInvoicesStampPresets.tr,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: theme.secondaryText,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final c in _presets)
                          InkWell(
                            onTap: () => setLocal(() => draft = c),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: c,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: draft.toARGB32() == c.toARGB32()
                                      ? AppColors.primary
                                      : theme.border,
                                  width: draft.toARGB32() == c.toARGB32()
                                      ? 2.5
                                      : 1,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      AppLocaleKeys.osInvoicesStampHue.tr,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.secondaryText,
                      ),
                    ),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 10,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 10,
                        ),
                      ),
                      child: Slider(
                        value: hsv.hue,
                        max: 360,
                        onChanged: (v) {
                          setLocal(() {
                            draft = hsv.withHue(v).toColor();
                          });
                        },
                      ),
                    ),
                    Text(
                      AppLocaleKeys.osInvoicesStampSaturation.tr,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.secondaryText,
                      ),
                    ),
                    Slider(
                      value: hsv.saturation,
                      onChanged: (v) {
                        setLocal(() {
                          draft = hsv.withSaturation(v).toColor();
                        });
                      },
                    ),
                    Text(
                      AppLocaleKeys.osInvoicesStampBrightness.tr,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.secondaryText,
                      ),
                    ),
                    Slider(
                      value: hsv.value,
                      onChanged: (v) {
                        setLocal(() {
                          draft = hsv.withValue(v).toColor();
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(AppLocaleKeys.osCommonCancel.tr),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                  ),
                  onPressed: () => Navigator.pop(ctx, draft),
                  child: Text(AppLocaleKeys.osCommonSave.tr),
                ),
              ],
            );
          },
        );
      },
    );
    if (picked == null) return;
    final hex =
        '#${picked.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';
    await stamp.setStampColorHex(hex);
    _hexCtrl.text = hex;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    final stamp = Get.find<OsStampSettingsController>();

    return Obx(() {
      final enabled = stamp.stampEnabled.value;
      final signatureUri = stamp.signatureImageDataUri.value.trim();
      final content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!widget.embedded) ...[
            Text(
              AppLocaleKeys.osInvoicesStampSection.tr,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: theme.primaryText,
              ),
            ),
            const SizedBox(height: 16),
          ],
          Text(
            AppLocaleKeys.osInvoicesStampSignatureImage.tr,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: theme.secondaryText,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            AppLocaleKeys.osInvoicesStampSignatureHint.tr,
            style: TextStyle(
              fontSize: 12,
              height: 1.45,
              color: theme.mutedText,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: () => _pickSignatureImage(stamp),
                icon: const Icon(Icons.upload_outlined, size: 18),
                label: Text(AppLocaleKeys.osInvoicesStampSignatureUpload.tr),
              ),
              if (signatureUri.isNotEmpty)
                OutlinedButton.icon(
                  onPressed: () async {
                    await stamp.clearSignatureImage();
                    if (mounted) setState(() {});
                  },
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: Text(AppLocaleKeys.osInvoicesStampSignatureRemove.tr),
                ),
            ],
          ),
          if (signatureUri.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.border),
                color: theme.pageBackground.withValues(alpha: 0.55),
              ),
              child: Center(
                child: _signaturePreview(signatureUri),
              ),
            ),
          ],
          const SizedBox(height: 18),
          LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 820;
                final textField = osTypedTextField(
                  controller: _textCtrl,
                  onChanged: stamp.setStampText,
                  decoration: InputDecoration(
                    labelText: AppLocaleKeys.osInvoicesStampText.tr,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 16,
                    ),
                  ),
                );
                final colorBlock = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocaleKeys.osInvoicesStampColor.tr,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: theme.secondaryText,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _openColorPicker(stamp),
                            borderRadius: BorderRadius.circular(12),
                            child: Ink(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: stamp.stampColor,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: theme.border),
                                boxShadow: [
                                  BoxShadow(
                                    color: stamp.stampColor
                                        .withValues(alpha: 0.35),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.colorize,
                                size: 18,
                                color: Colors.white70,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: osTypedTextField(
                            controller: _hexCtrl,
                            onChanged: (v) async {
                              await stamp.setStampColorHex(v);
                              setState(() {});
                            },
                            decoration: InputDecoration(
                              hintText: '#1e1b4b',
                              isDense: true,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 14,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final c in _presets.take(8))
                          InkWell(
                            onTap: () async {
                              final hex =
                                  '#${c.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';
                              await stamp.setStampColorHex(hex);
                              _hexCtrl.text = hex;
                              setState(() {});
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: c,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: stamp.stampColor.toARGB32() ==
                                          c.toARGB32()
                                      ? AppColors.primary
                                      : theme.border,
                                  width: stamp.stampColor.toARGB32() ==
                                          c.toARGB32()
                                      ? 2
                                      : 1,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                );
                final enableBlock = Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: FilterChip(
                    selected: enabled,
                    showCheckmark: true,
                    selectedColor: AppColors.primary.withValues(alpha: 0.25),
                    checkmarkColor: theme.accentText,
                    label: Text(
                      AppLocaleKeys.osInvoicesStampEnabled.tr,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: enabled
                            ? theme.primaryText
                            : theme.secondaryText,
                      ),
                    ),
                    onSelected: stamp.setStampEnabled,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                  ),
                );
                final preview = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocaleKeys.osInvoicesStampPreview.tr,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: theme.secondaryText,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: theme.border,
                          style: BorderStyle.solid,
                        ),
                        color: theme.pageBackground.withValues(alpha: 0.55),
                      ),
                      child: Center(
                        child: enabled
                            ? OsElectronicStamp(
                                reference:
                                    AppLocaleKeys.osVouchersStampDemoRef.tr,
                                size: 96,
                              )
                            : Text(
                                AppLocaleKeys.osInvoicesStampDisabledHint.tr,
                                style: TextStyle(
                                  color: theme.secondaryText,
                                  fontSize: 12,
                                ),
                              ),
                      ),
                    ),
                  ],
                );

                if (wide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: Column(
                          children: [
                            textField,
                            const SizedBox(height: 14),
                            colorBlock,
                            const SizedBox(height: 14),
                            enableBlock,
                          ],
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(flex: 2, child: preview),
                    ],
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    textField,
                    const SizedBox(height: 14),
                    colorBlock,
                    const SizedBox(height: 14),
                    enableBlock,
                    const SizedBox(height: 16),
                    preview,
                  ],
                );
              },
            ),
        ],
      );

      if (widget.embedded) return content;

      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: theme.cardSurface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: theme.border),
        ),
        child: content,
      );
    });
  }
}
