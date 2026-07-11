import 'package:flutter/material.dart';
import 'package:flutter_dropzone/flutter_dropzone.dart';
import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/View/Shared/InputText.dart';
import 'package:point/View/Shared/button.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/Utils/app_theme_extension.dart';

class DragFilePicker extends StatefulWidget {
  final HomeController controller;
  const DragFilePicker({super.key, required this.controller});

  @override
  State<DragFilePicker> createState() => _DragFilePickerState();
}

class _DragFilePickerState extends State<DragFilePicker> {
  late DropzoneViewController dropController;
  bool highlighted = false;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: (Get.width * 0.7 / 2) - 30,
      child: InputText(
        labelText: 'dragfile'.tr,
        hintText: 'enternotes'.tr,
        enable: false,
        height: 100,
        expanded: true,
        body: Stack(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: highlighted
                    ? AppColors.primary.withValues(alpha: 0.15)
                    : context.appTheme.unselected,
                borderRadius: BorderRadius.circular(5),
                border: Border.all(
                  color: highlighted
                      ? AppColors.primary
                      : context.appTheme.border,
                ),
              ),
              child: InkWell(
                onTap: () async {
                  final files = await widget.controller.pickMultiFiles();
                  for (var file in files) {
                    await widget.controller.uploadFiles(
                      filePathOrBytes: file.bytes!,
                      fileName: file.name,
                    );
                  }
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        'dragfile'.tr,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: context.appTheme.secondaryText,
                        ),
                      ),
                    ),
                    MainButton(
                      width: 100,
                      borderSize: 5,
                      height: 30,
                      fontSize: 12,
                      onPressed: () async {
                        final files = await widget.controller.pickMultiFiles();
                        for (var file in files) {
                          await widget.controller.uploadFiles(
                            filePathOrBytes: file.bytes!,
                            fileName: file.name,
                          );
                        }
                      },
                      title: 'uploadfile'.tr,
                      backgroundColor: context.appTheme.cardSurface,
                      fontColor: context.appTheme.primaryText,
                    ),
                  ],
                ),
              ),
            ),

            /// ✅ Drop Zone (للسحب والإفلات)
            DropzoneView(
              operation: DragOperation.copy,
              onCreated: (ctrl) => dropController = ctrl,
              onDropFile: (ev) async {
                final name = await dropController.getFilename(ev);
                final bytes = await dropController.getFileData(ev);
                await widget.controller.uploadFiles(
                  filePathOrBytes: bytes,
                  fileName: name,
                );
              },
              onHover: () => setState(() => highlighted = true),
              onLeave: () => setState(() => highlighted = false),
            ),
          ],
        ),
        borderRadius: 5,
      ),
    );
  }
}
