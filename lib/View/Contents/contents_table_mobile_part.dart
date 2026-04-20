part of 'package:point/View/Contents/ContentsTable.dart';

Widget _buildMobileContent(
    BuildContext context,
    HomeController controller,
  ) {
    return RefreshIndicator(
      onRefresh: () async {
        controller.fetchContents();
        await Future.delayed(const Duration(seconds: 1));
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Container(
          padding: const EdgeInsets.all(10),
          width: Get.width,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'managecontent'.tr,
                      style: TextStyle(
                        color: AppColors.fontColorGrey,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Obx(() {
                    if (!ContentPermissions.canAddOrEditContent(
                      controller.currentEmployee.value,
                    )) {
                      return const SizedBox.shrink();
                    }
                    return MainButton(
                      width: 160,
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
                          Icon(
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
                        Get.to(
                          () => ContentFormMobilePage(
                            clientId: controller.clientController.text,
                            model: null,
                          ),
                        );
                      },
                    );
                  }),
                  if (controller.currentEmployee.value != null &&
                      (controller.currentEmployee.value!.hasDepartment(
                            StorageKeys.departmentPromotion,
                          ) ||
                          controller.currentEmployee.value!.hasDepartment(
                            StorageKeys.departmentPublishing,
                          ))) ...[
                    const SizedBox(width: 8),
                    MainButton(
                      width: 140,
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
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.navigate_next,
                            color: Colors.white,
                            size: 20,
                          ),
                        ],
                      ),
                      onPressed: () => Get.toNamed('/employeeDashboard'),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              Obx(() {
                // Must read observable so Obx can track and rebuild
                final clients = controller.clients;
                return SizedBox(
                  width: double.infinity,
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
                        controller.clearSelectedContentIds();
                        controller.refreshFilteredContents();
                      }
                    },
                    validator: (v) => v == null ? ' ' : null,
                  ),
                );
              }),
              const SizedBox(height: 16),
              GetBuilder<HomeController>(
                id: 'employeeWebContent',
                builder: (c) {
                  return Row(
                    children: [
                      Expanded(
                        child: InputText(
                          hintText: 'employee.search_content_hint'.tr,
                          height: 42,
                          fillColor: Colors.white,
                          controller: c.employeeWebContentSearchController,
                          onchange: (_) {
                            c.update(['employeeWebContent']);
                            return null;
                          },
                          borderRadius: 8,
                          borderColor: Colors.grey.shade300,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Obx(
                          () => Container(
                            height: 42,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value:
                                    c.employeeWebContentStatusFilter.value.isEmpty
                                        ? null
                                        : c.employeeWebContentStatusFilter.value,
                                hint: Text('tasks.filter_status'.tr),
                                isExpanded: true,
                                items:
                                    StorageKeys.statusList
                                        .map(
                                          (e) => DropdownMenuItem<String>(
                                            value: e,
                                            child: Text(e.tr),
                                          ),
                                        )
                                        .toList(),
                                onChanged: (v) {
                                  c.employeeWebContentStatusFilter.value = v ?? '';
                                  c.update(['employeeWebContent']);
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                            initialDate:
                                c.employeeWebContentDateFilter.value ??
                                DateTime.now(),
                          );
                          if (picked == null) return;
                          c.employeeWebContentDateFilter.value = picked;
                          c.update(['employeeWebContent']);
                        },
                        icon: const Icon(Icons.calendar_month_outlined),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 8),
              GetBuilder<HomeController>(
                id: 'employeeWebContent',
                builder: (c) {
                  final contents = c.filteredContentsForEmployeeWeb();
                  if (c.clientController.text.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Text(
                          'history.pick_client_content'.tr,
                          style: TextStyle(
                            fontSize: 15,
                            color: AppColors.fontColorGrey,
                          ),
                        ),
                      ),
                    );
                  }
                  if (contents.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Text(
                          'history.empty_data'.tr,
                          style: TextStyle(
                            fontSize: 15,
                            color: AppColors.fontColorGrey,
                          ),
                        ),
                      ),
                    );
                  }
                  final visibleIds =
                      contents
                          .map((m) => m.id?.trim() ?? '')
                          .where((id) => id.isNotEmpty)
                          .toList();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (visibleIds.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Obx(() {
                            final selectedInView = visibleIds
                                .where((id) => c.selectedContentIds.contains(id))
                                .length;
                            final bool? headerValue =
                                selectedInView == 0
                                    ? false
                                    : selectedInView == visibleIds.length
                                    ? true
                                    : null;
                            return InkWell(
                              onTap: () =>
                                  c.toggleSelectAllVisibleContents(contents),
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  children: [
                                    Checkbox(
                                      tristate: true,
                                      value: headerValue,
                                      onChanged: (_) =>
                                          c.toggleSelectAllVisibleContents(
                                            contents,
                                          ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        'notifications.action.select_all'.tr,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: AppColors.fontColorGrey,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: contents.length,
                        itemBuilder: (_, i) {
                          final content = contents[i];
                          final id = content.id;
                          final selected =
                              id != null && c.selectedContentIds.contains(id);
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              IconButton(
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 48,
                                  minHeight: 48,
                                ),
                                icon: Icon(
                                  selected
                                      ? Icons.check_box
                                      : Icons.check_box_outline_blank,
                                  color:
                                      selected
                                          ? Theme.of(
                                            context,
                                          ).colorScheme.primary
                                          : Colors.grey.shade600,
                                  size: 26,
                                ),
                                tooltip:
                                    'notifications.action.selection_mode'.tr,
                                onPressed:
                                    id == null
                                        ? null
                                        : () {
                                            c.toggleContentSelection(
                                              id,
                                              selected: !selected,
                                            );
                                          },
                              ),
                              Expanded(
                                child: ContentStatusCard(
                                  index: i,
                                  model: content,
                                  onTap:
                                      () => showContentDialogDetails(
                                        context,
                                        task: content,
                                      ),
                                ),
                              ),
                            ],
                          );
                        },
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 8),
                      ),
                    ],
                  );
                },
              ),
              Obx(() {
                final selected = controller.selectedContentIds.length;
                if (selected == 0) return const SizedBox.shrink();
                final emp = controller.currentEmployee.value;
                final canStatus = ContentPermissions.canChangePostStatus(emp);
                final canDel = ContentPermissions.canDeleteContent(emp);
                if (!canStatus && !canDel) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (canStatus) ...[
                        _bulkActionChipButton(
                          label: '${'tasks.accept'.tr} ($selected)',
                          accentColor: AppColors.success,
                          icon: Icons.check_circle_outline_rounded,
                          expandWidth: true,
                          onPressed: () => controller.approveSelectedContents(),
                        ),
                        const SizedBox(height: 8),
                        _bulkActionChipButton(
                          label: '${'content.publish_now'.tr} ($selected)',
                          accentColor: AppColors.primary,
                          icon: Icons.publish_rounded,
                          expandWidth: true,
                          onPressed: () => controller.publishSelectedContents(),
                        ),
                        const SizedBox(height: 8),
                        _bulkActionChipButton(
                          label: '${'content.schedule'.tr} ($selected)',
                          accentColor: const Color(0xFF1565C0),
                          icon: Icons.schedule_rounded,
                          expandWidth: true,
                          onPressed: () => controller.scheduleSelectedContents(),
                        ),
                      ],
                      if (canStatus && canDel) const SizedBox(height: 8),
                      if (canDel)
                        _bulkActionChipButton(
                          label: '${'delete'.tr} ($selected)',
                          accentColor: AppColors.destructive,
                          icon: Icons.delete_outline_rounded,
                          expandWidth: true,
                          onPressed: () {
                            _confirmBulkDeleteContent(context, controller);
                          },
                        ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
