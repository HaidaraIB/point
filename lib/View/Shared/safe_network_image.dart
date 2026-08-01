import 'package:flutter/material.dart';

/// [Image.network] with [WebHtmlElementStrategy.prefer] so Flutter **web**
/// can still paint cross-origin R2/CDN images when CanvasKit CORS fails.
///
/// Prefer this (or [AttachmentThumbnailTile]) over bare [Image.network] for
/// any remote attachment / avatar / gallery URL that may be hosted off-origin.
class SafeNetworkImage extends StatelessWidget {
  const SafeNetworkImage(
    this.src, {
    super.key,
    this.width,
    this.height,
    this.fit,
    this.alignment = Alignment.center,
    this.errorBuilder,
    this.loadingBuilder,
    this.frameBuilder,
    this.semanticLabel,
    this.excludeFromSemantics = false,
    this.gaplessPlayback = false,
    this.filterQuality = FilterQuality.medium,
  });

  final String src;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final AlignmentGeometry alignment;
  final ImageErrorWidgetBuilder? errorBuilder;
  final ImageLoadingBuilder? loadingBuilder;
  final ImageFrameBuilder? frameBuilder;
  final String? semanticLabel;
  final bool excludeFromSemantics;
  final bool gaplessPlayback;
  final FilterQuality filterQuality;

  @override
  Widget build(BuildContext context) {
    return Image.network(
      src,
      width: width,
      height: height,
      fit: fit,
      alignment: alignment,
      errorBuilder: errorBuilder,
      loadingBuilder: loadingBuilder,
      frameBuilder: frameBuilder,
      semanticLabel: semanticLabel,
      excludeFromSemantics: excludeFromSemantics,
      gaplessPlayback: gaplessPlayback,
      filterQuality: filterQuality,
      webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
    );
  }
}
