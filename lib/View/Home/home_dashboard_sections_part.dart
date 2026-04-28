part of 'package:point/View/Home/Home.dart';

Widget contentScheduletoday(BuildContext context) {
  final isMobile = Responsive.isMobile(context);
  return GetBuilder<HomeController>(
    builder: (controller) {
      final today = DateTime.now();
      final contents =
          Get.find<HomeController>().contents.where((a) {
            final d = a.publishDate;
            if (d == null) return false;
            return d.year == today.year &&
                d.month == today.month &&
                d.day == today.day;
          }).toList();
      return Container(
        height: isMobile ? 300 : 270,
        constraints: null,
        width:
            Responsive.isDesktop(context)
                ? (Get.width - 300) / 3
                : (isMobile ? null : Get.width * 0.8),
        margin:
            isMobile
                ? const EdgeInsets.only(bottom: _kMobileSectionSpacing)
                : null,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(
            isMobile ? _kMobileCardRadius : 16,
          ),
          boxShadow:
              isMobile
                  ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.06),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                  : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.max,
          children: [
            if (isMobile)
              Container(
                height: _kMobileAccentBarHeight,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(_kMobileCardRadius),
                  ),
                ),
              ),
            SizedBox(height: isMobile ? 14 : 10),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? _kMobileCardPadding : 10,
                vertical: isMobile ? 0 : 10,
              ),
              child: Row(
                children: [
                  if (isMobile) ...[
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 20,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      AppLocaleKeys.homeScheduleToday.tr,
                      style: TextStyle(
                        fontSize: isMobile ? 15 : 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: isMobile ? 8 : 10),
            if (contents.isEmpty)
              Expanded(
                child: Center(
                  child: _buildEmptySection(
                    icon: Icons.calendar_today_outlined,
                    message: AppLocaleKeys.homeNoScheduleToday.tr,
                    compact: isMobile,
                  ),
                ),
              )
            else
              Expanded(
                child: _ScrollableHomeList(
                  itemCount: contents.length,
                  itemBuilder: (ctx, index) {
                    final content = contents[index];
                    return InkWell(
                      onTap: () {
                        controller.uploadedFilesPaths.assignAll(
                          content.files ?? [],
                        );
                        showContentDialogDetails(context, task: content);
                      },
                      child: Container(
                        constraints:
                            isMobile
                                ? const BoxConstraints(
                                  minHeight: _kMobileMinTouchHeight,
                                )
                                : null,
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: Colors.grey.shade200),
                          ),
                        ),
                        margin: EdgeInsets.symmetric(
                          horizontal: isMobile ? 8 : 5,
                          vertical: isMobile ? 6 : 5,
                        ),
                        padding: EdgeInsets.symmetric(
                          horizontal: isMobile ? 8 : 5,
                          vertical: isMobile ? 10 : 5,
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: Colors.teal.shade100,
                              child:
                                  controller.clients
                                              .firstWhereOrNull(
                                                (a) => a.id == content.clientId,
                                              )
                                              ?.image !=
                                          null
                                      ? ClipRRect(
                                        borderRadius: BorderRadius.circular(25),
                                        child: Image.network(
                                          controller.clients
                                                  .firstWhereOrNull(
                                                    (a) =>
                                                        a.id ==
                                                        content.clientId,
                                                  )
                                                  ?.image ??
                                              '',
                                          fit: BoxFit.cover,
                                          height: 50,
                                          width: 50,
                                          errorBuilder:
                                              (_, __, ___) => Text(
                                                controller.clients
                                                        .firstWhereOrNull(
                                                          (a) =>
                                                              a.id ==
                                                              content.clientId,
                                                        )
                                                        ?.name
                                                        .toString()[0] ??
                                                    '',
                                                style: const TextStyle(
                                                  color: Colors.teal,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                        ),
                                      )
                                      : Text(
                                        controller.clients
                                                .firstWhereOrNull(
                                                  (a) =>
                                                      a.id == content.clientId,
                                                )
                                                ?.name
                                                .toString()[0] ??
                                            '',
                                        style: const TextStyle(
                                          color: Colors.teal,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    content.title,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    controller.clients
                                            .firstWhereOrNull(
                                              (a) => a.id == content.clientId,
                                            )
                                            ?.name ??
                                        '',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      );
    },
  );
}

Widget _buildEmptySection({
  required IconData icon,
  required String message,
  bool compact = false,
}) {
  return Padding(
    padding:
        compact
            ? const EdgeInsets.symmetric(vertical: 16, horizontal: 16)
            : const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          icon,
          size: compact ? _kMobileEmptyIconSize : 48,
          color: Colors.grey.shade400,
        ),
        SizedBox(height: compact ? 10 : 12),
        Text(
          message,
          style: TextStyle(
            fontSize: compact ? 13 : 14,
            color: Colors.grey.shade600,
            height: 1.3,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}

Widget contentUnderPromotion(BuildContext context) {
  final isMobile = Responsive.isMobile(context);
  return GetBuilder<HomeController>(
    builder: (controller) {
      final contents =
          Get.find<HomeController>().contents.where((a) {
            return a.promotion == 'under_promotion';
          }).toList();
      return Container(
        height: isMobile ? 300 : 270,
        constraints: null,
        width:
            Responsive.isDesktop(context)
                ? (Get.width - 300) / 3
                : (isMobile ? null : Get.width * 0.8),
        margin:
            isMobile
                ? const EdgeInsets.only(bottom: _kMobileSectionSpacing)
                : null,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(
            isMobile ? _kMobileCardRadius : 16,
          ),
          boxShadow:
              isMobile
                  ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.06),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                  : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.max,
          children: [
            if (isMobile)
              Container(
                height: _kMobileAccentBarHeight,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(_kMobileCardRadius),
                  ),
                ),
              ),
            SizedBox(height: isMobile ? 14 : 10),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? _kMobileCardPadding : 10,
                vertical: isMobile ? 0 : 10,
              ),
              child:
                  isMobile
                      ? Row(
                        children: [
                          Icon(
                            Icons.campaign_rounded,
                            size: 20,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              AppLocaleKeys.homeUnderPromotion.tr,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      )
                      : Text(
                        AppLocaleKeys.homeUnderPromotion.tr,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
            ),
            SizedBox(height: isMobile ? 8 : 10),
            if (contents.isEmpty)
              Expanded(
                child: Center(
                  child: _buildEmptySection(
                    icon: Icons.campaign_outlined,
                    message: AppLocaleKeys.homeNoUnderPromotion.tr,
                    compact: isMobile,
                  ),
                ),
              )
            else
              Expanded(
                child: _ScrollableHomeList(
                  itemCount: contents.length,
                  itemBuilder: (ctx, index) {
                    final content = contents[index];
                    return InkWell(
                      onTap: () {
                        controller.uploadedFilesPaths.assignAll(
                          content.files ?? [],
                        );
                        showContentDialogDetails(context, task: content);
                      },
                      child: Container(
                        constraints:
                            isMobile
                                ? const BoxConstraints(
                                  minHeight: _kMobileMinTouchHeight,
                                )
                                : null,
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: Colors.grey.shade200),
                          ),
                        ),
                        margin: EdgeInsets.symmetric(
                          horizontal: isMobile ? 8 : 5,
                          vertical: isMobile ? 6 : 5,
                        ),
                        padding: EdgeInsets.symmetric(
                          horizontal: isMobile ? 8 : 5,
                          vertical: isMobile ? 10 : 5,
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: Colors.teal.shade100,
                              child:
                                  controller.clients
                                              .firstWhereOrNull(
                                                (a) => a.id == content.clientId,
                                              )
                                              ?.image !=
                                          null
                                      ? ClipRRect(
                                        borderRadius: BorderRadius.circular(25),
                                        child: Image.network(
                                          controller.clients
                                                  .firstWhereOrNull(
                                                    (a) =>
                                                        a.id ==
                                                        content.clientId,
                                                  )
                                                  ?.image ??
                                              '',
                                          fit: BoxFit.cover,
                                          height: 50,
                                          width: 50,
                                          errorBuilder:
                                              (_, __, ___) => Text(
                                                controller.clients
                                                        .firstWhereOrNull(
                                                          (a) =>
                                                              a.id ==
                                                              content.clientId,
                                                        )
                                                        ?.name
                                                        .toString()[0] ??
                                                    '',
                                                style: const TextStyle(
                                                  color: Colors.teal,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                        ),
                                      )
                                      : Text(
                                        controller.clients
                                                .firstWhereOrNull(
                                                  (a) =>
                                                      a.id == content.clientId,
                                                )
                                                ?.name
                                                .toString()[0] ??
                                            '',
                                        style: const TextStyle(
                                          color: Colors.teal,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    content.title,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    controller.clients
                                            .firstWhereOrNull(
                                              (a) => a.id == content.clientId,
                                            )
                                            ?.name ??
                                        '',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      );
    },
  );
}

Widget tasksUnderProcessing(BuildContext context) {
  final isMobile = Responsive.isMobile(context);
  return GetBuilder<HomeController>(
    builder: (controller) {
      final contents =
          Get.find<HomeController>().tasks.where((a) {
            return a.status == StorageKeys.status_processing;
          }).toList();
      return Container(
        height: isMobile ? 300 : 270,
        constraints: null,
        width:
            Responsive.isDesktop(context)
                ? (Get.width - 300) / 3
                : (isMobile ? null : Get.width * 0.8),
        margin:
            isMobile
                ? const EdgeInsets.only(bottom: _kMobileSectionSpacing)
                : null,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(
            isMobile ? _kMobileCardRadius : 16,
          ),
          boxShadow:
              isMobile
                  ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.06),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                  : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.max,
          children: [
            if (isMobile)
              Container(
                height: _kMobileAccentBarHeight,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(_kMobileCardRadius),
                  ),
                ),
              ),
            SizedBox(height: isMobile ? 14 : 10),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? _kMobileCardPadding : 10,
                vertical: isMobile ? 0 : 10,
              ),
              child:
                  isMobile
                      ? Row(
                        children: [
                          Icon(
                            Icons.pending_actions_rounded,
                            size: 20,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              AppLocaleKeys.homeTasksInProgress.tr,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      )
                      : Text(
                        AppLocaleKeys.homeTasksInProgress.tr,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
            ),
            SizedBox(height: isMobile ? 8 : 10),
            if (contents.isEmpty)
              Expanded(
                child: Center(
                  child: _buildEmptySection(
                    icon: Icons.pending_actions_outlined,
                    message: AppLocaleKeys.homeNoTasksInProgress.tr,
                    compact: isMobile,
                  ),
                ),
              )
            else
              Expanded(
                child: _ScrollableHomeList(
                  itemCount: contents.length,
                  itemBuilder: (ctx, index) {
                    final content = contents[index];
                    return InkWell(
                      onTap: () {
                        switch (content.type) {
                          case '0':
                            showCampaignDetailsDialog(context, task: content);
                            break;
                          case '1':
                            showDesignDetailsDialog(context, task: content);
                            break;
                          case '2':
                            showDPhotographyDialog(context, task: content);
                            break;
                          case '3':
                            showContentWriteDialog(context, task: content);
                            break;
                          case '4':
                            showMontageDialog(context, task: content);
                            break;
                          case '5':
                            showPublishDialog(context, task: content);
                            break;
                          case '6':
                            showProgrammingDialog(context, task: content);
                            break;
                          case '7':
                            showAdministrativeTaskDetailsDialog(
                              context,
                              task: content,
                            );
                            break;
                          default:
                        }
                      },
                      child: Container(
                        constraints:
                            isMobile
                                ? const BoxConstraints(
                                  minHeight: _kMobileMinTouchHeight,
                                )
                                : null,
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: Colors.grey.shade200),
                          ),
                        ),
                        margin: EdgeInsets.symmetric(
                          horizontal: isMobile ? 8 : 5,
                          vertical: isMobile ? 6 : 5,
                        ),
                        padding: EdgeInsets.symmetric(
                          horizontal: isMobile ? 8 : 5,
                          vertical: isMobile ? 10 : 5,
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: Colors.teal.shade100,
                              child:
                                  controller.clients
                                              .firstWhereOrNull(
                                                (a) =>
                                                    a.id == content.clientName,
                                              )
                                              ?.image !=
                                          null
                                      ? ClipRRect(
                                        borderRadius: BorderRadius.circular(25),
                                        child: Image.network(
                                          controller.clients
                                                  .firstWhereOrNull(
                                                    (a) =>
                                                        a.id ==
                                                        content.clientName,
                                                  )
                                                  ?.image ??
                                              '',
                                          fit: BoxFit.cover,
                                          height: 50,
                                          width: 50,
                                          errorBuilder:
                                              (_, __, ___) => Text(
                                                controller.clients
                                                        .firstWhereOrNull(
                                                          (a) =>
                                                              a.id ==
                                                              content
                                                                  .clientName,
                                                        )
                                                        ?.name
                                                        .toString()[0] ??
                                                    '',
                                                style: const TextStyle(
                                                  color: Colors.teal,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                        ),
                                      )
                                      : Text(
                                        controller.clients
                                                .firstWhereOrNull(
                                                  (a) =>
                                                      a.id ==
                                                      content.clientName,
                                                )
                                                ?.name
                                                .toString()[0] ??
                                            '',
                                        style: const TextStyle(
                                          color: Colors.teal,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    content.title,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    controller.clients
                                            .firstWhereOrNull(
                                              (a) => a.id == content.clientName,
                                            )
                                            ?.name ??
                                        '',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      );
    },
  );
}
