import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/Utils/AppConstants.dart';
import 'package:point/View/Contents/ContentDialogDetails.dart';
import 'package:point/View/Contents/Mobile/ContentFormMobilePage.dart';
import 'package:point/View/EmployeeDashboard/employee_mobile_app_bar.dart';
import 'package:point/View/Mobile/ContentStatusCard.dart';
import 'package:point/View/Shared/CustomDropDown.dart';
import 'package:point/View/Shared/CustomHeader.dart';
import 'package:point/View/Shared/button.dart';
import 'package:point/View/Shared/responsive.dart';

/// Content management for employees (Promotion/Publishing): same shell as [EmployeeDashboard],
/// responsive mobile vs desktop/web — no [ResponsiveScaffold] drawer.
class EmployeeContentDashboard extends StatelessWidget {
  const EmployeeContentDashboard({super.key});

  static const double _maxContentWidth = 1200;

  @override
  Widget build(BuildContext context) {
    return GetBuilder<HomeController>(
      builder: (controller) {
        final isMobile = Responsive.isMobile(context);
        return Scaffold(
          backgroundColor: Colors.grey.shade100,
          appBar: isMobile ? EmployeeMobileAppBar(controller: controller) : null,
          body: Responsive(
            mobile: _buildMobileBody(context, controller),
            desktop: _buildDesktopBody(context, controller),
          ),
        );
      },
    );
  }

  Widget _buildMobileBody(BuildContext context, HomeController controller) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          Text(
            'managecontent'.tr,
            style: TextStyle(
              color: AppColors.fontColorGrey,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.start,
            children: [
              MainButton(
                width: 160,
                height: 45,
                borderSize: 35,
                fontColor: Colors.white,
                backgroundColor: AppColors.primary,
                widget: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
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
                onPressed: () => _onAddContent(controller),
              ),
              MainButton(
                width: 160,
                height: 45,
                borderSize: 35,
                fontColor: Colors.white,
                backgroundColor: AppColors.primary,
                widget: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
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
          ),
          const SizedBox(height: 12),
          _buildClientDropdown(controller),
          const SizedBox(height: 16),
          _buildContentList(context, controller),
        ],
      ),
    );
  }

  Widget _buildDesktopBody(BuildContext context, HomeController controller) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _maxContentWidth),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Obx(
                () => HeaderWidget(
                  employee: true,
                  name: controller.currentemployee.value?.name ?? '',
                  role: controller.currentemployee.value?.role ?? '',
                  avatarUrl:
                      controller.currentemployee.value?.image ??
                      kDefaultAvatarUrl,
                ),
              ),
              const SizedBox(height: 20),
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
                    onPressed: () => _onAddContent(controller),
                  ),
                  const SizedBox(width: 10),
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
              ),
              const SizedBox(height: 16),
              _buildClientDropdown(controller),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (ctx, constraints) {
                  return _buildContentList(
                    ctx,
                    controller,
                    maxWidth: constraints.maxWidth,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onAddContent(HomeController controller) {
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
  }

  Widget _buildClientDropdown(HomeController controller) {
    return Obx(() {
      final clients = controller.clients;
      return DynamicDropdown(
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
                : clients.firstWhere(
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
      );
    });
  }

  Widget _buildContentList(
    BuildContext context,
    HomeController controller, {
    double? maxWidth,
  }) {
    return GetX<HomeController>(
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

        final wide =
            maxWidth != null &&
            maxWidth >= 720 &&
            Responsive.isDesktop(context);

        if (wide) {
          final half = (maxWidth - 12) / 2;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (var i = 0; i < contents.length; i++)
                SizedBox(
                  width: half.clamp(260, 560),
                  child: ContentStatusCard(
                    index: i,
                    model: contents[i],
                    onTap:
                        () => showContentDialogDetails(
                          context,
                          task: contents[i],
                        ),
                  ),
                ),
            ],
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
                  () => showContentDialogDetails(context, task: content),
            );
          },
          separatorBuilder: (_, __) => const SizedBox(height: 8),
        );
      },
    );
  }
}
