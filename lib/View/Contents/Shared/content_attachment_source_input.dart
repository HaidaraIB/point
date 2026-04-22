import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:point/View/Shared/InputText.dart';
import 'package:point/View/Shared/button.dart';

/// Drag / tap zone + "add from source" (library vs local) — same layout as the
/// add/edit Content desktop dialog (`ContentsTable` attachment rows).
class ContentAttachmentSourceInput extends StatelessWidget {
  const ContentAttachmentSourceInput({
    super.key,
    required this.labelText,
    required this.bodyHintText,
    required this.onTap,
    this.loading = false,
  });

  final String labelText;
  final String bodyHintText;
  final VoidCallback onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: InputText(
        labelText: labelText,
        hintText: '',
        validator: (_) => null,
        enable: false,
        height: 100,
        fillColor: Colors.white,
        expanded: true,
        body: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(color: Colors.grey.shade200),
          child: Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(
                    bodyHintText,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              MainButton(
                width: 132,
                borderSize: 5,
                height: 30,
                fontSize: 11,
                margin: EdgeInsets.zero,
                load: loading,
                title: 'content.attachment_add_from_source'.tr,
                backgroundColor: Colors.white,
                fontColor: AppColors.primaryfontColor,
              ),
            ],
          ),
        ),
        borderRadius: 5,
        borderColor: Colors.grey.shade300,
      ),
    );
  }
}
