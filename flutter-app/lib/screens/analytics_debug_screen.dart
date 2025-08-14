import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AnalyticsDebugScreen extends ConsumerWidget {
  const AnalyticsDebugScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics Debug'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ElevatedButton(
              onPressed: () => _testBasicConnection(context),
              child: const Text('Test Basic Connection'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _testItemsQuery(context),
              child: const Text('Test Items Query'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _testSimpleAnalytics(context),
              child: const Text('Test Simple Analytics'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _testFullAnalytics(context),
              child: const Text('Test Full Analytics'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _testBasicConnection(BuildContext context) async {
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase.from('items').select('count').limit(1);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Connection OK: $response')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Connection Error: $e')),
        );
      }
    }
  }

  Future<void> _testItemsQuery(BuildContext context) async {
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase.from('items').select('id, title, status').limit(5);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Items Query OK: ${response.length} items')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Items Query Error: $e')),
        );
      }
    }
  }

  Future<void> _testSimpleAnalytics(BuildContext context) async {
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase.rpc('analytics_summary_simple');
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Simple Analytics OK: ${response.toString().substring(0, 100)}...')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Simple Analytics Error: $e')),
        );
      }
    }
  }

  Future<void> _testFullAnalytics(BuildContext context) async {
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase.rpc('analytics_summary', params: {
        'since': DateTime.now().subtract(const Duration(days: 90)).toIso8601String(),
      });
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Full Analytics OK: ${response.toString().substring(0, 100)}...')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Full Analytics Error: $e')),
        );
      }
    }
  }
}
