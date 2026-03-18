import 'package:flutter/material.dart';
import 'package:get/get_utils/src/extensions/internacionalization.dart';
import 'package:get/instance_manager.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Models/TaskModel.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Services/StorageKeys.dart';
import 'package:point/View/Tasks/Dialogs/ContentWriteDialog.dart';
import 'package:point/View/Tasks/Dialogs/DesignDialog.dart';
import 'package:point/View/Tasks/Dialogs/MontageDialog.dart';
import 'package:point/View/Tasks/Dialogs/PhotoGraphyDialog.dart';
import 'package:point/View/Tasks/Dialogs/ProgrammingDialog.dart';
import 'package:point/View/Tasks/Dialogs/PromotionDialog.dart';
import 'package:point/View/Tasks/Dialogs/PublishDialog.dart';

class TaskCard extends StatelessWidget {
  final TaskModel task;
  final VoidCallback onTap;

  TaskCard({super.key, required this.task, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SizedBox(
            height: constraints.maxHeight,
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // --- العنوان + النقاط الثلاثة ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          task.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      SizedBox(
                        child: PopupMenuButton<int>(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          color: Colors.white,
                          elevation: 4,
                          itemBuilder:
                              (context) => [
                                PopupMenuItem(
                                  value: 0,

                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: const [
                                      Text("عرض"),
                                      Icon(
                                        Icons.remove_red_eye_outlined,
                                        color: Colors.green,
                                        size: 20,
                                      ),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 1,
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: const [
                                      Text("طلب تعديل"),
                                      Icon(
                                        Icons.edit_outlined,
                                        color: Colors.blueAccent,
                                        size: 20,
                                      ),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 2,
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: const [
                                      Text("حذف"),
                                      Icon(
                                        Icons.delete_outline,
                                        color: Colors.red,
                                        size: 20,
                                      ),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 3,
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: const [
                                      Text("رفض"),
                                      Icon(
                                        Icons.close_rounded,
                                        color: Colors.red,
                                        size: 20,
                                      ),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 4,
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: const [
                                      Text("قبول"),
                                      Icon(
                                        Icons.check,
                                        color: Colors.green,
                                        size: 20,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                          onSelected: (value) {
                            if (value == 0) {
                              onTap();
                            } else if (value == 1) {
                              // controller.uploadedFilesPaths.clear();

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
                              }
                            } else if (value == 2) {
                              Get.find<HomeController>().deleteTask(task.id!);
                            } else if (value == 3) {
                              Get.find<HomeController>().updateTask(
                                task.copyWith(
                                  status: StorageKeys.status_rejected,
                                ),
                              );
                            } else if (value == 4) {
                              Get.find<HomeController>().updateTask(
                                task.copyWith(
                                  status: StorageKeys.status_approved,
                                ),
                              );
                            }
                          },
                          child: const Icon(Icons.more_vert), //
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // --- الحالة و الأولوية ---
                  Row(
                    children: [
                      _buildstatusTag(
                        task.status,
                        Colors.amber.shade700,
                        Colors.amber.shade50,
                      ),
                      const SizedBox(width: 8),
                      _buildpriortyTag(
                        task.priority,
                        Colors.red.shade700,
                        Colors.red.shade50,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // --- الوصف ---
                  Text(
                    task.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                  ),
                  const SizedBox(height: 12),

                  // --- التقدم ---
                  Text('التقدم', style: TextStyle(color: Colors.grey.shade600)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: LinearProgressIndicator(
                          value: task.progress ?? 0,
                          color: Colors.blue,
                          backgroundColor: Colors.grey.shade200,
                          minHeight: 6,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${((task.progress ?? 0) * 100).toInt()}%',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundImage: NetworkImage(
                              task.assignedImageUrl.isEmpty
                                  ? '${StorageKeys.supabaseStorageBaseUrl}/Avatar.png'
                                  : task.assignedImageUrl,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            Get.find<HomeController>().employees
                                    .firstWhereOrNull(
                                      (emp) => emp.id == task.assignedTo,
                                    )
                                    ?.name ??
                                '',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.calendar_today_outlined,
                                size: 14,
                                color: Colors.grey,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                FunHelper.formatdate(task.fromDate).toString(),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            _stilltime(task.toDate).toString(),
                            style: TextStyle(
                              fontSize: 12,
                              color:
                                  _stilltime(task.toDate).toString() ==
                                          'الوقت منتهي'
                                      ? Colors.red
                                      : Colors.grey,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      OutlinedButton(
                        onPressed: onTap,
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text('عرض التفاصيل'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  _stilltime(DateTime enddate) {
    final now = DateTime.now();
    final difference = enddate.difference(now);

    if (difference.isNegative) {
      return 'الوقت منتهي';
    } else {
      final days = difference.inDays;
      final hours = difference.inHours % 24;
      final minutes = difference.inMinutes % 60;

      String stilltime = '';
      if (days > 0) {
        stilltime += '$days يوم ';
      }
      if (hours > 0) {
        stilltime += '$hours ساعة ';
      }
      if (minutes > 0) {
        stilltime += '$minutes دقيقة';
      }
      return stilltime.trim();
    }
  }

  Widget _buildpriortyTag(String text, Color color, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getprioritybgColor(text),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text.toString().tr,
        style: TextStyle(
          color: _getPriorityColor(text),
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

Widget _buildstatusTag(String text, Color color, Color bg) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: _getStatusbgColor(text),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      text.toString().tr,
      style: TextStyle(
        color: _getStatusColor(text),
        fontSize: 11,
        fontWeight: FontWeight.bold,
      ),
    ),
  );
}

Color _getPriorityColor(String priority) {
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

Color _getprioritybgColor(String priority) {
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

Color _getStatusColor(String status) {
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

Color _getStatusbgColor(String status) {
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

class OptionsMenu extends StatelessWidget {
  final VoidCallback? onView;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const OptionsMenu({this.onView, this.onEdit, this.onDelete, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildOption(
            icon: Icons.remove_red_eye_outlined,
            text: 'عرض',
            color: Colors.green,
            onTap: onView,
          ),
          _buildOption(
            icon: Icons.edit_outlined,
            text: 'تعديل',
            color: Colors.blueAccent,
            onTap: onEdit,
          ),
          _buildOption(
            icon: Icons.delete_outline,
            text: 'حذف',
            color: Colors.red,
            onTap: onDelete,
          ),
        ],
      ),
    );
  }

  Widget _buildOption({
    required IconData icon,
    required String text,
    required Color color,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 45,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.15)),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: color, size: 20),
            Text(
              text,
              style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
