import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/Utils/app_theme_extension.dart';
import 'package:point/View/Tasks/ProgrammingUpdates/programming_updates_panel.dart';

/// Reads optional `updatesTab` / `tab` route param (0=tasks, 1=converted).
/// Pending suggestions now live inline in the tasks tab (see
/// [ProgrammingSuggestionsCard]), so the old pending-tab index (1) collapses
/// into the tasks tab and only "converted" (previously 2) remains as tab 1.
int programmingUpdatesTabFromRoute() {
  final raw = Get.parameters['updatesTab'] ?? Get.parameters['tab'];
  final requested = int.tryParse(raw ?? '') ?? 0;
  if (requested >= 2) return 1;
  if (requested == 1) return 0;
  return 0;
}

/// Top-level tabs for the programming department: tasks, pending, converted.
class ProgrammingDepartmentTabs extends StatefulWidget {
  final Widget tasksTab;
  final int initialTabIndex;

  /// Whether the tab content should be wrapped in [Expanded] (i.e. this
  /// widget sits in a bounded-height context and the tab content manages
  /// its own scrolling, as on mobile). Pass `false` when this widget is
  /// placed inside an outer unbounded scroll view (desktop), where the tab
  /// content should size itself instead.
  final bool expandContent;

  const ProgrammingDepartmentTabs({
    super.key,
    required this.tasksTab,
    this.initialTabIndex = 0,
    this.expandContent = true,
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
    final initial = widget.initialTabIndex.clamp(0, 1);
    _tabController = TabController(length: 2, vsync: this, initialIndex: initial);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
    Get.find<HomeController>().fetchProgrammingUpdates();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final content = _tabController.index == 0
        ? widget.tasksTab
        : ProgrammingConvertedUpdatesPanel(shrinkWrap: !widget.expandContent);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: context.appTheme.cardSurface,
          child: TabBar(
            controller: _tabController,
            labelColor: AppColors.primary,
            unselectedLabelColor: context.appTheme.secondaryText,
            indicatorColor: AppColors.primary,
            indicatorWeight: 3,
            dividerColor: context.appTheme.border,
            tabs: [
              Tab(text: 'programming.tab.tasks'.tr),
              Tab(text: 'programming.updates.converted'.tr),
            ],
          ),
        ),
        widget.expandContent ? Expanded(child: content) : content,
      ],
    );
  }
}
