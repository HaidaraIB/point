import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Models/ContentModel.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/Services/StorageKeys.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/View/Shared/HorizontalScrollbarAttachments.dart';
import 'package:url_launcher/url_launcher.dart';

void showContentDialogDetails(
  BuildContext context, {
  required ContentModel task,
}) {
  showDialog(
    context: context,
    builder: (context) {
      return ContentDialogDetails(task: task);
    },
  );
}

class ContentDialogDetails extends StatelessWidget {
  final ContentModel task;
  ContentDialogDetails({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final isNarrow = screenWidth < 600;
    final dialogWidth = isNarrow ? screenWidth - 32 : Get.width * 0.7;
    final horizontalInset = isNarrow ? 16.0 : 40.0;

    return Dialog(
      insetPadding: EdgeInsets.symmetric(horizontal: horizontalInset, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.grey.shade100,
      child: Container(
        width: dialogWidth,
        constraints: const BoxConstraints(maxHeight: 700),
        padding: EdgeInsets.all(isNarrow ? 12 : 20),
        child: Padding(
          padding: EdgeInsets.only(top: 10, left: isNarrow ? 6 : 10, right: isNarrow ? 6 : 10),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    Get.back();
                  },
                ),
                // --- المنفذ والعنوان ---
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isNarrow ? 10 : 15,
                    vertical: isNarrow ? 14 : 23,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              task.title,
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              task.title,
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: isNarrow ? 6 : 10),
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundImage: NetworkImage(
                              '${StorageKeys.supabaseStorageBaseUrl}/Avatar.png',
                            ),
                          ),
                          SizedBox(width: 6),
                          Column(
                            children: [
                              Text(
                                'المنفذ',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                              Text(
                                Get.find<HomeController>().employees
                                        .firstWhereOrNull(
                                          (emp) => emp.id == task.executor,
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
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                isNarrow
                    ? SizedBox(
                        height: 110,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                            Container(
                              height: 110,
                              padding: EdgeInsets.symmetric(
                                vertical: 10,
                                horizontal: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                              _infoBox(
                            'العميل',
                            Get.find<HomeController>().clients
                                    .firstWhereOrNull(
                                      (emp) => emp.id == task.clientId,
                                    )
                                    ?.name ??
                                '',
                          ),
                          SizedBox(
                            height: 35,
                            child: const VerticalDivider(
                              color: Colors.grey,
                              thickness: 1,
                            ),
                          ),
                          _infoBox('نوع المحتوى', task.contentType.tr),
                          SizedBox(
                            height: 35,
                            child: const VerticalDivider(
                              color: Colors.grey,
                              thickness: 1,
                            ),
                          ),
                          _infoBox(
                            'المنصة',
                            // '',
                            task.platform.toString().tr,
                          ),
                          SizedBox(
                            height: 35,
                            child: const VerticalDivider(
                              color: Colors.grey,
                              thickness: 1,
                            ),
                          ),
                          _infoBox(
                            'الحاله',
                            // '',
                            task.status.toString().tr,
                          ),
                          SizedBox(
                            height: 35,
                            child: const VerticalDivider(
                              color: Colors.grey,
                              thickness: 1,
                            ),
                          ),
                          _infoBox(
                            'الترويج',
                            // '',
                            task.promotion.toString().tr,
                          ),
                          SizedBox(
                            height: 35,
                            child: const VerticalDivider(
                              color: Colors.grey,
                              thickness: 1,
                            ),
                          ),
                                  _infoBox(
                                    'ملاحظات العميل',
                                    task.clientNotes.toString(),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(width: 10),
                            Container(
                              height: 110,
                              width: 140,
                              padding: EdgeInsets.symmetric(
                                vertical: 10,
                                horizontal: 10,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.center,
                                      child: _infoBoxdates(
                                        'تاريخ النشر',
                                        '${FunHelper.formatdate(task.publishDate)}',
                                        CupertinoIcons.calendar,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        ),
                      )
                    : Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 110,
                              padding: EdgeInsets.symmetric(
                                vertical: 10,
                                horizontal: 10,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _infoBox(
                                      'العميل',
                                      Get.find<HomeController>().clients
                                          .firstWhereOrNull(
                                            (emp) => emp.id == task.clientId,
                                          )
                                          ?.name ??
                                          '',
                                    ),
                                    SizedBox(
                                      height: 35,
                                      child: const VerticalDivider(
                                        color: Colors.grey,
                                        thickness: 1,
                                      ),
                                    ),
                                    _infoBox('نوع المحتوى', task.contentType.tr),
                                    SizedBox(
                                      height: 35,
                                      child: const VerticalDivider(
                                        color: Colors.grey,
                                        thickness: 1,
                                      ),
                                    ),
                                    _infoBox(
                                      'المنصة',
                                      task.platform.toString().tr,
                                    ),
                                    SizedBox(
                                      height: 35,
                                      child: const VerticalDivider(
                                        color: Colors.grey,
                                        thickness: 1,
                                      ),
                                    ),
                                    _infoBox(
                                      'الحاله',
                                      task.status.toString().tr,
                                    ),
                                    SizedBox(
                                      height: 35,
                                      child: const VerticalDivider(
                                        color: Colors.grey,
                                        thickness: 1,
                                      ),
                                    ),
                                    _infoBox(
                                      'الترويج',
                                      task.promotion.toString().tr,
                                    ),
                                    SizedBox(
                                      height: 35,
                                      child: const VerticalDivider(
                                        color: Colors.grey,
                                        thickness: 1,
                                      ),
                                    ),
                                    _infoBox(
                                      'ملاحظات العميل',
                                      task.clientNotes.toString(),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 10),
                          Flexible(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(
                                minWidth: 120,
                                maxWidth: 200,
                              ),
                              child: Container(
                                height: 110,
                                padding: EdgeInsets.symmetric(
                                  vertical: 10,
                                  horizontal: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _infoBoxdates(
                                      'تاريخ النشر',
                                      '${FunHelper.formatdate(task.publishDate)}',
                                      CupertinoIcons.calendar,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                const SizedBox(height: 24),

                // --- المرفقات ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Container(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('الملاحظات', style: textTheme.titleMedium),
                            const SizedBox(height: 8),
                            Container(
                              height: 280,
                              width: isNarrow ? null : (Get.width * 0.35 - 35),
                              constraints: isNarrow
                                  ? null
                                  : null,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,

                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  task.notes ?? '',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primaryfontColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    ),
                    SizedBox(width: isNarrow ? 12 : 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('المرفقات', style: textTheme.titleMedium),
                          const SizedBox(height: 10),
                          Container(
                            width: isNarrow ? null : (Get.width * 0.35 - 35),
                            constraints: isNarrow ? null : null,
                          height: 200,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: EdgeInsets.all(10),
                          child: Column(
                            children: [
                              HorizontalScrollbarAttachments(
                                child: kIsWeb
                                    ? Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          for (var i = 0;
                                              i < task.files!.length;
                                              i++) ...[
                                            if (i > 0)
                                              const SizedBox(width: 16),
                                            _attachmentCard(
                                              FunHelper.getFileNameFromUrl(
                                                  task.files![i]),
                                              '',
                                              onDownload: () async {
                                                final att = task.files![i];
                                                if (await canLaunchUrl(
                                                    Uri.parse(att))) {
                                                  await launchUrl(
                                                    Uri.parse(att),
                                                    mode: LaunchMode
                                                        .externalApplication,
                                                  );
                                                } else {
                                                  throw 'لا يمكن فتح الرابط $att';
                                                }
                                              },
                                            ),
                                          ],
                                        ],
                                      )
                                    : Wrap(
                                        spacing: 16,
                                        children: [
                                          for (var att in task.files!)
                                            _attachmentCard(
                                              FunHelper.getFileNameFromUrl(att),
                                              '',
                                              onDownload: () async {
                                                if (await canLaunchUrl(
                                                  Uri.parse(att),
                                                )) {
                                                  await launchUrl(
                                                    Uri.parse(att),
                                                    mode: LaunchMode
                                                        .externalApplication,
                                                  );
                                                } else {
                                                  throw 'لا يمكن فتح الرابط $att';
                                                }
                                              },
                                            ),
                                        ],
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoBox(String title, String value, {Widget? child}) {
    final screenWidth = Get.width;
    final calculatedWidth = (screenWidth * 0.7 - 550) / 5;
    final width = calculatedWidth < 70 ? 70.0 : calculatedWidth;
    return Container(
      width: width,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 6),
            child ??
                Text(
                  value,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: AppColors.primaryfontColor,
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Widget _infoBoxdates(String title, String value, IconData icon) {
    return Container(
      width: 170,
      margin: EdgeInsets.all(5),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.grey),
              SizedBox(width: 5),
              Text(
                title,
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ),
          SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: AppColors.primaryfontColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _attachmentCard(
    String title,
    String size, {
    required VoidCallback onDownload,
  }) {
    return Container(
      width: 200,
      height: 140,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.blue.withValues(alpha: 0.2),
                radius: 14,
                child: const Icon(
                  Icons.insert_drive_file_outlined,
                  color: Colors.blue,
                  size: 16,
                ),
              ),
              SizedBox(width: 5),
              SizedBox(
                width: 100,
                child: Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,

                    color: AppColors.primaryfontColor,
                  ),
                ),
              ),
            ],
          ),

          Text(size, style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: onDownload,
            icon: const Icon(Icons.download, size: 18),
            label: const Text('تنزيل'),
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              backgroundColor: Color(0xffF9F5FF),
              foregroundColor: Colors.blue,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 20),
            ),
          ),
        ],
      ),
    );
  }
}
