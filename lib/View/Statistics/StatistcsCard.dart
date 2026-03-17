import 'package:flutter/material.dart';
import 'package:point/Utils/AppColors.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

class StatisticsCard extends StatefulWidget {
  const StatisticsCard({super.key});

  @override
  State<StatisticsCard> createState() => _StatisticsCardState();
}

class _StatisticsCardState extends State<StatisticsCard> {
  String selectedTab = "آخر 7 أيام";

  final List<String> tabs = ["اليوم", "آخر 7 أيام", "هذا الشهر", "هذا العام"];

  final List<_ChartData> data = [
    _ChartData('Jan', 30, 40, 60),
    _ChartData('Feb', 35, 42, 50),
    _ChartData('Mar', 28, 45, 70),
    _ChartData('Apr', 40, 55, 60),
    _ChartData('May', 45, 60, 80),
    _ChartData('Jun', 50, 58, 70),
    _ChartData('Jul', 55, 65, 90),
    _ChartData('Aug', 60, 63, 95),
    _ChartData('Sep', 58, 68, 100),
    _ChartData('Oct', 65, 70, 110),
    _ChartData('Nov', 68, 75, 115),
    _ChartData('Dec', 72, 80, 120),
  ];

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // العنوان + زر التصدير
            Row(
              // mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'احصائيات',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(width: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children:
                      tabs.map((t) {
                        final isActive = t == selectedTab;
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: GestureDetector(
                            onTap: () => setState(() => selectedTab = t),
                            child: Text(
                              t,
                              style: TextStyle(
                                fontWeight:
                                    isActive
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                color:
                                    isActive
                                        ? AppColors.fontColorGrey
                                        : Colors.grey,
                                decoration:
                                    isActive ? TextDecoration.underline : null,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                ),
                Spacer(),
                OutlinedButton(onPressed: () {}, child: const Text('تصدير')),
              ],
            ),
            const SizedBox(height: 12),

            // التبويبات
            const SizedBox(height: 12),

            // الرسم البياني
            SfCartesianChart(
              primaryYAxis: NumericAxis(isVisible: false),
              primaryXAxis: CategoryAxis(),
              legend: Legend(isVisible: true, position: LegendPosition.bottom),
              tooltipBehavior: TooltipBehavior(enable: true),
              series: [
                SplineAreaSeries<_ChartData, String>(
                  name: 'العملاء',
                  color: Colors.amber.withValues(alpha: 0.05),
                  borderColor: Colors.amber,
                  borderWidth: 2,
                  dataSource: data,
                  xValueMapper: (d, _) => d.month,
                  yValueMapper: (d, _) => d.clients,
                ),
                SplineAreaSeries<_ChartData, String>(
                  name: 'المهام المرسلة',
                  color: Colors.purpleAccent.withValues(alpha: 0.05),
                  borderColor: Colors.purpleAccent,
                  borderWidth: 2,
                  dataSource: data,
                  xValueMapper: (d, _) => d.month,
                  yValueMapper: (d, _) => d.tasks,
                ),
                SplineAreaSeries<_ChartData, String>(
                  name: 'المحتوى المنشور',
                  color: Colors.deepPurple.withValues(alpha: 0.05),
                  borderColor: Colors.deepPurple,
                  borderWidth: 2,
                  dataSource: data,
                  xValueMapper: (d, _) => d.month,
                  yValueMapper: (d, _) => d.content,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ChartData {
  final String month;
  final double clients;
  final double tasks;
  final double content;
  _ChartData(this.month, this.clients, this.tasks, this.content);
}
