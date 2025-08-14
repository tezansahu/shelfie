import 'package:freezed_annotation/freezed_annotation.dart';

part 'analytics_models.freezed.dart';
part 'analytics_models.g.dart';

@freezed
class AnalyticsSummary with _$AnalyticsSummary {
  const factory AnalyticsSummary({
    required AnalyticsMetrics metrics,
    required AnalyticsCharts charts,
    required AnalyticsStreaks streaks,
  }) = _AnalyticsSummary;

  factory AnalyticsSummary.fromJson(Map<String, dynamic> json) => _$AnalyticsSummaryFromJson(json);
}

@freezed
class AnalyticsMetrics with _$AnalyticsMetrics {
  const factory AnalyticsMetrics({
    @JsonKey(name: 'pending_total') required int pendingTotal,
    @JsonKey(name: 'pending_reading') required int pendingReading,
    @JsonKey(name: 'pending_viewing') required int pendingViewing,
    @JsonKey(name: 'completed_7d') required int completed7d,
    @JsonKey(name: 'completed_30d') required int completed30d,
    @JsonKey(name: 'completed_period') required int completedPeriod,
    @JsonKey(name: 'completion_rate') required double completionRate,
    @JsonKey(name: 'avg_hours_to_complete') required double? avgHoursToComplete,
    @JsonKey(name: 'median_hours_to_complete') required double? medianHoursToComplete,
  }) = _AnalyticsMetrics;

  factory AnalyticsMetrics.fromJson(Map<String, dynamic> json) => _$AnalyticsMetricsFromJson(json);
}

@freezed
class AnalyticsCharts with _$AnalyticsCharts {
  const factory AnalyticsCharts({
    @JsonKey(name: 'weekly_completions') required List<WeeklyCompletion> weeklyCompletions,
    @JsonKey(name: 'top_tags') required List<TagAnalytics> topTags,
    @JsonKey(name: 'top_domains') required List<DomainAnalytics> topDomains,
    @JsonKey(name: 'backlog_age') required List<BacklogAge> backlogAge,
  }) = _AnalyticsCharts;

  factory AnalyticsCharts.fromJson(Map<String, dynamic> json) => _$AnalyticsChartsFromJson(json);
}

@freezed
class AnalyticsStreaks with _$AnalyticsStreaks {
  const factory AnalyticsStreaks({
    @JsonKey(name: 'current_streak') required int currentStreak,
  }) = _AnalyticsStreaks;

  factory AnalyticsStreaks.fromJson(Map<String, dynamic> json) => _$AnalyticsStreaksFromJson(json);
}

@freezed
class WeeklyCompletion with _$WeeklyCompletion {
  const factory WeeklyCompletion({
    required String week,
    @JsonKey(name: 'week_number') required int weekNumber,
    required int year,
    required int added,
    required int completed,
  }) = _WeeklyCompletion;

  factory WeeklyCompletion.fromJson(Map<String, dynamic> json) => _$WeeklyCompletionFromJson(json);
}

@freezed
class TagAnalytics with _$TagAnalytics {
  const factory TagAnalytics({
    required String name,
    required String type,
    @JsonKey(name: 'completed_count') required int completedCount,
  }) = _TagAnalytics;

  factory TagAnalytics.fromJson(Map<String, dynamic> json) => _$TagAnalyticsFromJson(json);
}

@freezed
class DomainAnalytics with _$DomainAnalytics {
  const factory DomainAnalytics({
    required String domain,
    @JsonKey(name: 'total_count') required int totalCount,
    @JsonKey(name: 'completed_count') required int completedCount,
  }) = _DomainAnalytics;

  factory DomainAnalytics.fromJson(Map<String, dynamic> json) => _$DomainAnalyticsFromJson(json);
}

@freezed
class BacklogAge with _$BacklogAge {
  const factory BacklogAge({
    @JsonKey(name: 'age_bucket') required String ageBucket,
    required int count,
  }) = _BacklogAge;

  factory BacklogAge.fromJson(Map<String, dynamic> json) => _$BacklogAgeFromJson(json);
}

// Enum for analytics date ranges
enum AnalyticsDateRange {
  week7('7 days', 7),
  days30('30 days', 30),
  days90('90 days', 90),
  days180('180 days', 180),
  year1('1 year', 365);

  const AnalyticsDateRange(this.label, this.days);
  
  final String label;
  final int days;

  DateTime get startDate => DateTime.now().subtract(Duration(days: days));
}
