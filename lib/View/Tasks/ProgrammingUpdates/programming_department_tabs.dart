import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/View/Tasks/ProgrammingUpdates/programming_updates_panel.dart';

/// Reads optional `updatesTab` / `tab` route param (0=tasks, 1=pending, 2=converted).
int programmingUpdatesTabFromRoute() {
  final raw = Get.parameters['updatesTab'] ?? Get.parameters['tab'];
  return (int.tryParse(raw ?? '') ?? 0).clamp(0, 2);
}

/// Top-level tabs for the programming department: tasks, pending, converted.
class ProgrammingDepartmentTabs extends StatefulWidget {
  final Widget tasksTab;
  final int initialTabIndex;

  const ProgrammingDepartmentTabs({
    super.key,
    required this.tasksTab,
    this.initialTabIndex = 0,
  });

  @override
  State<ProgrammingDepartmentTabs> createState() =>
      _ProgrammingDepartmentTabsState();
}

class _ProgrammingDepartmentTabsState extends State<ProgrammingDepartmentTabs>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialTabIndex.clamp(0, 2);
    _tabController = TabController(length: 3, vsync: this, initialIndex: initial);
    Get.find<HomeController>().fetchProgrammingUpdates();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: Colors.white,
          child: Obx(() {
            final pendingCount =
                Get.find<HomeController>().pendingProgrammingUpdatesCount;
            return TabBar(
              controller: _tabController,
              labelColor: AppColors.primary,
              unselectedLabelColor: Colors.grey.shade600,
              indicatorColor: AppColors.primary,
              indicatorWeight: 3,
              tabs: [
                Tab(text: 'programming.tab.tasks'.tr),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          'programming.updates.pending'.tr,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (pendingCount > 0) ...[
                        const SizedBox(width: 6),
                        CircleAvatar(
                          radius: 10,
                          backgroundColor: AppColors.primary,
                          child: Text(
                            pendingCount > 99 ? '99+' : '$pendingCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Tab(text: 'programming.updates.converted'.tr),
              ],
            );
          }),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              widget.tasksTab,
              const ProgrammingPendingUpdatesPanel(),
              const ProgrammingConvertedUpdatesPanel(),
            ],
          ),
        ),
      ],
    );
  }
}
