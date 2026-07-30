part of 'package:point/View/Home/Home.dart';

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
        backgroundColor: Theme.of(context).colorScheme.surface,
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
                          color: context.appTheme.navSurface,
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
                                  style: TextStyle(
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
                                          context,
                                          AppLocaleKeys.homeUserTypeClients.tr,
                                          'clients',
                                          selected,
                                        ),
                                        const SizedBox(height: 10),
                                        _userTypeButton(
                                          context,
                                          AppLocaleKeys
                                              .homeUserTypeEmployees
                                              .tr,
                                          'employees',
                                          selected,
                                        ),
                                        const SizedBox(height: 10),
                                        _userTypeButton(
                                          context,
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
                                          context,
                                          AppLocaleKeys.homeUserTypeClients.tr,
                                          'clients',
                                          selected,
                                        ),
                                      ),
                                      Expanded(
                                        child: _userTypeButton(
                                          context,
                                          AppLocaleKeys
                                              .homeUserTypeEmployees
                                              .tr,
                                          'employees',
                                          selected,
                                        ),
                                      ),
                                      Expanded(
                                        child: _userTypeButton(
                                          context,
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
                              controller: title,

                              validator: (v) {
                                if (v == null || v.isEmpty) {
                                  return ' ';
                                }
                                return null;
                              },

                              borderRadius: 5,
                            ),
                            InputText(
                              onTap: () async {
                                final picked = await customDatePicker(
                                  context,
                                  initialDateTime: date,
                                );
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
                              textInputType: TextInputType.datetime,
                              controller: datectr,
                              readOnly: true,
                              validator: (v) {
                                if (v == null || v.isEmpty) return ' ';
                                return null;
                              },
                              suffixIcon: Icon(
                                CupertinoIcons.calendar,
                                color: context.appTheme.secondaryText,
                              ),
                              borderRadius: 5,
                            ),
                            InputText(
                              labelText: AppLocaleKeys.homeNotificationBody.tr,
                              hintText:
                                  AppLocaleKeys.homeNotificationBodyHint.tr,
                              height: 42,
                              controller: body,
                              expanded: true,
                              validator: (v) {
                                if (v == null || v.isEmpty) {
                                  return ' ';
                                }
                                return null;
                              },
                              borderRadius: 5,
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  AppLocaleKeys
                                      .homeNotificationSendChannelsTitle
                                      .tr,
                                  style: TextStyle(
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
                                                backgroundColor: AppColors.primary,
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
                                                  final sendPush = controller
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
                                                        style: TextStyle(
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
                                                  final sendPush = controller
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
                                                  final empId =
                                                      controller
                                                          .currentEmployee
                                                          .value
                                                          ?.id;
                                                  if (empId == null ||
                                                      empId.isEmpty) {
                                                    FunHelper.showSnackbar(
                                                      'error'.tr,
                                                      'لا يوجد موظف متاح لإرسال Push.',
                                                      snackPosition:
                                                          SnackPosition.TOP,
                                                      backgroundColor:
                                                          Colors.red,
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
                                                    excludeCurrentActor: false,
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
                                                backgroundColor: AppColors.primary,
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
                                                  final sendPush = controller
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
                                                        style: TextStyle(
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
                                    ...[
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
                                                  final sendPush = controller
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
                                                  final empId =
                                                      controller
                                                          .currentEmployee
                                                          .value
                                                          ?.id;
                                                  if (empId == null ||
                                                      empId.isEmpty) {
                                                    FunHelper.showSnackbar(
                                                      'error'.tr,
                                                      'لا يوجد موظف متاح لإرسال Push.',
                                                      snackPosition:
                                                          SnackPosition.TOP,
                                                      backgroundColor:
                                                          Colors.red,
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
                                                    excludeCurrentActor: false,
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
        backgroundColor: Theme.of(context).colorScheme.surface,
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
                      color: context.appTheme.navSurface,
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
                          controller: toEmailController,
                          textInputType: TextInputType.emailAddress,
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return 'home.test_email.validation_email'.tr;
                            }
                            return null;
                          },
                          borderRadius: 5,
                        ),
                        const SizedBox(height: 14),
                        InputText(
                          labelText: 'home.test_email.subject_label'.tr,
                          hintText: 'home.test_email.subject_hint'.tr,
                          height: 42,
                          controller: subjectController,
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return 'home.test_email.validation_subject'.tr;
                            }
                            return null;
                          },
                          borderRadius: 5,
                        ),
                        const SizedBox(height: 14),
                        InputText(
                          labelText: 'home.test_email.body_label'.tr,
                          hintText: 'home.test_email.body_hint'.tr,
                          height: 100,
                          controller: bodyController,
                          expanded: true,
                          borderRadius: 5,
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
