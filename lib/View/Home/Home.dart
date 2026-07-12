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
import 'package:point/View/Tasks/DetailsDialogs/DAdministrativeDialog.dart';
import 'package:point/View/Tasks/DetailsDialogs/DProgrammingDialog.dart';
import 'package:point/View/Tasks/DetailsDialogs/DPromotionDialog.dart';
import 'package:point/View/Tasks/DetailsDialogs/DPublishDialog.dart';
import 'package:point/firebase_app_options.dart';
import 'package:point/Utils/AppConstants.dart';
import 'package:point/View/Shared/app_user_avatar.dart';
import 'package:point/Utils/app_theme_extension.dart';

part 'home_dashboard_sections_part.dart';
part 'home_notification_dialogs_part.dart';
part 'home_widgets_part.dart';

Widget _dashboardClientAvatar(HomeController controller, String clientId) {
  final client = controller.clients.firstWhereOrNull((a) => a.id == clientId);
  return AppUserAvatar(
    url: client?.image ?? kDefaultAvatarUrl,
    radius: 24,
    displayName: client?.name,
  );
}

// Design tokens for mobile dashboard (clean, no overflow)
const double _kMobileCardRadius = 20.0;
const double _kMobileSectionSpacing = 20.0;
const double _kMobileCardPadding = 20.0;
const double _kMobileEmptyIconSize = 40.0;
const double _kMobileMinTouchHeight = 48.0;
const double _kMobileAccentBarHeight = 4.0;
/// زرَا «إرسال إشعار» و«اختبار الإشعارات» على سطح المكتب — نفس المقاس بالضبط.
const double _kHomePairButtonWidth = 180.0;
const double _kHomePairButtonHeight = 45.0;
const double _kHomePairButtonRadius = 35.0;

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
            body:
                isMobile
                    ? RefreshIndicator(
                      onRefresh: () async {
                        controller.fetchTasks();
                        controller.fetchClients();
                        controller.fetchContents();
                        await Future.delayed(const Duration(seconds: 1));
                      },
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: SafeArea(
                          child: Container(
                            width: double.infinity,
                            color: context.appTheme.pageBackground,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: _buildHomeColumn(
                                context,
                                controller,
                                isMobile,
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                    : SingleChildScrollView(
                      child: _buildHomeColumn(context, controller, isMobile),
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
    final showPushTest =
        FirebaseAppOptions.isUsingTestFirebaseProject &&
        canOpenPushNotificationTester(controller.effectiveEmployee?.role);

    return Column(
      children: [
        SizedBox(height: isMobile ? _kMobileSectionSpacing : 20),
        Row(
          children: [
            if (isMobile) ...[
              Expanded(
                child: MainButton(
                  margin: EdgeInsets.zero,
                  width: double.infinity,
                  height: _kMobileMinTouchHeight,
                  borderSize: _kHomePairButtonRadius,
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
                        size: 20,
                      ),
                    ],
                  ),
                  onPressed: () => showAddNotifications(context),
                ),
              ),
              if (showPushTest) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    height: _kMobileMinTouchHeight,
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: context.appTheme.accentText,
                        side: BorderSide(
                          color: context.appTheme.accentBorder,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                        minimumSize: Size(0, _kMobileMinTouchHeight),
                        maximumSize: Size(
                          double.infinity,
                          _kMobileMinTouchHeight,
                        ),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            _kHomePairButtonRadius,
                          ),
                        ),
                      ),
                      onPressed: () => showPushNotificationTestDialog(context),
                      icon: const Icon(
                        Icons.notifications_active_outlined,
                        size: 20,
                      ),
                      label: Text(
                        AppLocaleKeys.pushTestOpenButton.tr,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ] else ...[
              const Spacer(),
              MainButton(
                margin: EdgeInsets.zero,
                width: _kHomePairButtonWidth,
                height: _kHomePairButtonHeight,
                borderSize: _kHomePairButtonRadius,
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
                      size: 20,
                    ),
                  ],
                ),
                onPressed: () => showAddNotifications(context),
              ),
              if (showPushTest) ...[
                const SizedBox(width: 10),
                SizedBox(
                  width: _kHomePairButtonWidth,
                  height: _kHomePairButtonHeight,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: context.appTheme.accentText,
                      side: BorderSide(
                        color: context.appTheme.accentBorder,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      minimumSize: Size(
                        _kHomePairButtonWidth,
                        _kHomePairButtonHeight,
                      ),
                      maximumSize: Size(
                        _kHomePairButtonWidth,
                        _kHomePairButtonHeight,
                      ),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          _kHomePairButtonRadius,
                        ),
                      ),
                    ),
                    onPressed: () => showPushNotificationTestDialog(context),
                    icon: const Icon(
                      Icons.notifications_active_outlined,
                      size: 20,
                    ),
                    label: Text(
                      AppLocaleKeys.pushTestOpenButton.tr,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],
            ],
          ],
        ),
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
