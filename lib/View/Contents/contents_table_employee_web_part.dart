part of 'package:point/View/Contents/ContentsTable.dart';

/// على الويب: موظفو قسم النشر أو الترويج يستخدمون جدول المحتوى الكامل (مثل الأدمن).
bool _isWebPublishingOrPromotionEmployee(EmployeeModel? emp) {
  if (emp?.role != 'employee' || !kIsWeb) return false;
  return StorageKeys.matchesDepartment(
        emp?.department,
        StorageKeys.departmentPublishing,
      ) ||
      StorageKeys.matchesDepartment(
        emp?.department,
        StorageKeys.departmentPromotion,
      );
}

bool _useEmployeeContentDashboard(EmployeeModel? emp) {
  if (emp?.role != 'employee') return false;
  return !_isWebPublishingOrPromotionEmployee(emp);
}

List<ContentModel> _contentsListForDesktopTable(
  BuildContext context,
  HomeController c,
) {
  if (kIsWeb &&
      _isWebPublishingOrPromotionEmployee(c.currentEmployee.value) &&
      !Responsive.isMobile(context)) {
    return c.filteredContentsForEmployeeWeb();
  }
  return c.searchedContents.toList();
}

Widget _buildClientPickerRow(
  HomeController controller, {
  required bool fullWidth,
  required bool clearFiltersWhenClientChanges,
}) {
  return Obx(() {
    final clients = controller.clients;
    return SizedBox(
      width: fullWidth ? double.infinity : ((Get.width * 0.7 / 2) - 20),
      child: DynamicDropdown(
        items:
            clients
                .map(
                  (v) => DropdownMenuItem(
                    value: v,
                    child: Text('${v.name}'),
                  ),
                )
                .toList(),
        value:
            controller.clientController.text.isEmpty
                ? null
                : clients.firstWhereOrNull(
                  (a) => a.id == controller.clientController.text,
                ),
        label: 'chooseclient'.tr,
        borderRadius: 5,
        borderColor: Colors.grey.shade300,
        height: 42,
        fillColor: Colors.white,
        onChanged: (value) {
          if (value != null) {
            controller.clientController.text = (value).id ?? '';
            if (clearFiltersWhenClientChanges) {
              controller.clearEmployeeWebContentFilters();
            }
            controller.refreshFilteredContents();
          }
        },
        validator: (v) => v == null ? ' ' : null,
      ),
    );
  });
}

Widget _employeeWebContentStatBox(
  String value,
  String label,
  Color color,
  BuildContext context, {
  double? width,
}) {
  final isDesktop = Responsive.isDesktop(context);
  final boxWidth =
      width ?? (isDesktop ? Get.width / 5 - 78 : Get.width / 5 - 30);
  return Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
    ),
    width: boxWidth,
    height: 150,
    margin: const EdgeInsets.all(10),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          height: 32,
          child: Center(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 22,
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 25),
        SizedBox(
          height: 48,
          width: double.infinity,
          child: Center(
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.grey,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _EmployeeWebContentTitleRow(
  BuildContext context,
  HomeController controller,
) {
  return Row(
    children: [
      Text(
        'managecontent'.tr,
        style: TextStyle(
          color: AppColors.fontColorGrey,
          fontSize: 15,
          fontWeight: FontWeight.bold,
        ),
      ),
      const Spacer(),
      Obx(() {
        if (!ContentPermissions.canAddOrEditContent(
              controller.currentEmployee.value,
            )) {
          return const SizedBox.shrink();
        }
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
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
                    'addnewcontent'.tr,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 5),
                  const Icon(
                    Icons.add_circle_outline_rounded,
                    color: Colors.white,
                  ),
                ],
              ),
              onPressed: () {
                if (controller.clientController.text.isEmpty) {
                  FunHelper.showSnackbar(
                    'error'.tr,
                    'content.form.select_client_first'.tr,
                    snackPosition: SnackPosition.TOP,
                    backgroundColor: Colors.red,
                    colorText: Colors.white,
                  );
                  return;
                }
                controller.uploadedFilesPaths.clear();
                showAddContentDialog(
                  context,
                  clientId: controller.clientController.text,
                );
              },
            ),
            const SizedBox(width: 10),
          ],
        );
      }),
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
              'tasks'.tr,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 5),
            const Icon(
              Icons.navigate_next,
              color: Colors.white,
            ),
          ],
        ),
        onPressed: () => Get.toNamed('/employeeDashboard'),
      ),
    ],
  );
}

Widget _EmployeeWebContentStatsRow(
  HomeController controller,
  BuildContext context,
) {
  return GetBuilder<HomeController>(
    id: 'employeeWebContent',
    builder: (c) {
      final list = c.filteredContentsForEmployeeWeb();
      final isDesktop = Responsive.isDesktop(context);
      final boxWidth =
          isDesktop
              ? null
              : (Get.width / 5 - 30).clamp(88.0, double.infinity);
      final statRow = Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _employeeWebContentStatBox(
            list.length.toString(),
            'employee.content.total_content'.tr,
            Colors.blue,
            context,
            width: boxWidth,
          ),
          _employeeWebContentStatBox(
            list
                .where((a) => a.status == StorageKeys.status_processing)
                .length
                .toString(),
            'status_processing'.tr,
            Colors.amber,
            context,
            width: boxWidth,
          ),
          _employeeWebContentStatBox(
            list
                .where((a) => a.status == StorageKeys.status_under_revision)
                .length
                .toString(),
            'status_under_revision'.tr,
            Colors.blue,
            context,
            width: boxWidth,
          ),
          _employeeWebContentStatBox(
            list
                .where(
                  (a) =>
                      a.status == StorageKeys.status_approved ||
                      a.status == StorageKeys.status_published,
                )
                .length
                .toString(),
            'employee.dashboard.completed'.tr,
            Colors.green,
            context,
            width: boxWidth,
          ),
          _employeeWebContentStatBox(
            list
                .where((a) => a.status == StorageKeys.status_rejected)
                .length
                .toString(),
            'employee.dashboard.cancelled'.tr,
            Colors.red,
            context,
            width: boxWidth,
          ),
        ],
      );
      return isDesktop
          ? statRow
          : SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: statRow,
          );
    },
  );
}

Widget _EmployeeWebContentFiltersRow(
  HomeController controller,
  BuildContext context,
) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: InputText(
            prefixIcon: const Icon(
              CupertinoIcons.search,
              color: Colors.grey,
            ),
            hintText: 'employee.search_content_hint'.tr,
            height: 42,
            fillColor: Colors.white,
            controller: controller.employeeWebContentSearchController,
            onchange: (value) {
              controller.update(['employeeWebContent']);
              return null;
            },
            borderRadius: 5,
            borderColor: Colors.grey.shade300,
          ),
        ),
        const SizedBox(width: 10),
        InkWell(
          onTap: () => controller.clearEmployeeWebContentFilters(),
          child: SvgPicture.asset(
            'assets/svgs/icon_menu.svg',
            height: 42,
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          flex: 2,
          child: Obx(
            () => Container(
              height: 40,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  hint: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      'employee.content.filter_type'.tr,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.primaryfontColor,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  value:
                      controller.employeeWebContentTypeFilter.value.isEmpty
                          ? null
                          : controller.employeeWebContentTypeFilter.value,
                  items:
                      StorageKeys.contentTypes
                          .map(
                            (e) => DropdownMenuItem(
                              value: e,
                              child: Text(e.tr),
                            ),
                          )
                          .toList(),
                  onChanged: (value) {
                    controller.employeeWebContentTypeFilter.value =
                        value ?? '';
                    controller.update(['employeeWebContent']);
                  },
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          flex: 2,
          child: Obx(
            () => Container(
              height: 40,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  hint: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      'tasks.filter_status'.tr,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.primaryfontColor,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  value:
                      controller.employeeWebContentStatusFilter.value.isEmpty
                          ? null
                          : controller.employeeWebContentStatusFilter.value,
                  items:
                      StorageKeys.statusList
                          .map(
                            (e) => DropdownMenuItem(
                              value: e,
                              child: Text(e.tr),
                            ),
                          )
                          .toList(),
                  onChanged: (value) {
                    controller.employeeWebContentStatusFilter.value =
                        value ?? '';
                    controller.update(['employeeWebContent']);
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _EmployeeWebDesktopContentShell extends StatelessWidget {
  const _EmployeeWebDesktopContentShell();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: GetBuilder<HomeController>(
        builder: (controller) {
          return SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.all(10),
              width: Get.width,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Obx(
                    () => HeaderWidget(
                      employee: true,
                      name: controller.currentEmployee.value?.name ?? '',
                      role: controller.currentEmployee.value?.role ?? '',
                      department:
                          controller.currentEmployee.value?.department,
                      avatarUrl:
                          controller.currentEmployee.value?.image ??
                          kDefaultAvatarUrl,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _EmployeeWebContentTitleRow(context, controller),
                  const SizedBox(height: 10),
                  _buildClientPickerRow(
                    controller,
                    fullWidth: true,
                    clearFiltersWhenClientChanges: true,
                  ),
                  const SizedBox(height: 10),
                  _EmployeeWebContentStatsRow(controller, context),
                  _EmployeeWebContentFiltersRow(controller, context),
                  const SizedBox(height: 15),
                  Text(
                    'employee.content.list_section'.tr,
                    style: TextStyle(
                      color: AppColors.fontColorGrey,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildDesktopContentsDataTable(context),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
