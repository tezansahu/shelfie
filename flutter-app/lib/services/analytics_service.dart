import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/analytics_models.dart';

class AnalyticsService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Ensure user is authenticated before any analytics operation
  String get _currentUserId {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated. Please sign in to access analytics.');
    }
    return user.id;
  }

  /// Get analytics summary for the specified date range
  Future<AnalyticsSummary> getAnalyticsSummary({
    AnalyticsDateRange range = AnalyticsDateRange.days90,
  }) async {
    try {
      // Ensure user is authenticated
      final userId = _currentUserId;
      print('📊 Getting analytics for user: $userId');
      
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
      print('📊 Analytics response: $response');

      return AnalyticsSummary.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      print('❌ Analytics error details: $e');
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
    // Ensure user is authenticated
    final userId = _currentUserId;
    print('📊 Getting raw analytics for user: $userId');
    
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
    // Ensure user is authenticated
    final userId = _currentUserId;
    
    final query = _supabase
        .from('items')
        .select('id, status, content_type, finished_at, added_at')
        .eq('user_id', userId)
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
    // Ensure user is authenticated
    final userId = _currentUserId;
    
    // Use proper Supabase query builder instead of raw SQL
    final response = await _supabase
        .from('tags')
        .select('''
          name,
          type,
          item_tags!inner(
            items!inner(
              id,
              status,
              finished_at
            )
          )
        ''')
        .eq('user_id', userId)
        .eq('item_tags.items.status', 'completed')
        .gte('item_tags.items.finished_at', range.startDate.toIso8601String())
        .limit(limit);

    // Process the response to count completions
    final tagCounts = <String, Map<String, dynamic>>{};
    
    for (final tag in response) {
      final tagName = tag['name'] as String;
      final tagType = tag['type'] as String;
      final itemTags = tag['item_tags'] as List;
      
      tagCounts[tagName] = {
        'name': tagName,
        'type': tagType,
        'completion_count': itemTags.length,
      };
    }
    
    // Sort by completion count and return
    final sortedTags = tagCounts.values.toList()
      ..sort((a, b) => (b['completion_count'] as int).compareTo(a['completion_count'] as int));
    
    return sortedTags.take(limit).toList();
  }

  /// Get domain statistics
  Future<List<Map<String, dynamic>>> getDomainStats({
    AnalyticsDateRange range = AnalyticsDateRange.days90,
    int limit = 10,
  }) async {
    // Ensure user is authenticated
    final userId = _currentUserId;
    
    // Use proper Supabase query builder
    final response = await _supabase
        .from('items')
        .select('domain, status')
        .eq('user_id', userId)
        .gte('added_at', range.startDate.toIso8601String());

    // Process the data to calculate domain stats
    final domainStats = <String, Map<String, dynamic>>{};
    
    for (final item in response) {
      final domain = item['domain'] as String;
      final status = item['status'] as String;
      
      if (!domainStats.containsKey(domain)) {
        domainStats[domain] = {
          'domain': domain,
          'total_count': 0,
          'completed_count': 0,
        };
      }
      
      domainStats[domain]!['total_count']++;
      if (status == 'completed') {
        domainStats[domain]!['completed_count']++;
      }
    }
    
    // Calculate completion rates and sort
    final sortedDomains = domainStats.values.map((domain) {
      final totalCount = domain['total_count'] as int;
      final completedCount = domain['completed_count'] as int;
      final completionRate = totalCount > 0 ? (completedCount / totalCount * 100) : 0.0;
      
      return {
        ...domain,
        'completion_rate': completionRate.round(),
      };
    }).toList()
      ..sort((a, b) => (b['total_count'] as int).compareTo(a['total_count'] as int));
    
    return sortedDomains.take(limit).toList();
  }

  /// Get streak information
  Future<Map<String, dynamic>> getStreakInfo() async {
    // Ensure user is authenticated
    final userId = _currentUserId;
    
    // Get daily completion counts for the last 90 days
    final ninetyDaysAgo = DateTime.now().subtract(const Duration(days: 90));
    
    final response = await _supabase
        .from('items')
        .select('finished_at')
        .eq('user_id', userId)
        .eq('status', 'completed')
        .gte('finished_at', ninetyDaysAgo.toIso8601String())
        .order('finished_at', ascending: false);

    // Process completions by day
    final dailyCompletions = <String, int>{};
    
    for (final item in response) {
      final finishedAt = DateTime.parse(item['finished_at'] as String);
      final dayKey = DateTime(finishedAt.year, finishedAt.month, finishedAt.day).toIso8601String().split('T')[0];
      
      dailyCompletions[dayKey] = (dailyCompletions[dayKey] ?? 0) + 1;
    }

    // Calculate current streak
    int currentStreak = 0;
    DateTime checkDate = DateTime.now();
    
    while (true) {
      final dayKey = DateTime(checkDate.year, checkDate.month, checkDate.day).toIso8601String().split('T')[0];
      
      if (dailyCompletions.containsKey(dayKey)) {
        currentStreak++;
        checkDate = checkDate.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }

    // Calculate longest streak
    int longestStreak = 0;
    int tempStreak = 0;
    
    final sortedDays = dailyCompletions.keys.toList()..sort();
    DateTime? lastDate;
    
    for (final dayStr in sortedDays) {
      final currentDate = DateTime.parse(dayStr);
      
      if (lastDate == null || currentDate == lastDate.add(const Duration(days: 1))) {
        tempStreak++;
        longestStreak = tempStreak > longestStreak ? tempStreak : longestStreak;
      } else {
        tempStreak = 1;
      }
      
      lastDate = currentDate;
    }

    // Convert daily completions to the expected format
    final dailyCompletionsList = dailyCompletions.entries.map((entry) => {
      'completion_date': entry.key,
      'completions': entry.value,
    }).toList()
      ..sort((a, b) => (b['completion_date'] as String).compareTo(a['completion_date'] as String));

    return {
      'current_streak': currentStreak,
      'longest_streak': longestStreak,
      'daily_completions': dailyCompletionsList,
    };
  }
}
