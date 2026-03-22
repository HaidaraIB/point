import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Services/StorageKeys.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/View/Home/Shared/ClientUnderReviewListPage.dart';

const double _kScrollStep = 220.0;

class ReviewContentWidget extends StatefulWidget {
  const ReviewContentWidget({super.key});

  @override
  State<ReviewContentWidget> createState() => _ReviewContentWidgetState();
}

class _ReviewContentWidgetState extends State<ReviewContentWidget> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollLeft() {
    if (!_scrollController.hasClients) return;
    final target = (_scrollController.offset - _kScrollStep)
        .clamp(0.0, _scrollController.position.maxScrollExtent);
    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  void _scrollRight() {
    if (!_scrollController.hasClients) return;
    final target = (_scrollController.offset + _kScrollStep)
        .clamp(0.0, _scrollController.position.maxScrollExtent);
    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  static const double _kMobileBreakpoint = 600;

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < _kMobileBreakpoint;
    final minTouchTarget = isMobile ? 48.0 : 40.0;

    return GetBuilder<HomeController>(
      builder: (controller) {
        final titleWidget = Padding(
          padding: EdgeInsets.only(
            right: isMobile ? 0 : 12.0,
            bottom: isMobile ? 12 : 0,
          ),
          child: Text(
            'home.review_carousel_title'.tr,
            textAlign: isMobile ? TextAlign.center : TextAlign.right,
            style: TextStyle(
              fontSize: isMobile ? 15 : 16,
              fontWeight: FontWeight.bold,
              color: AppColors.fontColorGrey,
            ),
          ),
        );

        final carouselRow = Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: minTouchTarget,
              height: minTouchTarget,
              child: IconButton(
                onPressed: _scrollLeft,
                icon: const Icon(Icons.arrow_back, color: Colors.teal),
                style: IconButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size(minTouchTarget, minTouchTarget),
                ),
              ),
            ),
            Expanded(
              child: _buildClientsCarousel(controller),
            ),
            SizedBox(
              width: minTouchTarget,
              height: minTouchTarget,
              child: IconButton(
                onPressed: _scrollRight,
                icon: const Icon(Icons.arrow_forward, color: Colors.teal),
                style: IconButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size(minTouchTarget, minTouchTarget),
                ),
              ),
            ),
          ],
        );

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(isMobile ? 16 : 0),
            boxShadow: isMobile
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          padding: EdgeInsets.symmetric(
            vertical: isMobile ? 14 : 6,
            horizontal: isMobile ? 14 : 5,
          ),
          margin: EdgeInsets.all(isMobile ? 0 : 5),
          child: isMobile
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    titleWidget,
                    carouselRow,
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    titleWidget,
                    const SizedBox(width: 50),
                    Expanded(child: carouselRow),
                    const SizedBox(width: 25),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildClientsCarousel(HomeController controller) {
    return Builder(
      builder: (context) {
        final underReview = controller.contents
            .where((c) => c.status == StorageKeys.status_under_revision)
            .toList();
        final seenClientIds = <String>{};
        final uniqueClientIds = <String>[];
        for (final c in underReview) {
          if (seenClientIds.add(c.clientId)) {
            uniqueClientIds.add(c.clientId);
          }
        }
        return SingleChildScrollView(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: uniqueClientIds.map((clientId) {
              final client = controller.clients
                  .firstWhereOrNull((a) => a.id == clientId);
              if (client == null) return const SizedBox.shrink();
              return InkWell(
                onTap: () {
                  showClientUnderReviewListDialog(
                    context,
                    clientId: clientId,
                    clientName: client.name ?? '',
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: Colors.teal.shade100,
                        child: client.image != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(25),
                                child: Image.network(
                                  client.image ?? '',
                                  fit: BoxFit.cover,
                                  height: 50,
                                  width: 50,
                                ),
                              )
                            : Text(
                                (client.name ?? '').isNotEmpty
                                    ? (client.name ?? '')[0]
                                    : '',
                                style: const TextStyle(
                                  color: Colors.teal,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        client.name ?? '',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}
