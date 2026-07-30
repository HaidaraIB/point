import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Localization/LanguageController.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/View/EmployeeDashboard/employee_dashboard_dialogs.dart';
import 'package:point/View/Shared/app_version_label.dart';
import 'package:point/View/Shared/app_theme_menu_button.dart';
import 'package:point/Services/StorageKeys.dart';
import 'package:point/Utils/AppConstants.dart';
import 'package:point/Utils/AppImages.dart';
import 'package:point/Utils/ContentPermissions.dart';
import 'package:point/Utils/LibraryPermissions.dart';
import 'package:point/View/Shared/app_user_avatar.dart';
import 'package:point/Utils/app_theme_extension.dart';

class CustomSidebar extends StatefulWidget {
  final int selectedTab;
  final int? subSelected;
  CustomSidebar({super.key, required this.selectedTab, this.subSelected = 20});

  @override
  State<CustomSidebar> createState() => _CustomSidebarState();
}

class _CustomSidebarState extends State<CustomSidebar> {
  Map<String, bool> openMenus = {};
  late int _selectedTab;
  int? _selectedSubTab;
  final LanguageController _languageController = Get.find<LanguageController>();

  String _departmentText(String slug) =>
      StorageKeys.semanticDepartmentLabelKey(slug).tr;

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.selectedTab;
    _selectedSubTab = widget.subSelected;
  }

  @override
  void didUpdateWidget(covariant CustomSidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _selectedTab = widget.selectedTab;
    if (oldWidget.subSelected != widget.subSelected) {
      _selectedSubTab = widget.subSelected;
    }
  }

  IconData _selectedNavArrowIcon(BuildContext context) {
    return Directionality.of(context) == TextDirection.rtl
        ? Icons.arrow_back
        : Icons.arrow_forward;
  }

  Widget _buildSidebarHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 40, 16, 0),
      child: Center(
        child: Image.asset(
          AppImages.images.logo,
          width: 180,
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  Future<void> _logoutFromDrawer(BuildContext context) async {
    final shouldLogout = await confirmEmployeeLogoutDialog(context);
    if (!shouldLogout) return;
    Get.find<HomeController>().clearEmployeeSession();
    Get.offAllNamed('/auth/login');
    FunHelper.scheduleFirebaseSignOutAndClearPrefs();
  }

  Widget _buildLanguageSelector() {
    final localeCode = Get.locale?.languageCode ?? 'ar';
    final currentLangLabel = localeCode == 'ar'
        ? AppLocaleKeys.appLanguageArabic.tr
        : AppLocaleKeys.appLanguageEnglish.tr;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          const Icon(
            Icons.language,
            color: Colors.white,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              AppLocaleKeys.appLanguage.tr,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
              ),
            ),
          ),
          Text(
            currentLangLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 2),
          PopupMenuButton<String>(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(
              minWidth: 36,
              minHeight: 36,
            ),
            color: Theme.of(context).colorScheme.surface,
            icon: const Icon(
              Icons.arrow_drop_down,
              color: Colors.white,
            ),
            onSelected:
                (value) => _languageController.changeLanguage(value),
            itemBuilder:
                (context) => [
                  PopupMenuItem(
                    value: 'ar',
                    child: Text(
                      AppLocaleKeys.appLanguageArabic.tr,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'en',
                    child: Text(
                      AppLocaleKeys.appLanguageEnglish.tr,
                    ),
                  ),
                ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 270,
      decoration: BoxDecoration(
        color: context.appTheme.navSurface,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 5)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSidebarHeader(),
          if (Get.width < 800) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 4),
              child: GetBuilder<HomeController>(
                builder: (controller) {
                  final employee = controller.effectiveEmployee;
                  final displayName = employee?.name ?? '';
                  final displayRole = employee?.role ?? '';
                  final displayImage = employee?.image ?? kDefaultAvatarUrl;
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Row(
                      children: [
                        AppUserAvatar(
                          url: displayImage,
                          radius: 20,
                          displayName: displayName,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                displayRole.tr,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'resetpassword'.tr,
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(
                            Icons.lock_reset_outlined,
                            color: Colors.white,
                          ),
                          onPressed: () {
                            Get.toNamed('/auth/resetPassword');
                          },
                        ),
                        IconButton(
                          tooltip: 'logout'.tr,
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(
                            Icons.logout,
                            color: Colors.redAccent,
                          ),
                          onPressed: () => _logoutFromDrawer(context),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],

          Expanded(
            child: GetBuilder<HomeController>(
              builder: (controller) {
                return Obx(
                  () => controller.effectiveEmployee?.role == 'admin'
                          ? ListView(
                            padding: const EdgeInsets.only(top: 8),
                            children: [
                              _buildTile(
                                selectedTab: 0,
                                icon: 'assets/images/nav_home.png',
                                text: "home".tr,
                                onTap: () {
                                  setState(() {
                                    _selectedTab = 0;
                                  });
                                  WidgetsBinding.instance.addPostFrameCallback((
                                    _,
                                  ) {
                                    Get.toNamed('/');
                                  });
                                },
                              ),

                              _buildTile(
                                selectedTab: 1,
                                icon: 'assets/images/nav_employees.png',
                                text: "employees".tr,
                                onTap: () {
                                  setState(() {
                                    _selectedTab = 1;
                                  });
                                  WidgetsBinding.instance.addPostFrameCallback((
                                    _,
                                  ) {
                                    Get.toNamed('/employees');
                                  });
                                },
                                // onTap: () => Get.toNamed('/users'),
                              ),
                              _buildTile(
                                selectedTab: 2,
                                icon: 'assets/images/nav_clients.png',
                                text: "clients".tr,
                                onTap: () {
                                  setState(() {
                                    _selectedTab = 2;
                                  });
                                  WidgetsBinding.instance.addPostFrameCallback((
                                    _,
                                  ) {
                                    Get.toNamed('/clients');
                                  });
                                },
                                // onTap: () => Get.toNamed('/users'),
                              ),
                              _buildTile(
                                selectedTab: 3,
                                icon: 'assets/images/nav_content.png',
                                text: "content".tr,
                                onTap: () {
                                  setState(() {
                                    _selectedTab = 3;
                                  });
                                  WidgetsBinding.instance.addPostFrameCallback((
                                    _,
                                  ) {
                                    Get.toNamed('/content');
                                  });
                                },
                                // onTap: () => Get.toNamed('/users'),
                              ),
                              if (ContentPermissions.canAccessPublishSection(
                                controller.effectiveEmployee,
                              ))
                                _buildTile(
                                  selectedTab: 10,
                                  icon: 'assets/images/nav_content.png',
                                  text: 'publish.sidebar'.tr,
                                  iconData: Icons.send_rounded,
                                  onTap: () {
                                    setState(() {
                                      _selectedTab = 10;
                                    });
                                    WidgetsBinding.instance.addPostFrameCallback((
                                      _,
                                    ) {
                                      Get.toNamed('/publish');
                                    });
                                  },
                                ),

                              _buildTile(
                                selectedTab: 9,
                                icon: 'assets/images/nav_content.png',
                                text: 'library.sidebar'.tr,
                                iconData: Icons.folder_copy_outlined,
                                onTap: () {
                                  setState(() {
                                    _selectedTab = 9;
                                  });
                                  WidgetsBinding.instance.addPostFrameCallback((
                                    _,
                                  ) {
                                    Get.toNamed('/library');
                                  });
                                },
                              ),

                              _buildExpansion(
                                id: 'tasks',
                                selectedTab: 4,

                                icon: 'assets/images/nav_tasks.png',
                                text: "tasks".tr,

                                children: [
                                  _buildSubTile(
                                    selectedTab: 0,
                                    text: _departmentText(
                                      StorageKeys.departmentPromotion,
                                    ),
                                    onTap: () {
                                      setState(() {
                                        _selectedSubTab = 0;
                                      });
                                      WidgetsBinding.instance
                                          .addPostFrameCallback((_) {
                                            Get.toNamed(
                                              '/tasks?department=promotion&id=0',
                                              arguments: 0,
                                              preventDuplicates: false,
                                            );
                                          });
                                    },
                                  ),
                                  _buildSubTile(
                                    selectedTab: 1,

                                    text: _departmentText(
                                      StorageKeys.departmentDesign,
                                    ),
                                    onTap: () {
                                      setState(() {
                                        _selectedSubTab = 1;
                                      });
                                      WidgetsBinding.instance
                                          .addPostFrameCallback((_) {
                                            Get.toNamed(
                                              '/tasks?department=design&id=1',
                                              arguments: 1,
                                              preventDuplicates: false,
                                            );
                                          });
                                    },
                                  ),
                                  _buildSubTile(
                                    selectedTab: 2,

                                    text: _departmentText(
                                      StorageKeys.departmentPhotography,
                                    ),
                                    onTap: () {
                                      setState(() {
                                        _selectedSubTab = 2;
                                      });
                                      WidgetsBinding.instance
                                          .addPostFrameCallback((_) {
                                            Get.toNamed(
                                              '/tasks?department=photography&id=2',
                                              arguments: 2,
                                              preventDuplicates: false,
                                            );
                                          });
                                    },
                                  ),
                                  _buildSubTile(
                                    selectedTab: 3,

                                    text: _departmentText(
                                      StorageKeys.departmentContentWriting,
                                    ),
                                    onTap: () {
                                      setState(() {
                                        _selectedSubTab = 3;
                                      });
                                      WidgetsBinding.instance
                                          .addPostFrameCallback((_) {
                                            Get.toNamed(
                                              '/tasks?department=content-writing&id=3',
                                              arguments: 2,
                                              preventDuplicates: false,
                                            );
                                          });
                                    },
                                  ),
                                  _buildSubTile(
                                    selectedTab: 4,

                                    text: _departmentText(
                                      StorageKeys.departmentMontage,
                                    ),
                                    onTap: () {
                                      setState(() {
                                        _selectedSubTab = 4;
                                      });
                                      WidgetsBinding.instance
                                          .addPostFrameCallback((_) {
                                            Get.toNamed(
                                              '/tasks?department=montage&id=4',
                                              arguments: 2,
                                              preventDuplicates: false,
                                            );
                                          });
                                    },
                                  ),
                                  _buildSubTile(
                                    selectedTab: 5,

                                    text: _departmentText(
                                      StorageKeys.departmentPublishing,
                                    ),
                                    onTap: () {
                                      setState(() {
                                        _selectedSubTab = 5;
                                      });
                                      WidgetsBinding.instance
                                          .addPostFrameCallback((_) {
                                            Get.toNamed(
                                              '/tasks?department=publishing&id=5',
                                              arguments: 2,
                                              preventDuplicates: false,
                                            );
                                          });
                                    },
                                  ),
                                  _buildSubTile(
                                    selectedTab: 6,

                                    text: _departmentText(
                                      StorageKeys.departmentProgramming,
                                    ),
                                    onTap: () {
                                      setState(() {
                                        _selectedSubTab = 6;
                                      });
                                      WidgetsBinding.instance
                                          .addPostFrameCallback((_) {
                                            Get.toNamed(
                                              '/tasks?department=programming&id=6',
                                              arguments: 2,
                                              preventDuplicates: false,
                                            );
                                          });
                                    },
                                  ),
                                  _buildSubTile(
                                    selectedTab: 7,
                                    text: _departmentText(
                                      StorageKeys.departmentAdministration,
                                    ),
                                    onTap: () {
                                      setState(() {
                                        _selectedSubTab = 7;
                                      });
                                      WidgetsBinding.instance
                                          .addPostFrameCallback((_) {
                                            Get.toNamed(
                                              '/tasks?department=administration&id=7',
                                              arguments: 7,
                                              preventDuplicates: false,
                                            );
                                          });
                                    },
                                  ),
                                ],
                              ),
                              _buildTile(
                                selectedTab: 6,
                                icon: 'assets/images/nav_statistics.png',
                                text: "statistcs".tr,
                                onTap: () {
                                  setState(() {
                                    _selectedTab = 6;
                                  });
                                  WidgetsBinding.instance.addPostFrameCallback((
                                    _,
                                  ) {
                                    Get.toNamed('/statistics');
                                  });
                                },
                                // onTap: () => Get.toNamed('/users'),
                              ),
                              _buildTile(
                                selectedTab: 12,
                                icon: 'assets/images/nav_history.png',
                                text: AppLocaleKeys.attendanceTitle.tr,
                                iconData: Icons.fingerprint_outlined,
                                onTap: () {
                                  WidgetsBinding.instance.addPostFrameCallback((
                                    _,
                                  ) {
                                    Get.toNamed('/attendance');
                                  });
                                },
                              ),
                              _buildTile(
                                selectedTab: 13,
                                icon: 'assets/images/nav_statistics.png',
                                text: AppLocaleKeys.attendanceReportsTitle.tr,
                                iconData: Icons.assessment_outlined,
                                onTap: () {
                                  WidgetsBinding.instance.addPostFrameCallback((
                                    _,
                                  ) {
                                    Get.toNamed('/attendanceReports');
                                  });
                                },
                              ),
                              _buildTile(
                                selectedTab: 11,
                                icon: 'assets/images/nav_history.png',
                                text: "admin_settings.title".tr,
                                iconData: Icons.settings_outlined,
                                onTap: () {
                                  setState(() {
                                    _selectedTab = 11;
                                  });
                                  WidgetsBinding.instance.addPostFrameCallback((
                                    _,
                                  ) {
                                    Get.toNamed('/adminSettings');
                                  });
                                },
                              ),
                              _buildTile(
                                selectedTab: 7,
                                icon: 'assets/images/nav_history.png',
                                text: "settings".tr,
                                iconData: Icons.history_rounded,
                                onTap: () {
                                  setState(() {
                                    _selectedTab = 7;
                                  });
                                  WidgetsBinding.instance.addPostFrameCallback((
                                    _,
                                  ) {
                                    Get.toNamed('/History');
                                  });
                                },
                                // onTap: () => Get.toNamed('/users'),
                              ),
                              _buildTile(
                                selectedTab: 8,
                                icon: 'assets/images/nav_history.png',
                                text: "TasksHistory".tr,
                                iconData: Icons.assignment_outlined,
                                onTap: () {
                                  setState(() {
                                    _selectedTab = 8;
                                  });
                                  WidgetsBinding.instance.addPostFrameCallback((
                                    _,
                                  ) {
                                    Get.toNamed('/TasksHistory');
                                  });
                                },
                                // onTap: () => Get.toNamed('/users'),
                              ),
                            ],
                          )
                          : controller.effectiveEmployee?.role == 'supervisor'
                          ? ListView(
                            padding: const EdgeInsets.only(top: 8),
                            children: [
                              _buildTile(
                                selectedTab: 0,
                                icon: 'assets/images/nav_home.png',
                                text: "home".tr,
                                onTap: () {
                                  setState(() {
                                    _selectedTab = 0;
                                  });
                                  WidgetsBinding.instance.addPostFrameCallback((
                                    _,
                                  ) {
                                    Get.toNamed('/');
                                  });
                                },
                              ),
                              _buildTile(
                                selectedTab: 1,
                                icon: 'assets/images/nav_employees.png',
                                text: "employees".tr,
                                onTap: () {
                                  setState(() {
                                    _selectedTab = 1;
                                  });
                                  WidgetsBinding.instance.addPostFrameCallback((
                                    _,
                                  ) {
                                    Get.toNamed('/employees');
                                  });
                                },
                              ),
                              _buildTile(
                                selectedTab: 2,
                                icon: 'assets/images/nav_clients.png',
                                text: "clients".tr,
                                onTap: () {
                                  setState(() {
                                    _selectedTab = 2;
                                  });
                                  WidgetsBinding.instance.addPostFrameCallback((
                                    _,
                                  ) {
                                    Get.toNamed('/clients');
                                  });
                                },
                              ),
                              _buildTile(
                                selectedTab: 3,
                                icon: 'assets/images/nav_content.png',
                                text: "content".tr,
                                onTap: () {
                                  setState(() {
                                    _selectedTab = 3;
                                  });
                                  WidgetsBinding.instance.addPostFrameCallback((
                                    _,
                                  ) {
                                    Get.toNamed('/content');
                                  });
                                },
                              ),
                              if (ContentPermissions.canAccessPublishSection(
                                controller.effectiveEmployee,
                              ))
                                _buildTile(
                                  selectedTab: 10,
                                  icon: 'assets/images/nav_content.png',
                                  text: 'publish.sidebar'.tr,
                                  iconData: Icons.send_rounded,
                                  onTap: () {
                                    setState(() {
                                      _selectedTab = 10;
                                    });
                                    WidgetsBinding.instance.addPostFrameCallback((
                                      _,
                                    ) {
                                      Get.toNamed('/publish');
                                    });
                                  },
                                ),
                              _buildTile(
                                selectedTab: 9,
                                icon: 'assets/images/nav_content.png',
                                text: 'library.sidebar'.tr,
                                iconData: Icons.folder_copy_outlined,
                                onTap: () {
                                  setState(() {
                                    _selectedTab = 9;
                                  });
                                  WidgetsBinding.instance.addPostFrameCallback((
                                    _,
                                  ) {
                                    Get.toNamed('/library');
                                  });
                                },
                              ),
                              _buildExpansion(
                                id: 'tasks',
                                selectedTab: 4,
                                icon: 'assets/images/nav_tasks.png',
                                text: "tasks".tr,
                                children: [
                                  _buildSubTile(
                                    selectedTab: 0,
                                    text: _departmentText(
                                      StorageKeys.departmentPromotion,
                                    ),
                                    onTap: () {
                                      setState(() {
                                        _selectedSubTab = 0;
                                      });
                                      WidgetsBinding.instance
                                          .addPostFrameCallback((_) {
                                            Get.toNamed(
                                              '/tasks?department=promotion&id=0',
                                              arguments: 0,
                                              preventDuplicates: false,
                                            );
                                          });
                                    },
                                  ),
                                  _buildSubTile(
                                    selectedTab: 1,
                                    text: _departmentText(
                                      StorageKeys.departmentDesign,
                                    ),
                                    onTap: () {
                                      setState(() {
                                        _selectedSubTab = 1;
                                      });
                                      WidgetsBinding.instance
                                          .addPostFrameCallback((_) {
                                            Get.toNamed(
                                              '/tasks?department=design&id=1',
                                              arguments: 1,
                                              preventDuplicates: false,
                                            );
                                          });
                                    },
                                  ),
                                  _buildSubTile(
                                    selectedTab: 2,
                                    text: _departmentText(
                                      StorageKeys.departmentPhotography,
                                    ),
                                    onTap: () {
                                      setState(() {
                                        _selectedSubTab = 2;
                                      });
                                      WidgetsBinding.instance
                                          .addPostFrameCallback((_) {
                                            Get.toNamed(
                                              '/tasks?department=photography&id=2',
                                              arguments: 2,
                                              preventDuplicates: false,
                                            );
                                          });
                                    },
                                  ),
                                  _buildSubTile(
                                    selectedTab: 3,
                                    text: _departmentText(
                                      StorageKeys.departmentContentWriting,
                                    ),
                                    onTap: () {
                                      setState(() {
                                        _selectedSubTab = 3;
                                      });
                                      WidgetsBinding.instance
                                          .addPostFrameCallback((_) {
                                            Get.toNamed(
                                              '/tasks?department=content-writing&id=3',
                                              arguments: 2,
                                              preventDuplicates: false,
                                            );
                                          });
                                    },
                                  ),
                                  _buildSubTile(
                                    selectedTab: 4,
                                    text: _departmentText(
                                      StorageKeys.departmentMontage,
                                    ),
                                    onTap: () {
                                      setState(() {
                                        _selectedSubTab = 4;
                                      });
                                      WidgetsBinding.instance
                                          .addPostFrameCallback((_) {
                                            Get.toNamed(
                                              '/tasks?department=montage&id=4',
                                              arguments: 2,
                                              preventDuplicates: false,
                                            );
                                          });
                                    },
                                  ),
                                  _buildSubTile(
                                    selectedTab: 5,
                                    text: _departmentText(
                                      StorageKeys.departmentPublishing,
                                    ),
                                    onTap: () {
                                      setState(() {
                                        _selectedSubTab = 5;
                                      });
                                      WidgetsBinding.instance
                                          .addPostFrameCallback((_) {
                                            Get.toNamed(
                                              '/tasks?department=publishing&id=5',
                                              arguments: 2,
                                              preventDuplicates: false,
                                            );
                                          });
                                    },
                                  ),
                                  _buildSubTile(
                                    selectedTab: 6,
                                    text: _departmentText(
                                      StorageKeys.departmentProgramming,
                                    ),
                                    onTap: () {
                                      setState(() {
                                        _selectedSubTab = 6;
                                      });
                                      WidgetsBinding.instance
                                          .addPostFrameCallback((_) {
                                            Get.toNamed(
                                              '/tasks?department=programming&id=6',
                                              arguments: 2,
                                              preventDuplicates: false,
                                            );
                                          });
                                    },
                                  ),
                                  _buildSubTile(
                                    selectedTab: 7,
                                    text: _departmentText(
                                      StorageKeys.departmentAdministration,
                                    ),
                                    onTap: () {
                                      setState(() {
                                        _selectedSubTab = 7;
                                      });
                                      WidgetsBinding.instance
                                          .addPostFrameCallback((_) {
                                            Get.toNamed(
                                              '/tasks?department=administration&id=7',
                                              arguments: 7,
                                              preventDuplicates: false,
                                            );
                                          });
                                    },
                                  ),
                                ],
                              ),
                            ],
                          )
                          : ListView(
                            padding: const EdgeInsets.only(top: 8),
                            children: [
                              _buildTile(
                                selectedTab: 0,
                                icon: 'assets/images/nav_tasks.png',
                                text: 'tasks'.tr,
                                onTap: () {
                                  setState(() => _selectedTab = 0);
                                  WidgetsBinding.instance.addPostFrameCallback((
                                    _,
                                  ) {
                                    Get.toNamed('/employeeDashboard');
                                  });
                                },
                              ),
                              if (controller.effectiveEmployee != null &&
                                  (controller.effectiveEmployee!.hasDepartment(
                                        StorageKeys.departmentPromotion,
                                      ) ||
                                      controller.effectiveEmployee!.hasDepartment(
                                        StorageKeys.departmentPublishing,
                                      )))
                                _buildTile(
                                  selectedTab: 3,
                                  icon: 'assets/images/nav_content.png',
                                  text: 'managecontent'.tr,
                                  onTap: () {
                                    setState(() => _selectedTab = 3);
                                    WidgetsBinding.instance.addPostFrameCallback((
                                      _,
                                    ) {
                                      Get.toNamed('/employeeContent');
                                    });
                                  },
                                ),
                              if (LibraryPermissions.canAccessLibrary(
                                controller.effectiveEmployee,
                              ))
                                _buildTile(
                                  selectedTab: 9,
                                  icon: 'assets/images/nav_content.png',
                                  text: 'library.sidebar'.tr,
                                  iconData: Icons.folder_copy_outlined,
                                  onTap: () {
                                    setState(() => _selectedTab = 9);
                                    WidgetsBinding.instance.addPostFrameCallback((
                                      _,
                                    ) {
                                      Get.toNamed('/library');
                                    });
                                  },
                                ),
                            ],
                          ),
                );
              },
            ),
          ),
          _buildLanguageSelector(),
          const AppThemeMenuButton(onDarkSurface: true),
          AppVersionLabel(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
            textStyle: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 12,
              height: 1.25,
            ),
            iconColor: Colors.white.withValues(alpha: 0.8),
            textAlign: TextAlign.center,
            safeAreaBottom: true,
          ),
        ],
      ),
    );
  }

  Widget _navIcon({
    required String icon,
    required Color color,
    IconData? iconData,
  }) {
    if (iconData != null) {
      return Icon(iconData, color: color, size: 22);
    }
    return Image.asset(
      icon,
      color: color,
      width: 22,
      height: 22,
      fit: BoxFit.contain,
    );
  }

  Widget _buildTile({
    required String icon,
    required String text,
    required VoidCallback onTap,
    required int selectedTab,
    IconData? iconData,
    Color? customColor,
  }) {
    final tileColor = customColor;
    final color =
        tileColor ??
        (selectedTab == _selectedTab
            ? Colors.white
            : Colors.white.withValues(alpha: 0.85));
    final selectedBg = Colors.white.withValues(alpha: 0.18);
    final decoration =
        selectedTab == _selectedTab
            ? BoxDecoration(
              color: selectedBg,
              borderRadius: BorderRadius.circular(3),
            )
            : null;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 5),
      decoration: decoration,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
        minLeadingWidth: 28,
        horizontalTitleGap: 8,
        minVerticalPadding: 0,
        visualDensity: VisualDensity.compact,
        leading: SizedBox(
          width: 28,
          child: Center(
            child: _navIcon(
              icon: icon,
              color: color,
              iconData: iconData,
            ),
          ),
        ),
        title: Text(
          text,
          style: TextStyle(
            fontSize: 14,
            color:
                tileColor ??
                (selectedTab == _selectedTab
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.85)),
            fontWeight: FontWeight.w500,
          ),
        ),
        onTap: onTap,
        trailing:
            selectedTab == _selectedTab
                ? Icon(
                  _selectedNavArrowIcon(context),
                  size: 18,
                  color: Colors.white,
                )
                : null,
      ),
    );
  }

  Widget _buildSubTile({
    required String text,
    required VoidCallback onTap,
    required int selectedTab,
  }) {
    final dotColor =
        selectedTab == _selectedSubTab
            ? Colors.white
            : Colors.white.withValues(alpha: 0.85);
    final textColor =
        selectedTab == _selectedSubTab
            ? Colors.white
            : Colors.white.withValues(alpha: 0.85);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 5),
      height: 30,
      decoration:
          selectedTab == _selectedSubTab
              ? BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(3),
              )
              : null,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                Icon(Icons.circle, size: 9, color: dotColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      color: textColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExpansion({
    required String id,
    required String icon,
    required int selectedTab,
    required String text,
    required List<Widget> children,
  }) {
    final iconColor =
        selectedTab == _selectedTab
            ? Colors.white
            : Colors.white.withValues(alpha: 0.85);
    final decoration =
        selectedTab == _selectedTab
            ? BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(3),
            )
            : null;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 5),
      decoration: decoration,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 8),
          childrenPadding: EdgeInsets.zero,
          leading: SizedBox(
            width: 28,
            child: Center(
              child: Image.asset(
                icon,
                color: iconColor,
                width: 22,
                height: 22,
                fit: BoxFit.contain,
              ),
            ),
          ),
          trailing: Icon(
            Icons.arrow_downward_outlined,
            color: Colors.white,
            size: 18,
          ),
          title: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color:
                  selectedTab == _selectedTab
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.85),
              fontWeight: FontWeight.w500,
            ),
          ),
          initiallyExpanded:
              openMenus[id] ??
              (selectedTab == _selectedTab ||
                  (id == 'tasks' && _selectedTab == 40)),
          onExpansionChanged: (expanded) {
            setState(() => openMenus[id] = expanded);
          },
          children: children,
        ),
      ),
    );
  }
}
