import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Services/StorageKeys.dart';

/// Legacy route — opens programming tasks (suggestions now live inline in
/// the tasks tab, so this always lands there unless the converted tab is
/// explicitly requested).
class ProgrammingUpdatesPage extends StatelessWidget {
  final int initialTabIndex;

  const ProgrammingUpdatesPage({super.key, this.initialTabIndex = 0});

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (Get.currentRoute != '/programming-updates') return;
      Get.offNamed(
        '/tasks',
        parameters: {
          'department': StorageKeys.departmentProgramming,
          'updatesTab': initialTabIndex.clamp(0, 1).toString(),
        },
      );
    });
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
