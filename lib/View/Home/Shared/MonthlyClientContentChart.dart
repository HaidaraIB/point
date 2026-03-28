import 'dart:math';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:point/Controller/HomeController.dart';
import 'package:point/Models/ContentModel.dart';
import 'package:point/Services/StorageKeys.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

bool _isPublishedThisCalendarMonth(ContentModel c, DateTime nowLocal) {
  if (c.status != StorageKeys.status_published) return false;
  final pd = c.publishDate;
  if (pd == null) return false;
  final l = pd.toLocal();
  return l.year == nowLocal.year && l.month == nowLocal.month;
}

class MonthlyClientContentChart extends StatelessWidget {
  const MonthlyClientContentChart({super.key});

  static const double _chartHeight = 320;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final hc = Get.find<HomeController>();
      final nowLocal = DateTime.now();
      final monthlyPublished =
          hc.contents
              .where((c) => _isPublishedThisCalendarMonth(c, nowLocal))
              .toList();

      final counts = <String, int>{};
      for (final c in monthlyPublished) {
        counts[c.clientId] = (counts[c.clientId] ?? 0) + 1;
      }

      final data = <ClientContent>[];
      for (final e in counts.entries) {
        final client = hc.clients.firstWhereOrNull((cl) => cl.id == e.key);
        if (client == null) continue;
        final name = client.name?.trim();
        if (name == null || name.isEmpty) continue;
        final color =
            Colors
                .primaries[e.key.hashCode.abs() % Colors.primaries.length]
                .shade300;
        data.add(ClientContent(name, e.value.toDouble(), color));
      }
      data.sort((a, b) => a.name.compareTo(b.name));

      final maxVal =
          data.isEmpty
              ? 1.0
              : data.map((e) => e.value).reduce((a, b) => a > b ? a : b);
      final yMax = max(5.0, maxVal * 1.2);

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
              SizedBox(
                height: _chartHeight,
                child:
                    data.isEmpty
                        ? Center(
                          child: Text(
                            'home.chart_monthly_published_empty'.tr,
                            textDirection: TextDirection.rtl,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        )
                        : SfCartesianChart(
                          plotAreaBorderWidth: 0,
                          primaryXAxis: CategoryAxis(
                            majorGridLines: const MajorGridLines(width: 0),
                            labelStyle: GoogleFonts.almarai(fontSize: 12),
                          ),
                          primaryYAxis: NumericAxis(
                            isVisible: false,
                            minimum: 0,
                            maximum: yMax,
                          ),
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
                          annotations: () {
                            final values = data.map((e) => e.value);
                            final chartMaxVal =
                                values.isEmpty
                                    ? 1.0
                                    : values.reduce((a, b) => a > b ? a : b);
                            final chartMinVal =
                                values.isEmpty
                                    ? 0.0
                                    : values.reduce((a, b) => a < b ? a : b);
                            final valueRange = (chartMaxVal - chartMinVal)
                                .clamp(0.001, double.infinity);
                            const minRadiusPx = 4.0;
                            const maxRadiusPx = 12.0;
                            const extraMarginPx = 2.0;
                            return data.map((client) {
                              final t =
                                  (client.value - chartMinVal) / valueRange;
                              final bubbleRadiusPx =
                                  minRadiusPx + t * (maxRadiusPx - minRadiusPx);
                              final stickHeight = (client.value *
                                          (_chartHeight / yMax) -
                                      2 * bubbleRadiusPx -
                                      extraMarginPx)
                                  .clamp(4.0, double.infinity);
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
                            }).toList();
                          }(),
                        ),
              ),
            ],
          ),
        ),
      );
    });
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
