import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Services/os_stamp_settings.dart';

/// Circular electronic stamp used on vouchers / invoice preview (point_os).
class OsElectronicStamp extends StatelessWidget {
  const OsElectronicStamp({
    super.key,
    required this.reference,
    this.size = 112,
  });

  final String reference;
  final double size;

  @override
  Widget build(BuildContext context) {
    final stamp = Get.find<OsStampSettingsController>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Obx(() {
      if (!stamp.stampEnabled.value) return const SizedBox.shrink();
      // Dark navy stamp defaults are unreadable on dark UI — lighten for contrast.
      final base = stamp.stampColor;
      final color = isDark
          ? Color.lerp(base, const Color(0xFFE8E4FF), 0.55)!
          : base;
      return SizedBox(
        width: size,
        height: size,
        child: FittedBox(
          fit: BoxFit.contain,
          child: Transform.rotate(
            angle: 6 * math.pi / 180,
            child: Container(
              width: size,
              height: size,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 2.5),
                color: color.withValues(alpha: isDark ? 0.12 : 0.06),
              ),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: color.withValues(alpha: 0.75),
                    width: 1.2,
                  ),
                ),
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      AppLocaleKeys.osVouchersStampCertified.tr,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: color,
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      stamp.stampText.value,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: color,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'REF: $reference',
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: color,
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                        height: 1.1,
                      ),
                    ),
                    Text(
                      AppLocaleKeys.osVouchersStampDept.tr,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: color,
                        fontSize: 7,
                        fontWeight: FontWeight.w600,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    });
  }
}
