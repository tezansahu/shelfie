import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../providers/analytics_provider.dart';

class BacklogChart extends ConsumerWidget {
  const BacklogChart({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final backlogAge = ref.watch(backlogAgeProvider);
    final totalBacklog = ref.watch(totalBacklogItemsProvider);

    if (backlogAge.isEmpty) {
      return Card(
        child: Container(
          height: 180, // Reduced from 250
          padding: const EdgeInsets.all(16.0),
          child: const Center(
            child: Text('No backlog data available'),
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
              'Backlog Age Distribution',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '$totalBacklog pending items',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 12), // Reduced from 16
            SizedBox(
              height: 140, // Reduced from 180
              child: PieChart(
                PieChartData(
                  pieTouchData: PieTouchData(
                    touchCallback: (FlTouchEvent event, pieTouchResponse) {},
                    enabled: true,
                  ),
                  borderData: FlBorderData(show: false),
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                  sections: backlogAge.asMap().entries.map((entry) {
                    final bucket = entry.value;
                    final percentage = totalBacklog > 0 
                      ? (bucket.count / totalBacklog * 100)
                      : 0.0;
                    
                    return PieChartSectionData(
                      color: _getAgeColor(bucket.ageBucket),
                      value: bucket.count.toDouble(),
                      title: percentage > 5 ? '${percentage.toStringAsFixed(0)}%' : '',
                      radius: 35,
                      titleStyle: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 8),
            _buildLegend(context, backlogAge, totalBacklog),
          ],
        ),
      ),
    );
  }

  Widget _buildLegend(BuildContext context, List<dynamic> backlogAge, int totalBacklog) {
    return Column(
      children: backlogAge.map((bucket) {
        final percentage = totalBacklog > 0 
          ? (bucket.count / totalBacklog * 100)
          : 0.0;
        
        return Padding(
          padding: const EdgeInsets.only(bottom: 4.0),
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: _getAgeColor(bucket.ageBucket),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  bucket.ageBucket,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              Text(
                '${bucket.count} (${percentage.toStringAsFixed(1)}%)',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Color _getAgeColor(String ageBucket) {
    switch (ageBucket) {
      case '0-7 days':
        return Colors.green;
      case '8-30 days':
        return Colors.blue;
      case '31-90 days':
        return Colors.orange;
      case '91-180 days':
        return Colors.red.shade400;
      case '180+ days':
        return Colors.red.shade700;
      default:
        return Colors.grey;
    }
  }
}
