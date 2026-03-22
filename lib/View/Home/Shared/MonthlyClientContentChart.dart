import 'dart:math';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

class MonthlyClientContentChart extends StatelessWidget {
  const MonthlyClientContentChart({super.key});

  @override
  Widget build(BuildContext context) {
    final data = [
      for (var c in Get.find<HomeController>().contents)
        if (Get.find<HomeController>().clients.firstWhereOrNull(
              (cl) => cl.id == c.clientId,
            ) !=
            null)
          ClientContent(
            '${Get.find<HomeController>().clients.firstWhereOrNull((cl) => cl.id == c.clientId)?.name}',
            Get.find<HomeController>().contents
                    .where((content) => content.clientId == c.clientId)
                    .length *
                1.toDouble(),

            Colors
                .primaries[Random().nextInt(Colors.primaries.length)]
                .shade300,
          ),
      // ClientContent('اسم العميل', 10, Colors.redAccent),
      // ClientContent('اسم العميل', 40, Colors.purple.shade100),
    ];

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 1,
      color: Colors.white,
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🔹 العنوان
            Text(
              'home.chart_monthly_published_title'.tr,
              textDirection: TextDirection.rtl,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 20),

            // 🔹 الرسم البياني
            SizedBox(
              height: 320,
              child: SfCartesianChart(
                plotAreaBorderWidth: 0,
                primaryXAxis: CategoryAxis(
                  majorGridLines: const MajorGridLines(width: 0),
                  labelStyle: GoogleFonts.almarai(fontSize: 12),
                ),
                primaryYAxis: NumericAxis(
                  isVisible: false,
                  minimum: 0,
                  maximum: 120,
                ),

                // 🔹 السلسلة
                series: <BubbleSeries<ClientContent, String>>[
                  BubbleSeries<ClientContent, String>(
                    dataSource: data,
                    xValueMapper: (ClientContent c, _) => c.name,
                    yValueMapper: (ClientContent c, _) => c.value,
                    pointColorMapper: (ClientContent c, _) => c.color,
                    sizeValueMapper: (ClientContent c, _) => c.value,
                    minimumRadius: 3,
                    maximumRadius: 10,
                    dataLabelSettings: const DataLabelSettings(
                      isVisible: true,
                      textStyle: TextStyle(
                        color: Colors.black,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                      labelAlignment: ChartDataLabelAlignment.top,
                    ),
                  ),
                ],

                // 🔹 أنوتيشن الخط من الاسم للفقاعة
                annotations:
                    () {
                      final values = data.map((e) => e.value);
                      final maxVal = values.isEmpty ? 1.0 : values.reduce((a, b) => a > b ? a : b);
                      final minVal = values.isEmpty ? 0.0 : values.reduce((a, b) => a < b ? a : b);
                      final valueRange = (maxVal - minVal).clamp(0.001, double.infinity);
                      const minRadiusPx = 4.0;
                      const maxRadiusPx = 12.0;
                      const extraMarginPx = 2.0;
                      return data.map(
                        (client) {
                          final t = (client.value - minVal) / valueRange;
                          final bubbleRadiusPx = minRadiusPx + t * (maxRadiusPx - minRadiusPx);
                          final stickHeight = (client.value * (320 / 120) - 2 * bubbleRadiusPx - extraMarginPx).clamp(4.0, double.infinity);
                          return CartesianChartAnnotation(
                              widget: CustomPaint(
                                size: Size(12, stickHeight),
                                painter: LinePainter(),
                              ),
                              coordinateUnit: CoordinateUnit.point,
                              x: client.name,
                              y: 0,
                              verticalAlignment: ChartAlignment.far,
                            );
                        },
                      ).toList();
                    }(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ClientContent {
  final String name;
  final double value;
  final Color color;

  ClientContent(this.name, this.value, this.color);
}

// 🎨 يرسم الخط الرأسي من الاسم إلى الفقاعة
class LinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = Colors.grey.shade400
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke;

    // يرسم خط رأسي لأعلى
    canvas.drawLine(
      Offset(size.width / 2, size.height),
      Offset(size.width / 2, 0),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
