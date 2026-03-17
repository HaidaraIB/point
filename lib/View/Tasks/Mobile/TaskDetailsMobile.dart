import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Models/TaskModel.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Services/StorageKeys.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/View/Shared/TaskTimelineWidget.dart';
import 'package:point/View/Tasks/Dialogs/ContentWriteDialog.dart';
import 'package:point/View/Tasks/Dialogs/DesignDialog.dart';
import 'package:point/View/Tasks/Dialogs/MontageDialog.dart';
import 'package:point/View/Tasks/Dialogs/PhotoGraphyDialog.dart';
import 'package:point/View/Tasks/Dialogs/ProgrammingDialog.dart';
import 'package:point/View/Tasks/Dialogs/PromotionDialog.dart';
import 'package:point/View/Tasks/Dialogs/PublishDialog.dart';

/// Mobile-only full-screen task details. Used when opening any task type on mobile.
class TaskDetailsMobilePage extends StatelessWidget {
  final TaskModel task;

  const TaskDetailsMobilePage({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom + 24;

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'تفاصيل المهمة'.tr,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Get.back(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16, 16, 16, bottomPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildCard(
                context,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryfontColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      task.description,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _buildCard(
                context,
                child: Row(
                  children: [
                    _chip(task.status, _statusColor(task.status), _statusBg(task.status)),
                    const SizedBox(width: 8),
                    _chip(task.priority, _priorityColor(task.priority), _priorityBg(task.priority)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _buildCard(
                context,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'التقدم'.tr,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: task.progress ?? 0,
                      backgroundColor: Colors.grey.shade200,
                      color: AppColors.primary,
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${((task.progress ?? 0) * 100).toInt()}%',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _buildCard(
                context,
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: Colors.grey.shade300,
                      backgroundImage: NetworkImage(
                        task.assignedImageUrl.isEmpty
                            ? '${StorageKeys.supabaseStorageBaseUrl}/Avatar.png'
                            : task.assignedImageUrl,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _assigneeName(context),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.calendar_today_outlined, size: 14, color: Colors.grey.shade600),
                              const SizedBox(width: 4),
                              Text(
                                FunHelper.formatdate(task.fromDate) ?? '',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                          Text(
                            _stillTime(task.toDate),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _stillTime(task.toDate) == 'الوقت منتهي' ? Colors.red : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (task.timelineEvents.isNotEmpty) ...[
                const SizedBox(height: 16),
                TaskTimelineWidget(events: task.timelineEvents),
              ],
              const SizedBox(height: 24),
              _buildActions(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context, {required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _chip(String text, Color color, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text.toString().tr,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _assigneeName(BuildContext context) {
    final controller = Get.find<HomeController>();
    final emp = controller.employees.firstWhereOrNull(
          (e) => e.id == task.assignedTo,
        );
    return emp?.name ?? task.clientName;
  }

  String _stillTime(DateTime endDate) {
    final diff = endDate.difference(DateTime.now());
    if (diff.isNegative) return 'الوقت منتهي';
    final d = diff.inDays;
    final h = diff.inHours % 24;
    final m = diff.inMinutes % 60;
    final parts = <String>[];
    if (d > 0) parts.add('$d يوم');
    if (h > 0) parts.add('$h ساعة');
    if (m > 0) parts.add('$m دقيقة');
    return parts.join(' ').trim().isEmpty ? 'الآن' : parts.join(' ');
  }

  Color _statusColor(String status) {
    switch (status) {
      case StorageKeys.status_under_revision:
        return Colors.blue;
      case StorageKeys.status_approved:
        return Colors.green;
      case StorageKeys.status_rejected:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Color _statusBg(String status) {
    switch (status) {
      case StorageKeys.status_under_revision:
        return Colors.blue.shade50;
      case StorageKeys.status_approved:
        return Colors.green.shade50;
      case StorageKeys.status_rejected:
        return Colors.red.shade50;
      default:
        return Colors.grey.shade200;
    }
  }

  Color _priorityColor(String priority) {
    switch (priority) {
      case 'normal':
        return Colors.blue;
      case 'imp':
        return Colors.orange;
      case 'veryimp':
        return Colors.red;
      case 'veryveryimp':
        return Colors.red.shade900;
      default:
        return Colors.green;
    }
  }

  Color _priorityBg(String priority) {
    switch (priority) {
      case 'normal':
        return Colors.blue.shade50;
      case 'imp':
        return Colors.orange.shade50;
      case 'veryimp':
        return Colors.red.shade50;
      case 'veryveryimp':
        return Colors.red.shade100;
      default:
        return Colors.green.shade50;
    }
  }

  Widget _buildActions(BuildContext context) {
    final controller = Get.find<HomeController>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: () => Get.back(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          label: const Text('إغلاق'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () => _openEditDialog(context, task),
          icon: const Icon(Icons.edit_outlined, size: 18),
          label: const Text('طلب تعديل'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  controller.updateTask(task.copyWith(status: StorageKeys.status_rejected));
                  Get.back();
                },
                icon: const Icon(Icons.close_rounded, size: 18),
                label: const Text('رفض'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: () {
                  controller.updateTask(task.copyWith(status: StorageKeys.status_approved));
                  Get.back();
                },
                icon: const Icon(Icons.check_rounded, size: 18),
                label: const Text('قبول'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () {
            controller.deleteTask(task.id!);
            Get.back();
          },
          icon: const Icon(Icons.delete_outline, size: 18),
          label: const Text('حذف'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.red,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  void _openEditDialog(BuildContext context, TaskModel task) {
    Get.find<HomeController>().uploadedFilesPaths.clear();
    switch (task.type) {
      case '0':
        showPromotionDialog(context, model: task);
        break;
      case '1':
        designDialog(context, model: task);
        break;
      case '2':
        photoGraphyDialog(context, model: task);
        break;
      case '3':
        contentWriteDiloag(context, model: task);
        break;
      case '4':
        montageDiloag(context, model: task);
        break;
      case '5':
        publishDilaog(context, model: task);
        break;
      case '6':
        programmingDiloag(context, model: task);
        break;
      default:
        break;
    }
  }
}

/// Call this from any showXDetailsDialog when Responsive.isMobile(context).
/// Desktop/tablet keep using showDialog; only mobile uses this screen.
void showTaskDetailsMobile(BuildContext context, {required TaskModel task}) {
  Get.to(() => TaskDetailsMobilePage(task: task));
}
