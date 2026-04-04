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
                  if (StorageKeys.matchesDepartment(
                        controller.currentEmployee.value?.department,
                        StorageKeys.departmentPromotion,
                      ) ||
                      StorageKeys.matchesDepartment(
                        controller.currentEmployee.value?.department,
                        StorageKeys.departmentPublishing,
                      )) ...[
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
                        controller.refreshFilteredContents();
                      }
                    },
                    validator: (v) => v == null ? ' ' : null,
                  ),
                );
              }),
              const SizedBox(height: 16),
              GetX<HomeController>(
                builder: (c) {
                  final contents = c.searchedContents.toList();
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
                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: contents.length,
                    itemBuilder: (_, i) {
                      final content = contents[i];
                      return ContentStatusCard(
                        index: i,
                        model: content,
                        onTap:
                            () =>
                                showContentDialogDetails(
                                  context,
                                  task: content,
                                ),
                      );
                    },
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
