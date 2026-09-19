import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Models/TaskModel.dart';
import 'package:point/Services/task_client_name_resolver.dart';
import 'package:point/Utils/app_theme_extension.dart';

/// [TaskModel.clientName] is usually a client document id (or auth uid); resolves to a human label.
String resolvedTaskClientDisplayName(TaskModel task, HomeController controller) {
  return resolveTaskClientRef(task.clientName, controller.clients);
}

/// Task card row: reactive client list + one-shot Firestore resolve when the task still holds a bare id.
class TaskCardClientNameRow extends StatefulWidget {
  final TaskModel task;

  const TaskCardClientNameRow({super.key, required this.task});

  @override
  State<TaskCardClientNameRow> createState() => _TaskCardClientNameRowState();
}

class _TaskCardClientNameRowState extends State<TaskCardClientNameRow> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scheduleDocLookup());
  }

  @override
  void didUpdateWidget(covariant TaskCardClientNameRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.task.clientName != widget.task.clientName) {
      _scheduleDocLookup();
    }
  }

  void _scheduleDocLookup() {
    final raw = widget.task.clientName.trim();
    if (raw.isEmpty) return;
    final hc = Get.find<HomeController>();
    if (displayLabelFromClient(findClientForTaskRef(hc.clients, raw)) != null) {
      return;
    }
    if (!taskClientRefLooksLikeTechnicalId(raw)) return;
    if (taskClientDocNameCache.containsKey(raw) &&
        taskClientDocNameCache[raw]!.isNotEmpty) {
      return;
    }
    loadTaskClientLabelFromFirestore(raw).then((_) {
      if (!mounted) return;
      if (taskClientDocNameCache.containsKey(raw) &&
          taskClientDocNameCache[raw]!.isNotEmpty) {
        setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final hc = Get.find<HomeController>();
      hc.clients.length;
      final raw = widget.task.clientName.trim();
      if (raw.isEmpty) return const SizedBox.shrink();

      final display = resolvedTaskClientDisplayName(widget.task, hc);
      if (display.isEmpty) return const SizedBox.shrink();
      if (display == raw && taskClientRefLooksLikeTechnicalId(raw)) {
        return const SizedBox.shrink();
      }

      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(
          children: [
            Icon(
              Icons.person_outline,
              size: 15,
              color: context.appTheme.mutedText,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                display,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: context.appTheme.secondaryText,
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}
