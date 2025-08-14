import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/analytics_provider.dart';
import '../models/analytics_models.dart';
import '../widgets/analytics/metric_card.dart';
import '../widgets/analytics/weekly_chart.dart';
import '../widgets/analytics/tag_chart.dart';
import '../widgets/analytics/domain_chart.dart';
import '../widgets/analytics/backlog_chart.dart';
import '../widgets/analytics/date_range_selector.dart';
import 'analytics_debug_screen.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analytics = ref.watch(analyticsSummaryProvider);
    final isLoading = ref.watch(analyticsLoadingProvider);
    final error = ref.watch(analyticsErrorProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bug_report),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const AnalyticsDebugScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(analyticsSummaryProvider);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Date range selector
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: DateRangeSelector(),
          ),
          
          // Content
          Expanded(
            child: analytics.when(
              data: (data) => _buildAnalyticsContent(context, data),
              loading: () => const Center(
                child: CircularProgressIndicator(),
              ),
              error: (error, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Failed to load analytics',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      error.toString(),
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        ref.invalidate(analyticsSummaryProvider);
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsContent(BuildContext context, AnalyticsSummary analytics) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Metrics Section
          Text(
            'Overview',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildMetricsGrid(context, analytics.metrics),
          
          const SizedBox(height: 24), // Reduced from 32
          
          // Charts Section
          Text(
            'Trends & Insights',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12), // Reduced from 16
          
          // Weekly completions chart
          const WeeklyChart(),
          const SizedBox(height: 16), // Reduced from 24
          
          // Two-column layout for smaller charts
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      const TagChart(),
                      const SizedBox(height: 16), // Reduced from 24
                      const BacklogChart(),
                    ],
                  ),
                ),
                const SizedBox(width: 12), // Reduced from 16
                Expanded(
                  child: const DomainChart(),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24), // Reduced from 32
          
          // Streak Section
          _buildStreakSection(context, analytics.streaks),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid(BuildContext context, AnalyticsMetrics metrics) {
    return GridView.count(
      crossAxisCount: 4, // Changed from 2 to 4 for more compact layout
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.2, // Reduced from 1.5 to make cards less tall
      mainAxisSpacing: 12, // Reduced from 16
      crossAxisSpacing: 12, // Reduced from 16
      children: [
        MetricCard(
          title: 'Pending Items',
          value: metrics.pendingTotal.toString(),
          subtitle: '${metrics.pendingReading} reading, ${metrics.pendingViewing} viewing',
          icon: Icons.pending_actions,
          color: Colors.orange,
        ),
        MetricCard(
          title: 'Completed (7d)',
          value: metrics.completed7d.toString(),
          subtitle: 'Last 7 days',
          icon: Icons.check_circle,
          color: Colors.green,
        ),
        MetricCard(
          title: 'Completion Rate',
          value: '${metrics.completionRate.toStringAsFixed(1)}%',
          subtitle: 'Items completed vs added',
          icon: Icons.trending_up,
          color: Colors.blue,
        ),
        MetricCard(
          title: 'Avg Time to Complete',
          value: metrics.avgHoursToComplete != null 
            ? _formatDuration(metrics.avgHoursToComplete!)
            : 'N/A',
          subtitle: 'Average completion time',
          icon: Icons.timer,
          color: Colors.purple,
        ),
      ],
    );
  }

  Widget _buildStreakSection(BuildContext context, AnalyticsStreaks streaks) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.local_fire_department,
                  color: streaks.currentStreak > 0 ? Colors.orange : Colors.grey,
                ),
                const SizedBox(width: 8),
                Text(
                  'Current Streak',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${streaks.currentStreak} ${streaks.currentStreak == 1 ? 'day' : 'days'}',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: streaks.currentStreak > 0 ? Colors.orange : Colors.grey,
              ),
            ),
            if (streaks.currentStreak > 0) ...[
              const SizedBox(height: 4),
              Text(
                'Keep it up! 🔥',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.orange,
                ),
              ),
            ] else ...[
              const SizedBox(height: 4),
              Text(
                'Complete an item today to start a streak!',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDuration(double hours) {
    if (hours < 1) {
      final minutes = (hours * 60).round();
      return '${minutes}m';
    } else if (hours < 24) {
      return '${hours.toStringAsFixed(1)}h';
    } else {
      final days = (hours / 24).round();
      return '${days}d';
    }
  }
}
