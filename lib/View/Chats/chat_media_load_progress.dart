import 'package:flutter/material.dart';

/// Fraction complete from an [ImageChunkEvent], or null when total size unknown.
double? chatMediaProgressValue(ImageChunkEvent? progress) {
  if (progress == null) return null;
  final total = progress.expectedTotalBytes;
  if (total == null || total <= 0) return null;
  return (progress.cumulativeBytesLoaded / total).clamp(0.0, 1.0);
}

/// Fraction complete from raw byte counts, or null when total size unknown.
double? chatMediaProgressFromBytes(int downloaded, int? totalSize) {
  if (totalSize == null || totalSize <= 0 || downloaded > totalSize) {
    return null;
  }
  return (downloaded / totalSize).clamp(0.0, 1.0);
}

/// Determinate circular progress when [value] is known; otherwise indeterminate.
class ChatMediaCircularProgress extends StatelessWidget {
  const ChatMediaCircularProgress({
    super.key,
    this.value,
    this.size = 20,
    this.strokeWidth = 2,
    this.color,
  });

  final double? value;
  final double size;
  final double strokeWidth;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        value: value,
        strokeWidth: strokeWidth,
        color: color,
      ),
    );
  }
}
