import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/Utils/AppImages.dart';

class CustomSidebar extends StatefulWidget {
  final int selectedTab;
  final int? subSelected;
  CustomSidebar({super.key, required this.selectedTab, this.subSelected = 20});

  @override
  State<CustomSidebar> createState() => _CustomSidebarState();
}

class _CustomSidebarState extends State<CustomSidebar> {
  Map<String, bool> openMenus = {};
  bool isCollapsed = false;
  late int _selectedtab;
  int? _subseletedtab;

  @override
  void initState() {
    super.initState();
    _selectedtab = widget.selectedTab;
    _subseletedtab = widget.subSelected;
  }

  @override
  void didUpdateWidget(covariant CustomSidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedTab != widget.selectedTab)
      _selectedtab = widget.selectedTab;
    if (oldWidget.subSelected != widget.subSelected)
      _subseletedtab = widget.subSelected;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: isCollapsed ? 70 : 270,
      // margin: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Color(0xff6736AE),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 5)],
        // borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 25),
          Image.asset(
            AppImages.images.logo,
            width: 180,
            // height: 50,
            fit: BoxFit.cover,
          ),

          Align(
            alignment: isCollapsed ? Alignment.center : Alignment.centerRight,
            child: IconButton(
              icon: Icon(
                isCollapsed ? Icons.arrow_forward_ios : Icons.arrow_back_ios,
                color: Colors.white,
                size: 16,
              ),
              onPressed: () {
                Get.width < 800
                    ? Scaffold.of(context).closeDrawer()
                    : setState(() {
                      isCollapsed = !isCollapsed;
                    });
              },
            ),
          ),

          Expanded(
            child: GetBuilder<HomeController>(
              builder: (controller) {
                return Obx(
                  () => (controller.effectiveEmployee?.role == 'admin' ||
                          controller.effectiveEmployee?.role == 'accountholder')
                          ? ListView(
                            children: [
                              _buildTile(
                                selectedTab: 0,
                                icon: 'assets/images/Home.png',
                                text: "home".tr,
                                onTap: () {
                                  setState(() {
                                    _selectedtab = 0;
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
                                icon: 'assets/images/User.png',
                                text: "employees".tr,
                                onTap: () {
                                  setState(() {
                                    _selectedtab = 1;
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
                                icon: 'assets/images/Frame.png',
                                text: "clients".tr,
                                onTap: () {
                                  setState(() {
                                    _selectedtab = 2;
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
                                icon: 'assets/images/Film.png',
                                text: "content".tr,
                                onTap: () {
                                  setState(() {
                                    _selectedtab = 3;
                                  });
                                  WidgetsBinding.instance.addPostFrameCallback((
                                    _,
                                  ) {
                                    Get.toNamed('/content');
                                  });
                                },
                                // onTap: () => Get.toNamed('/users'),
                              ),

                              _buildExpansion(
                                id: 'tasks',
                                selectedTab: 4,

                                icon: 'assets/images/Airplay.png',
                                text: "tasks".tr,

                                children: [
                                  _buildSubTile(
                                    selectedTab: 0,
                                    text: "cat1".tr,
                                    onTap: () {
                                      setState(() {
                                        _subseletedtab = 0;
                                      });
                                      WidgetsBinding.instance
                                          .addPostFrameCallback((_) {
                                            Get.toNamed(
                                              '/tasks?id=0',
                                              arguments: 0,
                                              preventDuplicates: false,
                                            );
                                          });
                                    },
                                  ),
                                  _buildSubTile(
                                    selectedTab: 1,

                                    text: "cat2".tr,
                                    onTap: () {
                                      setState(() {
                                        _subseletedtab = 1;
                                      });
                                      WidgetsBinding.instance
                                          .addPostFrameCallback((_) {
                                            Get.toNamed(
                                              '/tasks?id=1',
                                              arguments: 1,
                                              preventDuplicates: false,
                                            );
                                          });
                                    },
                                  ),
                                  _buildSubTile(
                                    selectedTab: 2,

                                    text: "cat3".tr,
                                    onTap: () {
                                      setState(() {
                                        _subseletedtab = 2;
                                      });
                                      WidgetsBinding.instance
                                          .addPostFrameCallback((_) {
                                            Get.toNamed(
                                              '/tasks?id=2',
                                              arguments: 2,
                                              preventDuplicates: false,
                                            );
                                          });
                                    },
                                  ),
                                  _buildSubTile(
                                    selectedTab: 3,

                                    text: "cat4".tr,
                                    onTap: () {
                                      setState(() {
                                        _subseletedtab = 3;
                                      });
                                      WidgetsBinding.instance
                                          .addPostFrameCallback((_) {
                                            Get.toNamed(
                                              '/tasks?id=3',
                                              arguments: 2,
                                              preventDuplicates: false,
                                            );
                                          });
                                    },
                                  ),
                                  _buildSubTile(
                                    selectedTab: 4,

                                    text: "cat5".tr,
                                    onTap: () {
                                      setState(() {
                                        _subseletedtab = 4;
                                      });
                                      WidgetsBinding.instance
                                          .addPostFrameCallback((_) {
                                            Get.toNamed(
                                              '/tasks?id=4',
                                              arguments: 2,
                                              preventDuplicates: false,
                                            );
                                          });
                                    },
                                  ),
                                  _buildSubTile(
                                    selectedTab: 5,

                                    text: "cat6".tr,
                                    onTap: () {
                                      setState(() {
                                        _subseletedtab = 5;
                                      });
                                      WidgetsBinding.instance
                                          .addPostFrameCallback((_) {
                                            Get.toNamed(
                                              '/tasks?id=5',
                                              arguments: 2,
                                              preventDuplicates: false,
                                            );
                                          });
                                    },
                                  ),
                                  _buildSubTile(
                                    selectedTab: 6,

                                    text: "cat7".tr,
                                    onTap: () {
                                      setState(() {
                                        _subseletedtab = 6;
                                      });
                                      WidgetsBinding.instance
                                          .addPostFrameCallback((_) {
                                            Get.toNamed(
                                              '/tasks?id=6',
                                              arguments: 2,
                                              preventDuplicates: false,
                                            );
                                          });
                                    },
                                  ),
                                ],
                              ),
                              _buildTile(
                                selectedTab: 6,
                                icon: 'assets/images/Frame(2).png',
                                text: "statistcs".tr,
                                onTap: () {
                                  setState(() {
                                    _selectedtab = 6;
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
                                selectedTab: 7,
                                icon: 'assets/images/Frame(1).png',
                                text: "settings".tr,
                                iconData: Icons.history_rounded,
                                onTap: () {
                                  setState(() {
                                    _selectedtab = 7;
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
                                icon: 'assets/images/Frame(1).png',
                                text: "TasksHistory".tr,
                                iconData: Icons.assignment_outlined,
                                onTap: () {
                                  setState(() {
                                    _selectedtab = 8;
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
                          : ListView(
                            children: [
                              _buildTile(
                                selectedTab: 3,
                                icon: 'assets/images/Film.png',
                                text: "content".tr,
                                onTap: () {
                                  setState(() {
                                    _selectedtab = 3;
                                  });
                                  WidgetsBinding.instance.addPostFrameCallback((
                                    _,
                                  ) {
                                    Get.toNamed('/content');
                                  });
                                },
                                // onTap: () => Get.toNamed('/users'),
                              ),

                              _buildExpansion(
                                id: 'tasks',
                                selectedTab: 4,

                                icon: 'assets/images/Airplay.png',
                                text: "tasks".tr,

                                children: [
                                  _buildSubTile(
                                    selectedTab: 0,
                                    text: "cat1".tr,
                                    onTap: () {
                                      setState(() {
                                        _subseletedtab = 0;
                                      });
                                      WidgetsBinding.instance
                                          .addPostFrameCallback((_) {
                                            Get.toNamed(
                                              '/tasks?id=0',
                                              arguments: 0,
                                              preventDuplicates: false,
                                            );
                                          });
                                    },
                                  ),
                                  _buildSubTile(
                                    selectedTab: 1,

                                    text: "cat2".tr,
                                    onTap: () {
                                      setState(() {
                                        _subseletedtab = 1;
                                      });
                                      WidgetsBinding.instance
                                          .addPostFrameCallback((_) {
                                            Get.toNamed(
                                              '/tasks?id=1',
                                              arguments: 1,
                                              preventDuplicates: false,
                                            );
                                          });
                                    },
                                  ),
                                  _buildSubTile(
                                    selectedTab: 2,

                                    text: "cat3".tr,
                                    onTap: () {
                                      setState(() {
                                        _subseletedtab = 2;
                                      });
                                      WidgetsBinding.instance
                                          .addPostFrameCallback((_) {
                                            Get.toNamed(
                                              '/tasks?id=2',
                                              arguments: 2,
                                              preventDuplicates: false,
                                            );
                                          });
                                    },
                                  ),
                                  _buildSubTile(
                                    selectedTab: 3,

                                    text: "cat4".tr,
                                    onTap: () {
                                      setState(() {
                                        _subseletedtab = 3;
                                      });
                                      WidgetsBinding.instance
                                          .addPostFrameCallback((_) {
                                            Get.toNamed(
                                              '/tasks?id=3',
                                              arguments: 2,
                                              preventDuplicates: false,
                                            );
                                          });
                                    },
                                  ),
                                  _buildSubTile(
                                    selectedTab: 4,

                                    text: "cat5".tr,
                                    onTap: () {
                                      setState(() {
                                        _subseletedtab = 4;
                                      });
                                      WidgetsBinding.instance
                                          .addPostFrameCallback((_) {
                                            Get.toNamed(
                                              '/tasks?id=4',
                                              arguments: 2,
                                              preventDuplicates: false,
                                            );
                                          });
                                    },
                                  ),
                                  _buildSubTile(
                                    selectedTab: 5,

                                    text: "cat6".tr,
                                    onTap: () {
                                      setState(() {
                                        _subseletedtab = 5;
                                      });
                                      WidgetsBinding.instance
                                          .addPostFrameCallback((_) {
                                            Get.toNamed(
                                              '/tasks?id=5',
                                              arguments: 2,
                                              preventDuplicates: false,
                                            );
                                          });
                                    },
                                  ),
                                  _buildSubTile(
                                    selectedTab: 6,

                                    text: "cat7".tr,
                                    onTap: () {
                                      setState(() {
                                        _subseletedtab = 6;
                                      });
                                      WidgetsBinding.instance
                                          .addPostFrameCallback((_) {
                                            Get.toNamed(
                                              '/tasks?id=6',
                                              arguments: 2,
                                              preventDuplicates: false,
                                            );
                                          });
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTile({
    required String icon,
    required String text,
    required VoidCallback onTap,
    required int selectedTab,
    IconData? iconData,
  }) {
    final color =
        selectedTab == _selectedtab ? AppColors.fontColorGrey : Colors.white;
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 5),
      decoration:
          selectedTab == _selectedtab
              ? BoxDecoration(
                color: Color(0xffECECEC),
                borderRadius: BorderRadius.circular(3),
              )
              : null,
      child: ListTile(
        minVerticalPadding: 0,
        leading:
            iconData != null
                ? Icon(iconData, color: color, size: 24)
                : Image.asset(icon, color: color),
        title:
            isCollapsed
                ? null
                : Text(
                  text,
                  style: TextStyle(
                    fontSize: 14,
                    color:
                        selectedTab == _selectedtab
                            ? AppColors.fontColorGrey
                            : Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
        onTap: onTap,
        trailing:
            selectedTab == _selectedtab ? Icon(Icons.arrow_forward) : null,
      ),
    );
  }

  Widget _buildSubTile({
    required String text,
    required VoidCallback onTap,
    required int selectedTab,
  }) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 5),
      height: 30,
      alignment: Alignment.center,
      decoration:
          selectedTab == _subseletedtab
              ? BoxDecoration(
                color: Color(0xffECECEC),
                borderRadius: BorderRadius.circular(3),
              )
              : null,
      child: ListTile(
        minTileHeight: 20,
        leading: Icon(
          Icons.circle,
          size: 9,
          color:
              selectedTab == _subseletedtab
                  ? AppColors.fontColorGrey
                  : Colors.white,
        ),
        title:
            isCollapsed
                ? null
                : Text(
                  text,
                  style: TextStyle(
                    fontSize: 14,
                    color:
                        selectedTab == _subseletedtab
                            ? AppColors.fontColorGrey
                            : Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
        onTap: onTap,
        contentPadding: EdgeInsets.symmetric(horizontal: 10),
        //   trailing:
        //       selectedtab == _subseletedtab
        //           ? Icon(Icons.arrow_forward)
        //           : null,
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
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 5),

      decoration:
          selectedTab == _selectedtab
              ? BoxDecoration(
                color: Color(0xffECECEC),
                borderRadius: BorderRadius.circular(3),
              )
              : null,
      child: ExpansionTile(
        childrenPadding: EdgeInsets.zero,
        leading: Image.asset(
          icon,
          color:
              selectedTab == _selectedtab
                  ? AppColors.fontColorGrey
                  : Colors.white,
        ),
        trailing:
            isCollapsed
                ? const SizedBox.shrink()
                : Icon(
                  Icons.arrow_downward_outlined,
                  color: Colors.white,
                  size: 18,
                ),
        title:
            isCollapsed
                ? const SizedBox.shrink()
                : Text(
                  text,
                  style: TextStyle(
                    fontSize: 14,
                    color:
                        selectedTab == _selectedtab
                            ? AppColors.fontColorGrey
                            : Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
        initiallyExpanded: openMenus[id] ?? false,
        onExpansionChanged: (expanded) {
          setState(() => openMenus[id] = expanded);
        },
        children: isCollapsed ? [] : children,
      ),
    );
  }
}
