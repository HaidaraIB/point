import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/View/Contents/ContentDialogDetails.dart';
import 'package:point/View/Mobile/ContentStatusCard.dart';
import 'package:point/View/Shared/app_multi_filter.dart';
import 'package:point/Utils/app_theme_extension.dart';

Widget buildMobileHistory(
  BuildContext context,
  HomeController controller,
  List<String> months,
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
          children: [
            const SizedBox(height: 24),
            Text(
              'settings'.tr,
              style: TextStyle(
                color: context.appTheme.secondaryText,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Obx(() {
              final clientId = controller.clientController.text;
              final clientIds = controller.clients
                  .map((c) => c.id?.trim() ?? '')
                  .where((id) => id.isNotEmpty)
                  .toList();
              String clientLabel(String id) =>
                  controller.clients
                      .firstWhereOrNull((c) => c.id == id)
                      ?.name ??
                  id;
              final selectedClients =
                  clientId.isEmpty ? <String>[] : [clientId];
              final selectedMonths = controller.selectedDate.value.isEmpty
                  ? <String>[]
                  : [controller.selectedDate.value];

              void applyClient(String? id) {
                if (id == null || id.isEmpty) {
                  controller.clientController.clear();
                  controller.selectedDate.value = '';
                  controller.searchedContents.clear();
                } else {
                  controller.clientController.text = id;
                  controller.selectedDate.value = '';
                  controller.searchedContents.assignAll(
                    controller.contents
                        .where((a) => a.clientId == id)
                        .toList(),
                  );
                }
                controller.update();
              }

              void applyMonths(List<String> monthsSelected) {
                final id = controller.clientController.text;
                if (id.isEmpty) return;
                if (monthsSelected.isEmpty) {
                  controller.selectedDate.value = '';
                  controller.searchedContents.assignAll(
                    controller.contents
                        .where((a) => a.clientId == id)
                        .toList(),
                  );
                } else {
                  final value = monthsSelected.last;
                  controller.selectedDate.value = value;
                  final parts = value.split('-');
                  if (parts.length >= 2) {
                    final year = int.tryParse(parts[0]);
                    final month = int.tryParse(parts[1]);
                    if (year != null && month != null) {
                      controller.searchedContents.assignAll(
                        controller.contents
                            .where(
                              (a) =>
                                  a.clientId == id &&
                                  a.publishDate != null &&
                                  a.publishDate!.month == month &&
                                  a.publishDate!.year == year,
                            )
                            .toList(),
                      );
                    }
                  }
                }
                controller.update();
              }

              final activeTags = <Widget>[];
              appendAppActiveFilterTags(
                out: activeTags,
                dimension: 'chooseclient'.tr,
                selected: selectedClients,
                itemLabel: clientLabel,
                onRemove: (_) => applyClient(null),
              );
              appendAppActiveFilterTags(
                out: activeTags,
                dimension: 'common.select_date'.tr,
                selected: selectedMonths,
                itemLabel: (m) => m,
                onRemove: (_) => applyMonths(const []),
              );

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      AppMultiFilterTrigger(
                        hint: 'chooseclient'.tr,
                        items: clientIds,
                        selected: selectedClients,
                        itemLabel: clientLabel,
                        onChanged: (v) =>
                            applyClient(v.isEmpty ? null : v.last),
                      ),
                      if (clientId.isNotEmpty)
                        AppMultiFilterTrigger(
                          hint: 'common.select_date'.tr,
                          items: months,
                          selected: selectedMonths,
                          itemLabel: (m) => m,
                          onChanged: applyMonths,
                        ),
                    ],
                  ),
                  if (activeTags.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(spacing: 8, runSpacing: 8, children: activeTags),
                  ],
                ],
              );
            }),
            const SizedBox(height: 24),
            GetX<HomeController>(
              builder: (c) {
                final contents = c.searchedContents.toList();
                if (c.clientController.text.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: Text(
                        'history.pick_client_content'.tr,
                        style: TextStyle(
                          fontSize: 15,
                          color: context.appTheme.secondaryText,
                        ),
                      ),
                    ),
                  );
                }
                if (contents.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: Text(
                        'history.empty_data'.tr,
                        style: TextStyle(
                          fontSize: 15,
                          color: context.appTheme.secondaryText,
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
                    return ContentStatusCard(
                      index: i,
                      model: contents[i],
                      onTap: () => showContentDialogDetails(
                        context,
                        task: contents[i],
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
