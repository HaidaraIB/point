import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Models/TaskModel.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Services/StorageKeys.dart';
import 'package:point/View/EmployeeDashboard/Shared/AddContentEmployeeDialog.dart';
import 'package:point/View/Shared/responsive.dart';

class EmployeeTaskCard extends StatelessWidget {
  final TaskModel task;
  final VoidCallback onTap;

  EmployeeTaskCard({super.key, required this.task, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<HomeController>(
      builder: (controller) {
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
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
                      tooltip: 'الخيارات',
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      color: Colors.white,
                      elevation: 4,
                      itemBuilder:
                          (context) => [
                            PopupMenuItem(
                              value: 0,
                              height: 30,
                              child: Container(
                                height: 30,
                                margin: EdgeInsets.all(2),
                                padding: EdgeInsets.symmetric(vertical: 5),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(5),
                                  color: Colors.grey.shade200,
                                ),
                                child: Row(
                                  children: [
                                    SizedBox(width: 5),
                                    Text(
                                      "جاري التنفيذ",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            PopupMenuItem(
                              value: 1,

                              height: 30,

                              child: Container(
                                height: 30,
                                margin: EdgeInsets.all(2),
                                padding: EdgeInsets.symmetric(vertical: 5),

                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(5),
                                  color: Colors.grey.shade200,
                                ),
                                child: Row(
                                  children: [
                                    SizedBox(width: 5),
                                    Text(
                                      "ارسال الي المراجعة",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                      onSelected: (value) {
                        if (value == 0) {
                          controller.updateTask(
                            task.copyWith(
                              status: StorageKeys.status_processing,
                            ),
                          );
                        } else if (value == 1) {
                          controller.updateTask(
                            task.copyWith(
                              status: StorageKeys.status_under_revision,
                            ),
                          );
                        }
                      },
                      child: Container(
                        width: 110,
                        height: 32,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(25),
                          border: Border.all(color: Colors.grey),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('تغيير الحالة'),
                            Icon(Icons.keyboard_arrow_down_sharp),
                          ],
                        ),
                      ),
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
                maxLines: 3,
                style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
              ),
              const SizedBox(height: 12),

              // --- التقدم ---
              Text('التقدم', style: TextStyle(color: Colors.grey.shade600)),
              const SizedBox(height: 4),
              // Row(
              //   children: [
              //     Expanded(
              //       child: LinearProgressIndicator(
              //         value: task.progress ?? 0,
              //         color: Colors.blue,
              //         backgroundColor: Colors.grey.shade200,
              //         minHeight: 6,
              //         borderRadius: BorderRadius.circular(10),
              //       ),
              //     ),
              //     const SizedBox(width: 8),
              //     Text(
              //       '${(task.progress ?? 0.0 * 100).toInt()}%',
              //       style: const TextStyle(fontSize: 12),
              //     ),
              //   ],
              // ),
              SizedBox(
                width: Get.width,
                height: 56,
                child: DraggableProgressBar(
                  initialValue: task.progress ?? 0,
                  color: Colors.blue,
                  backgroundColor: Colors.grey.shade200,
                  height: 10,
                  borderRadius: BorderRadius.circular(20),
                  onChanged: (value) {
                    controller.updateTask(task.copyWith(progress: value));
                  },
                ),
              ),

              const SizedBox(height: 12),

              // --- الشخص + التاريخ ---
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
                        (Get.find<HomeController>().employees
                                    .firstWhereOrNull(
                                      (emp) => emp.id == task.assignedTo,
                                    )
                                    ?.name ??
                                '')
                            .substring(
                              0,
                              ((Get.find<HomeController>().employees
                                                  .firstWhereOrNull(
                                                    (emp) =>
                                                        emp.id ==
                                                        task.assignedTo,
                                                  )
                                                  ?.name ??
                                              '')
                                          .length >
                                      10)
                                  ? 10
                                  : ((Get.find<HomeController>().employees
                                              .firstWhereOrNull(
                                                (emp) =>
                                                    emp.id == task.assignedTo,
                                              )
                                              ?.name ??
                                          '')
                                      .length),
                            ),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
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
                ],
              ),
              const SizedBox(height: 12),

              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    SizedBox(
                      width:
                          Responsive.isDesktop(context)
                              ? Get.width * 0.3 - 220
                              : Get.width / 2 - 55,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF5C5589),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          padding: EdgeInsets.symmetric(
                            // horizontal: 48,
                            vertical: 5,
                          ),
                        ),
                        onPressed: onTap,
                        child: Text(
                          Responsive.isDesktop(context)
                              ? "عرض تفاصيل المهمه"
                              : 'عرض التقاصيل',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                    ),
                    SizedBox(width: 20),
                    SizedBox(
                      width:
                          Responsive.isDesktop(context)
                              ? 160
                              : Get.width / 2 - 60,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          padding: EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 5,
                          ),
                        ),
                        onPressed: () {
                          addContentEmployeeDialog(context, model: task);
                        },
                        child: Text(
                          "اضافة محتوى",
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
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

Color _getStatusColor(String status) {
  switch (status) {
    case 'قيد المراجعة':
      return Colors.blue;
    case 'مكتملة':
      return Colors.green;
    case 'ملغاة':
      return Colors.red;
    default:
      return Colors.grey;
  }
}

Color _getStatusbgColor(String status) {
  switch (status) {
    case 'قيد المراجعة':
      return Colors.blue.shade50;
    case 'مكتملة':
      return Colors.green.shade50;
    case 'ملغاة':
      return Colors.red.shade50;
    default:
      return Colors.grey.shade200;
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

class DraggableProgressBar extends StatefulWidget {
  final double initialValue;
  final Color color;
  final Color backgroundColor;
  final double height;
  final BorderRadius borderRadius;
  final ValueChanged<double>? onChanged;
  final int stepsCount;

  const DraggableProgressBar({
    Key? key,
    this.initialValue = 0,
    this.color = Colors.blue,
    this.backgroundColor = const Color(0xFFE0E0E0),
    this.height = 6,
    this.borderRadius = const BorderRadius.all(Radius.circular(10)),
    this.onChanged,
    this.stepsCount = 5,
  }) : super(key: key);

  @override
  State<DraggableProgressBar> createState() => _DraggableProgressBarState();
}

class _DraggableProgressBarState extends State<DraggableProgressBar> {
  double progress = 0.0;

  @override
  void initState() {
    super.initState();
    progress = _snapToStep(widget.initialValue.clamp(0.0, 1.0));
  }

  double _snapToStep(double value) {
    final segments = (widget.stepsCount - 1).clamp(1, 100);
    final stepSize = 1 / segments;
    final snapped = (value / stepSize).round() * stepSize;
    return snapped.clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boxWidth = constraints.maxWidth;
        final segments = (widget.stepsCount - 1).clamp(1, 100);
        final currentStepIndex = (progress * segments).round();
        final markerSize = widget.height + 8;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: markerSize,
              child: Stack(
                children: [
                  Positioned(
                    top: (markerSize - widget.height) / 2,
                    left: 0,
                    right: 0,
                    child: ClipRRect(
                      borderRadius: widget.borderRadius,
                      child: Stack(
                        children: [
                          Container(
                            height: widget.height,
                            color: widget.backgroundColor,
                          ),
                          Positioned(
                            right: 0,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              height: widget.height,
                              width: boxWidth * progress,
                              color: widget.color,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: Row(
                      textDirection: TextDirection.rtl,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(widget.stepsCount, (index) {
                        final isActive = index <= currentStepIndex;
                        return InkWell(
                          borderRadius: BorderRadius.circular(markerSize),
                          onTap: () {
                            final stepProgress = index / segments;
                            final snapped = _snapToStep(stepProgress);
                            if (snapped == progress) return;
                            setState(() => progress = snapped);
                            widget.onChanged?.call(snapped);
                          },
                          child: Container(
                            width: markerSize,
                            height: markerSize,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isActive ? widget.color : Colors.white,
                              border: Border.all(
                                color:
                                    isActive
                                        ? widget.color
                                        : Colors.grey.shade400,
                                width: 1.2,
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${(progress * 100).toStringAsFixed(0)}%',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.black54,
              ),
            ),
          ],
        );
      },
    );
  }
}
