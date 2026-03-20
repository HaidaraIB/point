import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Utils/AppColors.dart';

/// يعرض البريد بنفس إيقاع حقول [InputText] مع قفل وتوضيح — للمسؤول عند تعديل حساب غيره.
class ReadOnlyAccountEmailField extends StatelessWidget {
  const ReadOnlyAccountEmailField({
    super.key,
    required this.email,
    this.height = 42,
    this.borderRadius = 5,
    this.borderColor,
    this.fillColor,
    /// مسافة فوق صف التسمية وشارة «للقراءة فقط» (بعد حقل الاسم مثلاً).
    this.topSpacing = 16,
  });

  final String email;
  final double height;
  final double borderRadius;
  final Color? borderColor;
  final Color? fillColor;
  final double topSpacing;

  @override
  Widget build(BuildContext context) {
    final border = borderColor ?? Colors.grey.shade300;
    final fill = fillColor ?? Colors.white;
    final display = email.trim().isEmpty ? '—' : email.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (topSpacing > 0) SizedBox(height: topSpacing),
        Row(
          children: [
            Flexible(
              child: Text(
                'email'.tr,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.lock_outline_rounded,
                    size: 14,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'email_read_only_badge'.tr,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: height,
          width: double.infinity,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: border, width: 1.2),
          ),
          alignment: Alignment.center,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Icon(
                  Icons.alternate_email_rounded,
                  size: 20,
                  color: AppColors.fontColorGrey,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    display,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.primaryfontColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.blueGrey.shade50,
            borderRadius: BorderRadius.circular(borderRadius + 2),
            border: Border.all(color: Colors.blueGrey.shade100),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Icon(
                  Icons.info_outline_rounded,
                  size: 18,
                  color: Colors.blueGrey.shade600,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'credentials_owner_only_note'.tr,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: Colors.blueGrey.shade800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
