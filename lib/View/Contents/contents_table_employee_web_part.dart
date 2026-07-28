part of 'package:point/View/Contents/ContentsTable.dart';

/// على الويب: موظفو قسم النشر أو الترويج يستخدمون جدول المحتوى الكامل (مثل الأدمن).
bool _isWebPublishingOrPromotionEmployee(EmployeeModel? emp) {
  if (emp?.role != 'employee' || !kIsWeb) return false;
  return emp!.hasDepartment(StorageKeys.departmentPublishing) ||
      emp.hasDepartment(StorageKeys.departmentPromotion);
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
        height: 42,
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
              color: context.appTheme.cardSurface,
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
              style: TextStyle(
                color: context.appTheme.secondaryText,
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
          color: context.appTheme.secondaryText,
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
                    style: TextStyle(
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
              style: TextStyle(
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
      const SizedBox(width: 8),
      _bulkContentActionsControls(context, controller, expandInParentRow: true),
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
  return Obx(() {
    final _ = controller.employeeWebContentFiltersRevision.value;
    final types = controller.employeeWebContentTypeFilters.toList();
    final statuses = controller.employeeWebContentStatusFilters.toList();
    final date = controller.employeeWebContentDateFilter.value;

    final activeTags = <Widget>[];
    appendAppActiveFilterTags(
      out: activeTags,
      dimension: 'employee.content.filter_type'.tr,
      selected: types,
      itemLabel: (s) => s.tr,
      onRemove: (value) {
        final next = List<String>.from(types)..remove(value);
        controller.setEmployeeWebContentFilterList(
          controller.employeeWebContentTypeFilters,
          next,
        );
      },
    );
    appendAppActiveFilterTags(
      out: activeTags,
      dimension: 'tasks.filter_status'.tr,
      selected: statuses,
      itemLabel: (s) => s.tr,
      onRemove: (value) {
        final next = List<String>.from(statuses)..remove(value);
        controller.setEmployeeWebContentFilterList(
          controller.employeeWebContentStatusFilters,
          next,
        );
      },
    );
    if (date != null) {
      activeTags.add(
        AppActiveFilterTag(
          dimension: 'publish_date'.tr,
          label: DateFormat('yyyy-MM-dd HH:mm').format(date),
          onRemove: () {
            controller.employeeWebContentDateFilter.value = null;
            controller.employeeWebContentFiltersRevision.value++;
            controller.update(['employeeWebContent']);
          },
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MobileFilterSearchRow(
            searchBar: MobileFilterSearchBar(
              controller: controller.employeeWebContentSearchController,
              hintText: 'employee.search_content_hint'.tr,
              onChanged: () => controller.update(['employeeWebContent']),
            ),
            onClearFilters: () => controller.clearEmployeeWebContentFilters(),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              AppMultiFilterTrigger(
                hint: 'employee.content.filter_type'.tr,
                items: StorageKeys.contentTypes,
                selected: types,
                itemLabel: (s) => s.tr,
                onChanged: (v) => controller.setEmployeeWebContentFilterList(
                  controller.employeeWebContentTypeFilters,
                  v,
                ),
              ),
              AppMultiFilterTrigger(
                hint: 'tasks.filter_status'.tr,
                items: StorageKeys.statusList,
                selected: statuses,
                itemLabel: (s) => s.tr,
                onChanged: (v) => controller.setEmployeeWebContentFilterList(
                  controller.employeeWebContentStatusFilters,
                  v,
                ),
              ),
              AppDateFilterChip(
                hint: 'publish_date'.tr,
                value: date,
                onPick: () async {
                  final picked = await pickAppDateTime(
                    context,
                    initialDateTime: date ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (picked == null) return;
                  controller.employeeWebContentDateFilter.value = picked;
                  controller.employeeWebContentFiltersRevision.value++;
                  controller.update(['employeeWebContent']);
                },
                onClear: () {
                  controller.employeeWebContentDateFilter.value = null;
                  controller.employeeWebContentFiltersRevision.value++;
                  controller.update(['employeeWebContent']);
                },
              ),
            ],
          ),
          if (activeTags.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: activeTags),
          ],
        ],
      ),
    );
  });
}

class _EmployeeWebDesktopContentShell extends StatelessWidget {
  const _EmployeeWebDesktopContentShell();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appTheme.pageBackground,
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
                      departments:
                          controller.currentEmployee.value?.departments ??
                          const [],
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
                      color: context.appTheme.secondaryText,
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
