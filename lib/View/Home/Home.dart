import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Services/EmailNotificationService.dart';
import 'package:point/Services/FcmServices.dart' as fcm;
import 'package:point/Services/FireStoreServices.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Services/push_notification_test_catalog.dart';
import 'package:point/Services/StorageKeys.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/View/Clients/ClientsTable.dart';
import 'package:point/View/Contents/ContentDialogDetails.dart';
import 'package:point/View/Home/Shared/MonthlyClientContentChart.dart';
import 'package:point/View/Home/Shared/ReviewContentShared.dart';
import 'package:point/View/Shared/CustomCheckBox.dart';
import 'package:point/View/Shared/InputText.dart';
import 'package:point/View/Home/PushNotificationTestDialog.dart';
import 'package:point/View/Shared/ResponsiveScaffold.dart';
import 'package:point/View/Shared/button.dart';
import 'package:point/View/Shared/responsive.dart';
import 'package:point/View/Tasks/DetailsDialogs/DContentWriteDialog.dart';
import 'package:point/View/Tasks/DetailsDialogs/DDesignDialog.dart';
import 'package:point/View/Tasks/DetailsDialogs/DMontageDialog.dart';
import 'package:point/View/Tasks/DetailsDialogs/DPhotographyDialog.dart';
import 'package:point/View/Tasks/DetailsDialogs/DProgrammingDialog.dart';
import 'package:point/View/Tasks/DetailsDialogs/DPromotionDialog.dart';
import 'package:point/View/Tasks/DetailsDialogs/DPublishDialog.dart';

// Design tokens for mobile dashboard (clean, no overflow)
const double _kMobileCardRadius = 20.0;
const double _kMobileSectionSpacing = 20.0;
const double _kMobileCardPadding = 20.0;
const double _kMobileEmptyIconSize = 40.0;
const double _kMobileMinTouchHeight = 48.0;
const double _kMobileAccentBarHeight = 4.0;

/// Wraps a ListView.builder with a Scrollbar using a dedicated ScrollController
/// so the scroll position is attached (fixes "ScrollController has no ScrollPosition" on web).
class _ScrollableHomeList extends StatefulWidget {
  final int itemCount;
  final Widget Function(BuildContext context, int index) itemBuilder;

  const _ScrollableHomeList({
    required this.itemCount,
    required this.itemBuilder,
  });

  @override
  State<_ScrollableHomeList> createState() => _ScrollableHomeListState();
}

class _ScrollableHomeListState extends State<_ScrollableHomeList> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      controller: _scrollController,
      thumbVisibility: true,
      child: ListView.builder(
        controller: _scrollController,
        itemCount: widget.itemCount,
        itemBuilder: widget.itemBuilder,
      ),
    );
  }
}

class Home extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GetBuilder<HomeController>(
      builder: (controller) {
        final isMobile = Responsive.isMobile(context);
        return Scaffold(
          body: ResponsiveScaffold(
            body: SingleChildScrollView(
              child:
                  isMobile
                      ? SafeArea(
                        child: Container(
                          width: double.infinity,
                          color: AppColors.greyBackground,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: _buildHomeColumn(
                              context,
                              controller,
                              isMobile,
                            ),
                          ),
                        ),
                      )
                      : _buildHomeColumn(context, controller, isMobile),
            ),
            selectedTab: 0,
          ),
        );
      },
    );
  }

  Widget _buildHomeColumn(
    BuildContext context,
    HomeController controller,
    bool isMobile,
  ) {
    return Column(
      children: [
        SizedBox(height: isMobile ? _kMobileSectionSpacing : 20),
        Row(
          children: [
            if (isMobile) ...[
              Expanded(
                child: MainButton(
                  width: null,
                  height: _kMobileMinTouchHeight,
                  borderSize: 35,
                  fontColor: Colors.white,
                  backgroundColor: AppColors.primary,
                  widget: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        AppLocaleKeys.homeSendNotification.tr,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      Icon(
                        Icons.add_circle_outline_rounded,
                        color: Colors.white,
                      ),
                    ],
                  ),
                  onPressed: () => showAddNotifications(context),
                ),
              ),
            ] else ...[
              const Spacer(),
              MainButton(
                width: 180,
                height: 45,
                borderSize: 35,
                fontColor: Colors.white,
                backgroundColor: AppColors.primary,
                widget: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      AppLocaleKeys.homeSendNotification.tr,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    Icon(Icons.add_circle_outline_rounded, color: Colors.white),
                  ],
                ),
                onPressed: () => showAddNotifications(context),
              ),
            ],
          ],
        ),
        if (canOpenPushNotificationTester(
              controller.effectiveEmployee?.role,
            )) ...[
          SizedBox(height: isMobile ? 8 : 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: BorderSide(color: AppColors.primary.withValues(alpha: 0.5)),
                padding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: isMobile ? 12 : 14,
                ),
              ),
              onPressed: () => showPushNotificationTestDialog(context),
              icon: const Icon(Icons.notifications_active_outlined, size: 20),
              label: Text(
                AppLocaleKeys.pushTestOpenButton.tr,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
        SizedBox(height: isMobile ? _kMobileSectionSpacing : 20),
        ReviewContentWidget(),
        SizedBox(height: isMobile ? _kMobileSectionSpacing : 20),
        if (controller.contents.isNotEmpty && Responsive.isDesktop(context))
          MonthlyClientContentChart(),
        Responsive.isDesktop(context)
            ? SizedBox(
              height: 300,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  contentScheduletoday(context),
                  contentUnderPromotion(context),
                  tasksUnderProcessing(context),
                ],
              ),
            )
            : Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                contentScheduletoday(context),
                contentUnderPromotion(context),
                tasksUnderProcessing(context),
              ],
            ),
        SizedBox(height: isMobile ? _kMobileSectionSpacing : 25),
      ],
    );
  }
}

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

void showAddNotifications(BuildContext context) {
  final title = TextEditingController();
  final body = TextEditingController();
  DateTime date = DateTime.now();
  final datectr = TextEditingController(
    text: DateFormat('dd MM yyyy - hh:mm a').format(date.toLocal()),
  );
  // final passwordController = TextEditingController(text: model?.password);

  final _key = GlobalKey<FormState>();
  showDialog(
    barrierDismissible: false,
    context: context,
    builder: (context) {
      return Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: GetBuilder<HomeController>(
          builder: (controller) {
            return Form(
              key: _key,
              child: SizedBox(
                width:
                    Responsive.isDesktop(Get.context!)
                        ? Get.width * 0.4
                        : Get.width * 0.9,

                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header
                      Container(
                        margin: EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: Color(0xFF5C5589),
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(12),
                          ),
                        ),
                        padding: EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_today_outlined,
                              color: Colors.white,
                              size: 30,
                            ),
                            SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  AppLocaleKeys.homeNotificationFormTitle.tr,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                Text(
                                  AppLocaleKeys.homeNotificationFormSubtitle.tr,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Content
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  AppLocaleKeys.homeNotificationTarget.tr,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Obx(() {
                                  final selected =
                                      controller
                                          .selectedTypeNotifications
                                          .value;
                                  final isMobile = Responsive.isMobile(context);
                                  if (isMobile) {
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        _userTypeButton(
                                          AppLocaleKeys.homeUserTypeClients.tr,
                                          'clients',
                                          selected,
                                        ),
                                        const SizedBox(height: 10),
                                        _userTypeButton(
                                          AppLocaleKeys
                                              .homeUserTypeEmployees
                                              .tr,
                                          'employees',
                                          selected,
                                        ),
                                        const SizedBox(height: 10),
                                        _userTypeButton(
                                          AppLocaleKeys.homeUserTypeAll.tr,
                                          'all',
                                          selected,
                                        ),
                                      ],
                                    );
                                  }

                                  return Row(
                                    children: [
                                      Expanded(
                                        child: _userTypeButton(
                                          AppLocaleKeys.homeUserTypeClients.tr,
                                          'clients',
                                          selected,
                                        ),
                                      ),
                                      Expanded(
                                        child: _userTypeButton(
                                          AppLocaleKeys
                                              .homeUserTypeEmployees
                                              .tr,
                                          'employees',
                                          selected,
                                        ),
                                      ),
                                      Expanded(
                                        child: _userTypeButton(
                                          AppLocaleKeys.homeUserTypeAll.tr,
                                          'all',
                                          selected,
                                        ),
                                      ),
                                    ],
                                  );
                                }),
                              ],
                            ),

                            InputText(
                              labelText: AppLocaleKeys.homeNotificationTitle.tr,
                              hintText:
                                  AppLocaleKeys.homeNotificationTitleHint.tr,
                              height: 42,
                              fillColor: Colors.white,
                              controller: title,

                              validator: (v) {
                                if (v == null || v.isEmpty) {
                                  return ' ';
                                }
                                return null;
                              },

                              borderRadius: 5,
                              borderColor: Colors.grey.shade300,
                            ),
                            InputText(
                              onTap: () async {
                                final picked = await customDatePicker(context);
                                if (picked != null) {
                                  date = picked;
                                  datectr.text = DateFormat(
                                    'dd MM yyyy - hh:mm a',
                                  ).format(picked.toLocal());
                                }
                              },
                              labelText: AppLocaleKeys.homeNotificationDate.tr,
                              hintText: AppLocaleKeys.homeNotificationDate.tr,
                              height: 42,
                              fillColor: Colors.white,
                              textInputType: TextInputType.datetime,
                              controller: datectr,
                              readOnly: true,
                              validator: (v) {
                                if (v == null || v.isEmpty) return ' ';
                                return null;
                              },
                              suffixIcon: Icon(
                                CupertinoIcons.calendar,
                                color: Colors.grey,
                              ),
                              borderRadius: 5,
                              borderColor: Colors.grey.shade300,
                            ),
                            InputText(
                              labelText: AppLocaleKeys.homeNotificationBody.tr,
                              hintText:
                                  AppLocaleKeys.homeNotificationBodyHint.tr,
                              height: 42,
                              fillColor: Colors.white,
                              controller: body,
                              expanded: true,
                              validator: (v) {
                                if (v == null || v.isEmpty) {
                                  return ' ';
                                }
                                return null;
                              },
                              borderRadius: 5,
                              borderColor: Colors.grey.shade300,
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  AppLocaleKeys
                                      .homeNotificationSendChannelsTitle
                                      .tr,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: DynamicCheckbox(
                                        label:
                                            AppLocaleKeys
                                                .homeNotificationSendPush
                                                .tr,
                                        rxValue:
                                            controller.sendPushNotifications,
                                        activeColor: AppColors.primary,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: DynamicCheckbox(
                                        label:
                                            AppLocaleKeys
                                                .homeNotificationSendEmail
                                                .tr,
                                        rxValue:
                                            controller.sendEmailNotifications,
                                        activeColor: AppColors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Actions
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child:
                            Responsive.isDesktop(Get.context!)
                                ? Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceEvenly,
                                      children: [
                                        Obx(
                                          () => SizedBox(
                                            width: Get.width * 0.4 - 260,
                                            child: ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(
                                                  0xFF5C5589,
                                                ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(24),
                                                ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 48,
                                                      vertical: 20,
                                                    ),
                                              ),
                                              onPressed: () async {
                                                if (_key.currentState!
                                                        .validate() ==
                                                    true) {
                                                  final sendPush =
                                                      controller
                                                          .sendPushNotifications
                                                          .value;
                                                  final sendEmail =
                                                      controller
                                                          .sendEmailNotifications
                                                          .value;
                                                  if (!sendPush && !sendEmail) {
                                                    FunHelper.showSnackbar(
                                                      'error'.tr,
                                                      AppLocaleKeys
                                                          .homeNotificationSelectChannelsError
                                                          .tr,
                                                      snackPosition:
                                                          SnackPosition.TOP,
                                                      backgroundColor:
                                                          Colors.red,
                                                      colorText: Colors.white,
                                                    );
                                                    return;
                                                  }
                                                  controller.isLoading.value =
                                                      true;
                                                  await FirestoreServices.sendFcmTopic(
                                                    scheduledAt:
                                                        date.toString(),
                                                    topic:
                                                        controller
                                                            .selectedTypeNotifications
                                                            .value,
                                                    title: title.text,
                                                    body: body.text,
                                                    sendPush: sendPush,
                                                    sendEmail: sendEmail,
                                                    notificationType:
                                                        'broadcast_topic',
                                                  ).then((value) {
                                                    Navigator.pop(context);
                                                    FunHelper.showSnackbar(
                                                      'success'.tr,
                                                      AppLocaleKeys
                                                          .homeNotificationSent
                                                          .tr,
                                                      snackPosition:
                                                          SnackPosition.TOP,
                                                      backgroundColor:
                                                          Colors.green,
                                                      colorText: Colors.white,
                                                    );
                                                    controller.isLoading.value =
                                                        false;
                                                  });
                                                }
                                              },
                                              child:
                                                  controller.isLoading.value
                                                      ? const Center(
                                                        child:
                                                            CircularProgressIndicator(
                                                              color:
                                                                  Colors.white,
                                                            ),
                                                      )
                                                      : Text(
                                                        AppLocaleKeys
                                                            .commonConfirm
                                                            .tr,
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                            ),
                                          ),
                                        ),
                                        SizedBox(
                                          width: 190,
                                          child: OutlinedButton(
                                            style: OutlinedButton.styleFrom(
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(24),
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 32,
                                                    vertical: 20,
                                                  ),
                                            ),
                                            onPressed:
                                                () => Navigator.pop(context),
                                            child: Text(
                                              AppLocaleKeys.commonCancel.tr,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceEvenly,
                                      children: [
                                        SizedBox(
                                          width: 260,
                                          child: OutlinedButton(
                                            style: OutlinedButton.styleFrom(
                                              side: const BorderSide(
                                                color: Colors.green,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(24),
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 16,
                                                    vertical: 20,
                                                  ),
                                            ),
                                            onPressed: () async {
                                              if (_key.currentState!
                                                      .validate() ==
                                                  true) {
                                                await fcm.NotificationService()
                                                    .showTestLocalNotification(
                                                      title: title.text.trim(),
                                                      body: body.text.trim(),
                                                    );
                                                if (context.mounted) {
                                                  FunHelper.showSnackbar(
                                                    'success'.tr,
                                                    'تم عرض إشعار محلي (Local).',
                                                    snackPosition:
                                                        SnackPosition.TOP,
                                                    backgroundColor:
                                                        Colors.green,
                                                    colorText: Colors.white,
                                                  );
                                                }
                                              }
                                            },
                                            child: const Text(
                                              'اختبار إشعار محلي (Local)',
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                        ),
                                        SizedBox(
                                          width: 260,
                                          child: OutlinedButton(
                                            style: OutlinedButton.styleFrom(
                                              side: const BorderSide(
                                                color: Colors.blueAccent,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(24),
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 16,
                                                    vertical: 20,
                                                  ),
                                            ),
                                            onPressed: () async {
                                              if (_key.currentState!
                                                      .validate() ==
                                                  true) {
                                                final sendPush =
                                                    controller
                                                        .sendPushNotifications
                                                        .value;
                                                final sendEmail =
                                                    controller
                                                        .sendEmailNotifications
                                                        .value;
                                                if (!sendPush && !sendEmail) {
                                                  FunHelper.showSnackbar(
                                                    'error'.tr,
                                                    AppLocaleKeys
                                                        .homeNotificationSelectChannelsError
                                                        .tr,
                                                    snackPosition:
                                                        SnackPosition.TOP,
                                                    backgroundColor: Colors.red,
                                                    colorText: Colors.white,
                                                  );
                                                  return;
                                                }
                                                final empId =
                                                    controller
                                                        .currentemployee
                                                        .value
                                                        ?.id;
                                                if (empId == null ||
                                                    empId.isEmpty) {
                                                  FunHelper.showSnackbar(
                                                    'error'.tr,
                                                    'لا يوجد موظف متاح لإرسال Push.',
                                                    snackPosition:
                                                        SnackPosition.TOP,
                                                    backgroundColor: Colors.red,
                                                    colorText: Colors.white,
                                                  );
                                                  return;
                                                }

                                                await FirestoreServices.sendFcm(
                                                  userId: empId,
                                                  title: title.text.trim(),
                                                  body: body.text.trim(),
                                                  sendPush: sendPush,
                                                  sendEmail: sendEmail,
                                                );

                                                if (context.mounted) {
                                                  FunHelper.showSnackbar(
                                                    'success'.tr,
                                                    'تم إرسال Push إلى هاتفي الآن.',
                                                    snackPosition:
                                                        SnackPosition.TOP,
                                                    backgroundColor:
                                                        Colors.green,
                                                    colorText: Colors.white,
                                                  );
                                                }
                                              }
                                            },
                                            child: const Text(
                                              'إرسال Push إلى هاتفي الآن',
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                )
                                : Column(
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Obx(
                                            () => ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(
                                                  0xFF5C5589,
                                                ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(24),
                                                ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 16,
                                                      vertical: 20,
                                                    ),
                                              ),
                                              onPressed: () async {
                                                if (_key.currentState!
                                                        .validate() ==
                                                    true) {
                                                  final sendPush =
                                                      controller
                                                          .sendPushNotifications
                                                          .value;
                                                  final sendEmail =
                                                      controller
                                                          .sendEmailNotifications
                                                          .value;
                                                  if (!sendPush && !sendEmail) {
                                                    FunHelper.showSnackbar(
                                                      'error'.tr,
                                                      AppLocaleKeys
                                                          .homeNotificationSelectChannelsError
                                                          .tr,
                                                      snackPosition:
                                                          SnackPosition.TOP,
                                                      backgroundColor:
                                                          Colors.red,
                                                      colorText: Colors.white,
                                                    );
                                                    return;
                                                  }
                                                  controller.isLoading.value =
                                                      true;
                                                  await FirestoreServices.sendFcmTopic(
                                                    scheduledAt:
                                                        date.toString(),
                                                    topic:
                                                        controller
                                                            .selectedTypeNotifications
                                                            .value,
                                                    title: title.text,
                                                    body: body.text,
                                                    sendPush: sendPush,
                                                    sendEmail: sendEmail,
                                                    notificationType:
                                                        'broadcast_topic',
                                                  ).then((value) {
                                                    Navigator.pop(context);
                                                    FunHelper.showSnackbar(
                                                      'success'.tr,
                                                      AppLocaleKeys
                                                          .homeNotificationSent
                                                          .tr,
                                                      snackPosition:
                                                          SnackPosition.TOP,
                                                      backgroundColor:
                                                          Colors.green,
                                                      colorText: Colors.white,
                                                    );
                                                    controller.isLoading.value =
                                                        false;
                                                  });
                                                }
                                              },
                                              child:
                                                  controller.isLoading.value
                                                      ? const Center(
                                                        child:
                                                            CircularProgressIndicator(
                                                              color:
                                                                  Colors.white,
                                                            ),
                                                      )
                                                      : Text(
                                                        AppLocaleKeys
                                                            .commonConfirm
                                                            .tr,
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: OutlinedButton(
                                            style: OutlinedButton.styleFrom(
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(24),
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 16,
                                                    vertical: 20,
                                                  ),
                                            ),
                                            onPressed:
                                                () => Navigator.pop(context),
                                            child: Text(
                                              AppLocaleKeys.commonCancel.tr,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: OutlinedButton(
                                            style: OutlinedButton.styleFrom(
                                              side: const BorderSide(
                                                color: Colors.green,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(24),
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 16,
                                                    vertical: 18,
                                                  ),
                                            ),
                                            onPressed: () async {
                                              if (_key.currentState!
                                                      .validate() ==
                                                  true) {
                                                await fcm.NotificationService()
                                                    .showTestLocalNotification(
                                                      title: title.text.trim(),
                                                      body: body.text.trim(),
                                                    );
                                                if (context.mounted) {
                                                  FunHelper.showSnackbar(
                                                    'success'.tr,
                                                    'تم عرض إشعار محلي (Local).',
                                                    snackPosition:
                                                        SnackPosition.TOP,
                                                    backgroundColor:
                                                        Colors.green,
                                                    colorText: Colors.white,
                                                  );
                                                }
                                              }
                                            },
                                            child: const Text(
                                              'اختبار إشعار محلي (Local)',
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: OutlinedButton(
                                            style: OutlinedButton.styleFrom(
                                              side: const BorderSide(
                                                color: Colors.blueAccent,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(24),
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 16,
                                                    vertical: 18,
                                                  ),
                                            ),
                                            onPressed: () async {
                                              if (_key.currentState!
                                                      .validate() ==
                                                  true) {
                                                final sendPush =
                                                    controller
                                                        .sendPushNotifications
                                                        .value;
                                                final sendEmail =
                                                    controller
                                                        .sendEmailNotifications
                                                        .value;
                                                if (!sendPush && !sendEmail) {
                                                  FunHelper.showSnackbar(
                                                    'error'.tr,
                                                    AppLocaleKeys
                                                        .homeNotificationSelectChannelsError
                                                        .tr,
                                                    snackPosition:
                                                        SnackPosition.TOP,
                                                    backgroundColor: Colors.red,
                                                    colorText: Colors.white,
                                                  );
                                                  return;
                                                }
                                                final empId =
                                                    controller
                                                        .currentemployee
                                                        .value
                                                        ?.id;
                                                if (empId == null ||
                                                    empId.isEmpty) {
                                                  FunHelper.showSnackbar(
                                                    'error'.tr,
                                                    'لا يوجد موظف متاح لإرسال Push.',
                                                    snackPosition:
                                                        SnackPosition.TOP,
                                                    backgroundColor: Colors.red,
                                                    colorText: Colors.white,
                                                  );
                                                  return;
                                                }

                                                await FirestoreServices.sendFcm(
                                                  userId: empId,
                                                  title: title.text.trim(),
                                                  body: body.text.trim(),
                                                  sendPush: sendPush,
                                                  sendEmail: sendEmail,
                                                );

                                                if (context.mounted) {
                                                  FunHelper.showSnackbar(
                                                    'success'.tr,
                                                    'تم إرسال Push إلى هاتفي الآن.',
                                                    snackPosition:
                                                        SnackPosition.TOP,
                                                    backgroundColor:
                                                        Colors.green,
                                                    colorText: Colors.white,
                                                  );
                                                }
                                              }
                                            },
                                            child: const Text(
                                              'إرسال Push إلى هاتفي الآن',
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );
    },
  );
}

void showSendTestEmailDialog(BuildContext context) {
  final toEmailController = TextEditingController();
  final subjectController = TextEditingController(
    text: 'home.test_email.default_subject'.tr,
  );
  final bodyController = TextEditingController(
    text: 'home.test_email.default_body'.tr,
  );
  final _key = GlobalKey<FormState>();
  var isLoading = false.obs;

  showDialog(
    barrierDismissible: false,
    context: context,
    builder: (context) {
      return Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Form(
          key: _key,
          child: SizedBox(
            width:
                Responsive.isDesktop(Get.context!)
                    ? Get.width * 0.4
                    : Get.width * 0.9,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    margin: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(12),
                      ),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.email_outlined,
                          color: Colors.white,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'home.test_email.title'.tr,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              'home.test_email.subtitle'.tr,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        InputText(
                          labelText: 'home.test_email.to_label'.tr,
                          hintText: 'example@email.com',
                          height: 42,
                          fillColor: Colors.white,
                          controller: toEmailController,
                          textInputType: TextInputType.emailAddress,
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return 'home.test_email.validation_email'.tr;
                            }
                            return null;
                          },
                          borderRadius: 5,
                          borderColor: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 14),
                        InputText(
                          labelText: 'home.test_email.subject_label'.tr,
                          hintText: 'home.test_email.subject_hint'.tr,
                          height: 42,
                          fillColor: Colors.white,
                          controller: subjectController,
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return 'home.test_email.validation_subject'.tr;
                            }
                            return null;
                          },
                          borderRadius: 5,
                          borderColor: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 14),
                        InputText(
                          labelText: 'home.test_email.body_label'.tr,
                          hintText: 'home.test_email.body_hint'.tr,
                          height: 100,
                          fillColor: Colors.white,
                          controller: bodyController,
                          expanded: true,
                          borderRadius: 5,
                          borderColor: Colors.grey.shade300,
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Obx(
                          () => SizedBox(
                            width: 140,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 16,
                                ),
                              ),
                              onPressed:
                                  isLoading.value
                                      ? null
                                      : () async {
                                        if (!_key.currentState!.validate())
                                          return;
                                        isLoading.value = true;
                                        await EmailNotificationService.send(
                                          toEmail:
                                              toEmailController.text.trim(),
                                          subject:
                                              subjectController.text.trim(),
                                          body: bodyController.text.trim(),
                                        );
                                        isLoading.value = false;
                                        if (context.mounted)
                                          Navigator.pop(context);
                                        FunHelper.showSnackbar(
                                          'success'.tr,
                                          'home.test_email.success_snackbar'.tr,
                                          snackPosition: SnackPosition.TOP,
                                          backgroundColor: Colors.green,
                                          colorText: Colors.white,
                                        );
                                      },
                              child:
                                  isLoading.value
                                      ? const SizedBox(
                                        height: 22,
                                        width: 22,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                      : Text(
                                        'send'.tr,
                                        style: TextStyle(color: Colors.white),
                                      ),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 120,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 16,
                              ),
                            ),
                            onPressed: () => Navigator.pop(context),
                            child: Text(AppLocaleKeys.commonCancel.tr),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

Widget _userTypeButton(String label, String type, String selected) {
  final controller = Get.find<HomeController>();
  final isSelected = selected == type;

  return GestureDetector(
    onTap: () => controller.changeType(type),
    child: Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(
          color: Colors.grey.shade300,
          // width: 1.5,
        ),
        borderRadius: BorderRadius.circular(12),
        // color: isSelected ? Colors.deepPurple.withValues(alpha: 0.1) : Colors.white,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                // color: isSelected ? Colors.deepPurple : Colors.black,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Icon(
            isSelected
                ? Icons.radio_button_checked
                : Icons.radio_button_unchecked,
            color: isSelected ? Colors.deepPurple : Colors.grey,
            size: 22,
          ),
        ],
      ),
    ),
  );
}
