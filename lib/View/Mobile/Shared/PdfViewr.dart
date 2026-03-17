import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:get/get.dart';

class PdfViewerPage extends StatelessWidget {
  final String url;

  const PdfViewerPage({super.key, required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'عرض الملف PDF',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF5C5589), // نفس لونك الأساسي
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Get.back(),
        ),
      ),
      body: SfPdfViewer.network(
        url,
        canShowPaginationDialog: true,
        canShowScrollHead: true,
        canShowScrollStatus: true,
      ),
    );
  }
}
