import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Services/os_stamp_settings.dart';

/// Rectangular rotated stamp used on invoices (point_os Invoices.tsx style).
class OsInvoiceStamp extends StatelessWidget {
  const OsInvoiceStamp({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final stamp = Get.find<OsStampSettingsController>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Obx(() {
      if (!stamp.stampEnabled.value) return const SizedBox.shrink();
      final base = stamp.stampColor;
      final color = isDark
          ? Color.lerp(base, const Color(0xFFE8E4FF), 0.55)!
          : base;
      return Transform.rotate(
        angle: 2 * math.pi / 180,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 14 : 20,
            vertical: compact ? 8 : 10,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color, width: 2),
            color: color.withValues(alpha: isDark ? 0.12 : 0.04),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.12),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            stamp.stampText.value,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: compact ? 11 : 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
        ),
      );
    });
  }
}
