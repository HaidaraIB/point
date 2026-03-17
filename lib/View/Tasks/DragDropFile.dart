import 'package:flutter/material.dart';
import 'package:flutter_dropzone/flutter_dropzone.dart';
import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/View/Shared/InputText.dart';
import 'package:point/View/Shared/button.dart';

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
        fillColor: Colors.white,
        expanded: true,
        body: Stack(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: highlighted ? Colors.blue.shade50 : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(5),
                border: Border.all(
                  color:
                      highlighted
                          ? AppColors.primaryfontColor
                          : Colors.grey.shade300,
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
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    MainButton(
                      width: 100,
                      bordersize: 5,
                      height: 30,
                      fontsize: 12,
                      onpress: () async {
                        final files = await widget.controller.pickMultiFiles();
                        for (var file in files) {
                          await widget.controller.uploadFiles(
                            filePathOrBytes: file.bytes!,
                            fileName: file.name,
                          );
                        }
                      },
                      title: 'uploadfile'.tr,
                      backgroundcolor: Colors.white,
                      fontcolor: AppColors.primaryfontColor,
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
        borderColor: Colors.grey.shade300,
      ),
    );
  }
}
