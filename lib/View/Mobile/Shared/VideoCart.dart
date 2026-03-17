import 'package:flutter/material.dart';
import 'package:get/get_navigation/get_navigation.dart';
import 'package:get/instance_manager.dart';
import 'package:point/Models/ContentModel.dart';
import 'package:point/View/Mobile/Shared/PdfViewr.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:dots_indicator/dots_indicator.dart';

class VideoCard extends StatelessWidget {
  final ContentModel model;
  VideoCard({required this.model});
  // const VideoCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: Get.width,
        margin: EdgeInsets.symmetric(horizontal: 15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ClipRRect(
            //   borderRadius: BorderRadius.circular(12),
            //   child: Stack(
            //     alignment: Alignment.center,
            //     children: [
            //       Container(
            //         height: 160,
            //         width: double.infinity,
            //         color: Colors.grey[300],
            //       ),
            //       Icon(
            //         Icons.file_copy_outlined,
            //         size: 60,
            //         color: Colors.white70,
            //       ),

            //       Positioned(
            //         left: 8,
            //         bottom: 8,
            //         child: Container(
            //           height: 4,
            //           width: 120,
            //           decoration: BoxDecoration(
            //             color: Colors.white54,
            //             borderRadius: BorderRadius.circular(2),
            //           ),
            //         ),
            //       ),
            //     ],
            //   ),
            // ),
            FilesPreviewWidget(files: model.files?.cast<String>() ?? []),

            const SizedBox(height: 12),

            // عنوان الفيديو
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                "العنوان",
                style: TextStyle(
                  color: Colors.blueAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(height: 4),

            // اسم المؤسسة
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                model.title,
                style: TextStyle(fontSize: 13, color: Colors.grey[700]),
              ),
            ),

            const SizedBox(height: 12),
            if (model.notes != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  "الملاحظات",
                  style: TextStyle(
                    color: Colors.blueAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            // الوصف
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                model.notes ?? '',
                style: TextStyle(fontSize: 13, color: Colors.grey[800]),
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

String getFileType(String url) {
  final lowerUrl = url.toLowerCase();
  if (lowerUrl.endsWith('.jpg') ||
      lowerUrl.endsWith('.jpeg') ||
      lowerUrl.endsWith('.png') ||
      lowerUrl.endsWith('.gif') ||
      lowerUrl.endsWith('.webp')) {
    return 'image';
  } else if (lowerUrl.endsWith('.mp4') ||
      lowerUrl.endsWith('.mov') ||
      lowerUrl.endsWith('.avi') ||
      lowerUrl.endsWith('.mkv')) {
    return 'video';
  } else if (lowerUrl.endsWith('.pdf')) {
    return 'pdf';
  } else {
    return 'unknown';
  }
}

Widget buildFilePreview(String url) {
  final type = getFileType(url);

  switch (type) {
    case 'image':
      return InkWell(
        onTap: () {
          Get.to(() => ImagePreviewPage(url: url));
        },
        child: Image.network(url, fit: BoxFit.cover),
      );

    case 'video':
      return InkWell(
        onTap: () {
          Get.to(() => VideoPlayerPage(url: url));
        },
        child: const Icon(
          Icons.play_circle_fill,
          color: Colors.deepPurple,
          size: 52,
        ),
      );

    case 'pdf':
      return InkWell(
        onTap: () {
          Get.to(() => PdfViewerPage(url: url));
        },
        child: const Icon(Icons.picture_as_pdf, color: Colors.red, size: 48),
      );

    default:
      return InkWell(
        onTap: () {
          Get.to(() => UnknownFilePage(url: url));
        },
        child: const Icon(
          Icons.insert_drive_file,
          color: Colors.grey,
          size: 46,
        ),
      );
  }
}

class ImagePreviewPage extends StatelessWidget {
  final String url;
  const ImagePreviewPage({super.key, required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF5C5589),
        title: const Text(
          'عرض الصورة',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Get.back(),
        ),
        centerTitle: true,
      ),
      body: InteractiveViewer(
        child: Center(child: Image.network(url, fit: BoxFit.contain)),
      ),
    );
  }
}

class VideoPlayerPage extends StatefulWidget {
  final String url;
  const VideoPlayerPage({super.key, required this.url});

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  late VideoPlayerController controller;
  bool isReady = false;

  @override
  void initState() {
    super.initState();
    controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        setState(() => isReady = true);
        controller.play();
      });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF5C5589),
        title: const Text(
          'عرض الفيديو',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Get.back(),
        ),
        centerTitle: true,
      ),
      body: Center(
        child:
            isReady
                ? AspectRatio(
                  aspectRatio: controller.value.aspectRatio,
                  child: Stack(
                    alignment: Alignment.bottomCenter,
                    children: [
                      VideoPlayer(controller),
                      VideoProgressIndicator(controller, allowScrubbing: true),
                      Positioned(
                        bottom: 20,
                        child: IconButton(
                          icon: Icon(
                            controller.value.isPlaying
                                ? Icons.pause_circle_filled
                                : Icons.play_circle_fill,
                            color: Colors.white,
                            size: 60,
                          ),
                          onPressed: () {
                            setState(() {
                              controller.value.isPlaying
                                  ? controller.pause()
                                  : controller.play();
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                )
                : const CircularProgressIndicator(color: Colors.white),
      ),
    );
  }
}

class UnknownFilePage extends StatelessWidget {
  final String url;
  const UnknownFilePage({super.key, required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF5C5589),
        title: const Text(
          'عرض الملف',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Get.back(),
        ),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.insert_drive_file, size: 80, color: Colors.grey),
            const SizedBox(height: 20),
            const Text(
              'لا يمكن عرض هذا الملف داخل التطبيق',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () async {
                if (await canLaunchUrl(Uri.parse(url))) {
                  await launchUrl(
                    Uri.parse(url),
                    mode: LaunchMode.externalApplication,
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5C5589),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 14,
                ),
              ),
              icon: const Icon(Icons.open_in_new, color: Colors.white),
              label: const Text(
                'فتح الملف',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class VideoPlayerWidget extends StatefulWidget {
  final String url;
  const VideoPlayerWidget({super.key, required this.url});

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late VideoPlayerController controller;

  @override
  void initState() {
    super.initState();
    controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        setState(() {});
        controller.play();
      });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return controller.value.isInitialized
        ? VideoPlayer(controller)
        : const Center(child: CircularProgressIndicator());
  }
}

class FilesPreviewWidget extends StatefulWidget {
  final List<String> files;

  const FilesPreviewWidget({super.key, required this.files});

  @override
  State<FilesPreviewWidget> createState() => _FilesPreviewWidgetState();
}

class _FilesPreviewWidgetState extends State<FilesPreviewWidget> {
  double currentIndexPage = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 150,
          child: PageView(
            scrollDirection: Axis.horizontal,
            onPageChanged: (index) {
              setState(() {
                currentIndexPage = index.toDouble();
              });
            },
            children: [
              for (var url in widget.files)
                Container(
                  height: 150,
                  width: Get.width - 100,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(color: Colors.grey.shade200, blurRadius: 5),
                    ],
                  ),
                  child: buildFilePreview(url),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        DotsIndicator(
          dotsCount: widget.files.length < 1 ? 1 : widget.files.length,
          position: currentIndexPage,
          decorator: DotsDecorator(
            size: const Size.square(8.0),
            activeSize: const Size(18.0, 8.0),
            activeShape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(5.0),
            ),
            activeColor: Colors.blue,
            color: Colors.grey.shade400,
          ),
        ),
      ],
    );
  }
}
