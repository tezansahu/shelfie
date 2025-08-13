import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  static String get supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';
  static String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';
  static String get appName => dotenv.env['APP_NAME'] ?? 'Shelfie';
  static String get appVersion => dotenv.env['APP_VERSION'] ?? '1.0.0';
  static bool get debugMode => dotenv.env['DEBUG_MODE']?.toLowerCase() == 'true';
  static bool get enableAnalytics => dotenv.env['ENABLE_ANALYTICS']?.toLowerCase() != 'false';
  static bool get enableOfflineSync => dotenv.env['ENABLE_OFFLINE_SYNC']?.toLowerCase() != 'false';
  static bool get enableNotifications => dotenv.env['ENABLE_NOTIFICATIONS']?.toLowerCase() != 'false';

  static bool get isConfigured {
    return supabaseUrl.isNotEmpty && 
           supabaseAnonKey.isNotEmpty &&
           !supabaseUrl.contains('your-project-id') &&
           !supabaseAnonKey.contains('eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...');
  }

  static void logConfiguration() {
    if (debugMode) {
      print('=== Shelfie Configuration ===');
      print('App Name: $appName');
      print('App Version: $appVersion');
      print('Supabase URL: ${supabaseUrl.isEmpty ? '[NOT SET]' : '[CONFIGURED]'}');
      print('Supabase Key: ${supabaseAnonKey.isEmpty ? '[NOT SET]' : '[CONFIGURED]'}');
      print('Debug Mode: $debugMode');
      print('Analytics: $enableAnalytics');
      print('Offline Sync: $enableOfflineSync');
      print('Notifications: $enableNotifications');
      print('Is Configured: $isConfigured');
      print('=============================');
    }
  }
}
