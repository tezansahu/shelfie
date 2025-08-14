import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../providers/analytics_provider.dart';

class TagChart extends ConsumerWidget {
  const TagChart({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topTags = ref.watch(topTagsProvider);
    final totalCompletions = ref.watch(totalTagCompletionsProvider);

    if (topTags.isEmpty) {
      return Card(
        child: Container(
          height: 180, // Reduced from 250
          padding: const EdgeInsets.all(16.0),
          child: const Center(
            child: Text('No tag data available'),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Top Tags',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12), // Reduced from 16
            SizedBox(
              height: 150, // Reduced from 200
              child: topTags.length <= 5 
                ? _buildPieChart(context, topTags, totalCompletions)
                : _buildBarChart(context, topTags),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPieChart(BuildContext context, List<dynamic> topTags, int totalCompletions) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
    ];

    return PieChart(
      PieChartData(
        pieTouchData: PieTouchData(
          touchCallback: (FlTouchEvent event, pieTouchResponse) {},
          enabled: true,
        ),
        borderData: FlBorderData(show: false),
        sectionsSpace: 2,
        centerSpaceRadius: 60,
        sections: topTags.asMap().entries.map((entry) {
          final index = entry.key;
          final tag = entry.value;
          final percentage = totalCompletions > 0 
            ? (tag.completedCount / totalCompletions * 100)
            : 0.0;
          
          return PieChartSectionData(
            color: colors[index % colors.length],
            value: tag.completedCount.toDouble(),
            title: '${percentage.toStringAsFixed(1)}%',
            radius: 50,
            titleStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBarChart(BuildContext context, List<dynamic> topTags) {
    final maxCount = topTags.isNotEmpty ? topTags.first.completedCount : 1;
    
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxCount.toDouble() + 1,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final tag = topTags[groupIndex];
              return BarTooltipItem(
                '${tag.name}\n',
                TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                children: [
                  TextSpan(
                    text: '${rod.toY.round()} completions',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < topTags.length) {
                  final tag = topTags[index];
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      tag.name.length > 8 
                        ? '${tag.name.substring(0, 8)}...' 
                        : tag.name,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  );
                }
                return const Text('');
              },
              reservedSize: 30,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
                  style: Theme.of(context).textTheme.bodySmall,
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: topTags.asMap().entries.map((entry) {
          final index = entry.key;
          final tag = entry.value;
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: tag.completedCount.toDouble(),
                color: tag.type == 'preset' ? Colors.blue : Colors.green,
                width: 16,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(4),
                ),
              ),
            ],
          );
        }).toList(),
        gridData: FlGridData(
          show: true,
          drawHorizontalLine: true,
          drawVerticalLine: false,
          horizontalInterval: 1,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.grey.shade300,
              strokeWidth: 1,
            );
          },
        ),
      ),
    );
  }
}
