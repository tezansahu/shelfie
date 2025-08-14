import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/analytics_models.dart';
import '../services/analytics_service.dart';

// Analytics service provider
final analyticsServiceProvider = Provider<AnalyticsService>((ref) {
  return AnalyticsService();
});

// Selected date range provider
final selectedDateRangeProvider = StateProvider<AnalyticsDateRange>((ref) {
  return AnalyticsDateRange.days90;
});

// Analytics summary provider
final analyticsSummaryProvider = FutureProvider<AnalyticsSummary>((ref) async {
  final analyticsService = ref.read(analyticsServiceProvider);
  final dateRange = ref.watch(selectedDateRangeProvider);
  
  return analyticsService.getAnalyticsSummary(range: dateRange);
});

// Loading state provider
final analyticsLoadingProvider = Provider<bool>((ref) {
  return ref.watch(analyticsSummaryProvider).isLoading;
});

// Error state provider
final analyticsErrorProvider = Provider<String?>((ref) {
  final asyncValue = ref.watch(analyticsSummaryProvider);
  return asyncValue.hasError ? asyncValue.error.toString() : null;
});

// Refresh analytics function
final refreshAnalyticsProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    ref.invalidate(analyticsSummaryProvider);
  };
});

// Individual chart data providers for easier access
final weeklyCompletionsProvider = Provider<List<WeeklyCompletion>>((ref) {
  final analytics = ref.watch(analyticsSummaryProvider);
  return analytics.when(
    data: (summary) => summary.charts.weeklyCompletions,
    loading: () => [],
    error: (_, __) => [],
  );
});

final topTagsProvider = Provider<List<TagAnalytics>>((ref) {
  final analytics = ref.watch(analyticsSummaryProvider);
  return analytics.when(
    data: (summary) => summary.charts.topTags,
    loading: () => [],
    error: (_, __) => [],
  );
});

final topDomainsProvider = Provider<List<DomainAnalytics>>((ref) {
  final analytics = ref.watch(analyticsSummaryProvider);
  return analytics.when(
    data: (summary) => summary.charts.topDomains,
    loading: () => [],
    error: (_, __) => [],
  );
});

final backlogAgeProvider = Provider<List<BacklogAge>>((ref) {
  final analytics = ref.watch(analyticsSummaryProvider);
  return analytics.when(
    data: (summary) => summary.charts.backlogAge,
    loading: () => [],
    error: (_, __) => [],
  );
});

final metricsProvider = Provider<AnalyticsMetrics?>((ref) {
  final analytics = ref.watch(analyticsSummaryProvider);
  return analytics.when(
    data: (summary) => summary.metrics,
    loading: () => null,
    error: (_, __) => null,
  );
});

final streaksProvider = Provider<AnalyticsStreaks?>((ref) {
  final analytics = ref.watch(analyticsSummaryProvider);
  return analytics.when(
    data: (summary) => summary.streaks,
    loading: () => null,
    error: (_, __) => null,
  );
});

// Computed metrics providers
final completionRateProvider = Provider<double>((ref) {
  final metrics = ref.watch(metricsProvider);
  return metrics?.completionRate ?? 0.0;
});

final pendingItemsProvider = Provider<int>((ref) {
  final metrics = ref.watch(metricsProvider);
  return metrics?.pendingTotal ?? 0;
});

final recentCompletionsProvider = Provider<int>((ref) {
  final metrics = ref.watch(metricsProvider);
  return metrics?.completed7d ?? 0;
});

final avgTimeToCompleteProvider = Provider<double?>((ref) {
  final metrics = ref.watch(metricsProvider);
  return metrics?.avgHoursToComplete;
});

final currentStreakProvider = Provider<int>((ref) {
  final streaks = ref.watch(streaksProvider);
  return streaks?.currentStreak ?? 0;
});

// Chart-specific computed providers
final maxWeeklyCompletionsProvider = Provider<int>((ref) {
  final weeklyData = ref.watch(weeklyCompletionsProvider);
  if (weeklyData.isEmpty) return 0;
  
  return weeklyData.map((week) => week.completed).reduce((a, b) => a > b ? a : b);
});

final totalTagCompletionsProvider = Provider<int>((ref) {
  final topTags = ref.watch(topTagsProvider);
  return topTags.fold(0, (sum, tag) => sum + tag.completedCount);
});

final mostActiveTagProvider = Provider<TagAnalytics?>((ref) {
  final topTags = ref.watch(topTagsProvider);
  return topTags.isNotEmpty ? topTags.first : null;
});

final mostProductiveDomainProvider = Provider<DomainAnalytics?>((ref) {
  final topDomains = ref.watch(topDomainsProvider);
  return topDomains.isNotEmpty ? topDomains.first : null;
});

// Backlog analysis providers
final oldestBacklogBucketProvider = Provider<BacklogAge?>((ref) {
  final backlogAge = ref.watch(backlogAgeProvider);
  // Find the bucket with the most items in the oldest category
  return backlogAge.isNotEmpty 
    ? backlogAge.reduce((a, b) => a.count > b.count ? a : b) 
    : null;
});

final totalBacklogItemsProvider = Provider<int>((ref) {
  final backlogAge = ref.watch(backlogAgeProvider);
  return backlogAge.fold(0, (sum, bucket) => sum + bucket.count);
});
