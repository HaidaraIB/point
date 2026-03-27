import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Localization/AppLocaleKeys.dart';
import 'package:point/Models/ContentModel.dart';
import 'package:point/Services/FunHelper.dart';
import 'package:point/View/Tasks/DetailsDialogs/TaskDetailsDialogHelpers.dart';
import 'package:url_launcher/url_launcher.dart';

class ContentDetailsMobilePage extends StatelessWidget {
  const ContentDetailsMobilePage({super.key, required this.task});

  final ContentModel task;

  @override
  Widget build(BuildContext context) {
    final clientName =
        Get.find<HomeController>().clients
            .firstWhereOrNull((client) => client.id == task.clientId)
            ?.name ??
        '-';
    final promotionValue =
        (task.promotion == null || task.promotion!.trim().isEmpty)
            ? AppLocaleKeys.contentDialogNoPromotion.tr
            : FunHelper.trStored(
              task.promotion,
              kind: StoredValueKind.promotion,
            );
    final publishDate =
        task.publishDate == null
            ? AppLocaleKeys.contentDialogNoDate.tr
            : FunHelper.formatdate(task.publishDate).toString();
    final platformValue = _platformText(task.platform);
    final notes =
        (task.clientNotes?.trim().isNotEmpty ?? false)
            ? task.clientNotes!.trim()
            : AppLocaleKeys.contentDialogNoNotes.tr;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F2FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0.3,
        title: Text('content.details_title'.tr),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              _tile(
                context,
                title: AppLocaleKeys.contentDialogClient.tr,
                value: clientName,
                icon: Icons.person_outline,
              ),
              _tile(
                context,
                title: AppLocaleKeys.contentType.tr,
                value: FunHelper.trStored(
                  task.contentType,
                  kind: StoredValueKind.contentType,
                ),
                icon: Icons.category_outlined,
              ),
              _tile(
                context,
                title: AppLocaleKeys.platform.tr,
                value: platformValue,
                icon: Icons.public,
              ),
              _tile(
                context,
                title: AppLocaleKeys.status.tr,
                value: task.status.tr,
                icon: Icons.flag_outlined,
              ),
              _tile(
                context,
                title: AppLocaleKeys.promotion.tr,
                value: promotionValue,
                icon: Icons.campaign_outlined,
              ),
              _tile(
                context,
                title: AppLocaleKeys.clientNotes.tr,
                value: notes,
                icon: Icons.note_alt_outlined,
              ),
              _tile(
                context,
                title: AppLocaleKeys.publishDate.tr,
                value: publishDate,
                icon: Icons.calendar_month_outlined,
              ),
              _attachmentsCard(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tile(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
  }) {
    final isRtl =
        Directionality.of(context) == TextDirection.rtl ||
        Get.locale?.languageCode == 'ar';
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE7E0F0)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  textAlign: isRtl ? TextAlign.right : TextAlign.left,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                radius: 14,
                backgroundColor: const Color(0xFFEDE2FF),
                child: Icon(
                  icon,
                  size: 16,
                  color: const Color(0xFF7E57C2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  value,
                  textAlign: isRtl ? TextAlign.right : TextAlign.left,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _attachmentsCard(BuildContext context) {
    final isRtl =
        Directionality.of(context) == TextDirection.rtl ||
        Get.locale?.languageCode == 'ar';
    final files =
        (task.files ?? [])
            .whereType<String>()
            .where((e) => e.trim().isNotEmpty)
            .toList();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE7E0F0)),
      ),
      child: Column(
        crossAxisAlignment:
            isRtl ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  AppLocaleKeys.contentDialogAttachments.tr,
                  textAlign: isRtl ? TextAlign.right : TextAlign.left,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const CircleAvatar(
                radius: 14,
                backgroundColor: Color(0xFFEDE2FF),
                child: Icon(
                  Icons.attach_file_outlined,
                  size: 16,
                  color: Color(0xFF7E57C2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (files.isEmpty)
            Align(
              alignment: isRtl ? Alignment.centerRight : Alignment.centerLeft,
              child: Text(
                AppLocaleKeys.contentDialogNoAttachments.tr,
                style: TextStyle(color: Colors.grey.shade600),
                textAlign: isRtl ? TextAlign.end : TextAlign.start,
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: files.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                mainAxisExtent: 84,
              ),
              itemBuilder: (context, index) {
                final rawUrl = files[index];
                return TaskDetailsDialogHelpers.attachmentThumbnail(
                  rawUrl,
                  onOpen: () => _openAttachment(rawUrl),
                );
              },
            ),
        ],
      ),
    );
  }

  Future<void> _openAttachment(String rawUrl) async {
    final uri = Uri.tryParse(rawUrl);
    if (uri == null) {
      FunHelper.showSnackbar(
        'error'.tr,
        AppLocaleKeys.contentDialogOpenLinkFailed.tr,
      );
      return;
    }
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) {
      FunHelper.showSnackbar(
        'error'.tr,
        AppLocaleKeys.contentDialogOpenLinkFailed.tr,
      );
    }
  }

  String _platformText(List<dynamic> platform) {
    if (platform.isEmpty) return '-';
    return platform.map((e) => e.toString().tr).join(' - ');
  }
}
