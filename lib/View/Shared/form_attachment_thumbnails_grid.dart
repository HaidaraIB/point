import 'package:flutter/material.dart';
import 'package:point/Utils/media_url_opener.dart';
import 'package:point/View/Shared/attachment_thumbnail_tile.dart';
import 'package:point/Utils/app_theme_extension.dart';

/// Two-column (default) grid of attachment thumbnails directly under a form
/// upload field. Tap opens in-app preview / player when possible.
class FormAttachmentThumbnailsGrid extends StatelessWidget {
  const FormAttachmentThumbnailsGrid({
    super.key,
    required this.urls,
    required this.onRemoveUrl,
    this.onOpenUrl,
    this.crossAxisCount = 2,
    this.spacing = 6,
    this.tileExtent = 88,
    this.closeButtonSize = 22,
    this.closeIconSize = 13,
  });

  final List<String> urls;
  final void Function(String url) onRemoveUrl;
  /// Opens preview / in-app player. Defaults to [openUrlPreferInAppMedia].
  final Future<void> Function(String url)? onOpenUrl;

  /// Horizontal and vertical gap between cells.
  final double spacing;

  final int crossAxisCount;
  final double tileExtent;
  final double closeButtonSize;
  final double closeIconSize;

  Future<void> _open(String url) async {
    final fn = onOpenUrl;
    if (fn != null) {
      await fn(url);
      return;
    }
    await openUrlPreferInAppMedia(url);
  }

  @override
  Widget build(BuildContext context) {
    if (urls.isEmpty) return const SizedBox.shrink();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: urls.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: spacing,
        mainAxisSpacing: spacing,
        mainAxisExtent: tileExtent,
      ),
      itemBuilder: (context, index) {
        final url = urls[index];
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: InkWell(
                onTap: () => _open(url),
                borderRadius: BorderRadius.circular(10),
                child: SizedBox.expand(
                  child: AttachmentThumbnailTile(
                    url: url,
                    borderRadius: 10,
                  ),
                ),
              ),
            ),
            PositionedDirectional(
              top: 4,
              end: 4,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => onRemoveUrl(url),
                  borderRadius: BorderRadius.circular(closeButtonSize / 2),
                  child: Container(
                    width: closeButtonSize,
                    height: closeButtonSize,
                    decoration: BoxDecoration(
                      color: context.appTheme.secondaryText,
                      borderRadius: BorderRadius.circular(closeButtonSize / 2),
                    ),
                    child: Icon(
                      Icons.close,
                      color: Colors.white,
                      size: closeIconSize,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
