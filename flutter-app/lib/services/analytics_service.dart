import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/analytics_models.dart';

class AnalyticsService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Get analytics summary for the specified date range
  Future<AnalyticsSummary> getAnalyticsSummary({
    AnalyticsDateRange range = AnalyticsDateRange.days90,
  }) async {
    try {
      // Call the enhanced analytics function directly
      final response = await _supabase.rpc(
        'analytics_summary',
        params: {
          'since': range.startDate.toIso8601String(),
        },
      );

      if (response == null) {
        throw Exception('No analytics data received from analytics_summary function');
      }

      // Debug print the raw response
      print('Analytics response: $response');

      return AnalyticsSummary.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      print('Analytics error details: $e');
      // Return a default/empty analytics summary for now
      return const AnalyticsSummary(
        metrics: AnalyticsMetrics(
          pendingTotal: 0,
          pendingReading: 0,
          pendingViewing: 0,
          completed7d: 0,
          completed30d: 0,
          completedPeriod: 0,
          completionRate: 0.0,
          avgHoursToComplete: null,
          medianHoursToComplete: null,
        ),
        charts: AnalyticsCharts(
          weeklyCompletions: [],
          topTags: [],
          topDomains: [],
          backlogAge: [],
        ),
        streaks: AnalyticsStreaks(currentStreak: 0),
      );
    }
  }

  /// Get raw analytics data for custom processing
  Future<Map<String, dynamic>> getRawAnalytics({
    AnalyticsDateRange range = AnalyticsDateRange.days90,
  }) async {
    final response = await _supabase.rpc(
      'analytics_summary',
      params: {
        'since': range.startDate.toIso8601String(),
      },
    );

    return response as Map<String, dynamic>;
  }

  /// Get completion stats for a specific time period
  Future<Map<String, dynamic>> getCompletionStats({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final query = _supabase
        .from('items')
        .select('id, status, content_type, finished_at, added_at')
        .gte('added_at', startDate.toIso8601String())
        .lte('added_at', endDate.toIso8601String());

    final items = await query;
    
    final total = items.length;
    final completed = items.where((item) => item['status'] == 'completed').length;
    final articles = items.where((item) => item['content_type'] == 'article').length;
    final videos = items.where((item) => item['content_type'] == 'video').length;
    
    return {
      'total': total,
      'completed': completed,
      'articles': articles,
      'videos': videos,
      'completion_rate': total > 0 ? (completed / total * 100).round() : 0,
    };
  }

  /// Get trending tags by completion count
  Future<List<Map<String, dynamic>>> getTrendingTags({
    AnalyticsDateRange range = AnalyticsDateRange.days30,
    int limit = 10,
  }) async {
    final query = '''
      SELECT 
        t.name,
        t.type,
        COUNT(*) as completion_count
      FROM tags t
      JOIN item_tags it ON t.id = it.tag_id
      JOIN items i ON it.item_id = i.id
      WHERE i.status = 'completed'
        AND i.finished_at >= '${range.startDate.toIso8601String()}'
      GROUP BY t.id, t.name, t.type
      ORDER BY COUNT(*) DESC
      LIMIT $limit
    ''';

    final response = await _supabase.rpc('execute_query', params: {'query': query});
    return List<Map<String, dynamic>>.from(response ?? []);
  }

  /// Get domain statistics
  Future<List<Map<String, dynamic>>> getDomainStats({
    AnalyticsDateRange range = AnalyticsDateRange.days90,
    int limit = 10,
  }) async {
    final query = '''
      SELECT 
        domain,
        COUNT(*) as total_count,
        COUNT(*) FILTER (WHERE status = 'completed') as completed_count,
        ROUND(
          COUNT(*) FILTER (WHERE status = 'completed')::decimal / COUNT(*) * 100, 
          1
        ) as completion_rate
      FROM items
      WHERE added_at >= '${range.startDate.toIso8601String()}'
      GROUP BY domain
      ORDER BY COUNT(*) DESC
      LIMIT $limit
    ''';

    final response = await _supabase.rpc('execute_query', params: {'query': query});
    return List<Map<String, dynamic>>.from(response ?? []);
  }

  /// Get streak information
  Future<Map<String, dynamic>> getStreakInfo() async {
    // Get daily completion counts for the last 90 days
    final query = '''
      SELECT 
        DATE_TRUNC('day', finished_at) as completion_date,
        COUNT(*) as completions
      FROM items
      WHERE status = 'completed'
        AND finished_at >= NOW() - INTERVAL '90 days'
      GROUP BY DATE_TRUNC('day', finished_at)
      ORDER BY completion_date DESC
    ''';

    final response = await _supabase.rpc('execute_query', params: {'query': query});
    final dailyCompletions = List<Map<String, dynamic>>.from(response ?? []);

    // Calculate current streak
    int currentStreak = 0;
    DateTime today = DateTime.now();
    DateTime checkDate = DateTime(today.year, today.month, today.day);

    for (int i = 0; i < dailyCompletions.length; i++) {
      final completionDate = DateTime.parse(dailyCompletions[i]['completion_date']);
      final completionDay = DateTime(completionDate.year, completionDate.month, completionDate.day);
      
      if (completionDay == checkDate) {
        currentStreak++;
        checkDate = checkDate.subtract(const Duration(days: 1));
      } else if (completionDay.isBefore(checkDate)) {
        break;
      }
    }

    // Calculate longest streak
    int longestStreak = 0;
    int tempStreak = 0;
    DateTime? lastDate;

    for (final completion in dailyCompletions.reversed) {
      final completionDate = DateTime.parse(completion['completion_date']);
      final completionDay = DateTime(completionDate.year, completionDate.month, completionDate.day);
      
      if (lastDate == null || completionDay == lastDate.subtract(const Duration(days: 1))) {
        tempStreak++;
        longestStreak = tempStreak > longestStreak ? tempStreak : longestStreak;
      } else {
        tempStreak = 1;
      }
      
      lastDate = completionDay;
    }

    return {
      'current_streak': currentStreak,
      'longest_streak': longestStreak,
      'daily_completions': dailyCompletions,
    };
  }
}
