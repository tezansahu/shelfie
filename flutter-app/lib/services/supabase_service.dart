import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/item.dart';

class SupabaseService {
  static SupabaseService? _instance;
  static SupabaseService get instance => _instance ??= SupabaseService._();
  
  SupabaseService._();
  
  SupabaseClient get client => Supabase.instance.client;
  
  static Future<void> initialize({
    required String url,
    required String anonKey,
  }) async {
    await Supabase.initialize(
      url: url,
      anonKey: anonKey,
    );
  }
}

class ItemsService {
  final SupabaseClient _client = SupabaseService.instance.client;

  // Convert database snake_case to camelCase for model
  Map<String, dynamic> _convertToModelFormat(Map<String, dynamic> dbData) {
    return {
      'id': dbData['id'],
      'userId': dbData['user_id'],
      'url': dbData['url'] ?? '',
      'canonicalUrl': dbData['canonical_url'],
      'domain': dbData['domain'] ?? '',
      'title': dbData['title'] ?? '',
      'description': dbData['description'],
      'imageUrl': dbData['image_url'],
      'contentType': dbData['content_type'] ?? 'article',
      'status': dbData['status'] ?? 'unread',
      'addedAt': dbData['added_at'],
      'finishedAt': dbData['finished_at'],
      'sourceClient': dbData['source_client'] ?? 'unknown',
      'sourcePlatform': dbData['source_platform'] ?? 'unknown',
      'notes': dbData['notes'],
      'metadata': dbData['metadata'] ?? {},
      'createdAt': dbData['created_at'],
      'updatedAt': dbData['updated_at'],
    };
  }

  // Get unread items (Reading + Viewing lists)
  Future<List<Item>> getUnreadItems({
    ContentType? contentType,
    int limit = 30,
    int offset = 0,
  }) async {
    try {
      var query = _client
          .from('items')
          .select()
          .eq('status', 'unread');

      if (contentType != null) {
        query = query.eq('content_type', contentType.value);
      }

      final response = await query
          .order('added_at', ascending: false)
          .range(offset, offset + limit - 1);
          
      print('📱 Database response: $response');
      print('📱 Response type: ${response.runtimeType}');
      
      if (response is List) {
        return response.map((json) {
          print('📱 Processing item: $json');
          final convertedJson = _convertToModelFormat(json as Map<String, dynamic>);
          print('📱 Converted item: $convertedJson');
          return Item.fromJson(convertedJson);
        }).toList();
      } else {
        print('❌ Unexpected response type: ${response.runtimeType}');
        return [];
      }
    } catch (error, stackTrace) {
      print('❌ Error in getUnreadItems: $error');
      print('📱 Stack trace: $stackTrace');
      rethrow;
    }
  }

  // Get archived/completed items
  Future<List<Item>> getArchivedItems({
    int limit = 30,
    int offset = 0,
  }) async {
    try {
      final response = await _client
          .from('items')
          .select()
          .eq('status', 'completed')
          .order('finished_at', ascending: false)
          .range(offset, offset + limit - 1);

      return response.map((json) {
        final convertedJson = _convertToModelFormat(json);
        return Item.fromJson(convertedJson);
      }).toList();
    } catch (error) {
      print('❌ Error in getArchivedItems: $error');
      rethrow;
    }
  }

  // Update item status
  Future<Item> updateItemStatus(String itemId, ItemStatus status) async {
    try {
      final response = await _client
          .from('items')
          .update({'status': status.value})
          .eq('id', itemId)
          .select()
          .single();

      final convertedJson = _convertToModelFormat(response);
      return Item.fromJson(convertedJson);
    } catch (error) {
      print('❌ Error in updateItemStatus: $error');
      rethrow;
    }
  }

  // Delete item
  Future<void> deleteItem(String itemId) async {
    try {
      print('🗑️ Deleting item: $itemId');
      await _client.from('items').delete().eq('id', itemId);
      print('✅ Item deleted successfully');
    } catch (error) {
      print('❌ Error in deleteItem: $error');
      rethrow;
    }
  }

  // Add item manually (from app)
  Future<Item> addItem(String url) async {
    try {
      print('📝 Adding URL via Edge Function: $url');
      
      // Call the Edge Function to process the URL
      final response = await _client.functions.invoke(
        'save-url',
        body: {
          'url': url,
          'source_client': 'app_manual',
          'source_platform': _getPlatform(),
        },
      );

      print('📱 Edge Function response: ${response.data}');
      print('📱 Response status: ${response.status}');

      if (response.data == null) {
        throw Exception('Failed to add item - no data returned');
      }

      final rawData = response.data as Map<String, dynamic>;
      print('📱 Raw response data: $rawData');
      
      final convertedJson = _convertToModelFormat(rawData);
      print('📱 Converted JSON: $convertedJson');
      
      final item = Item.fromJson(convertedJson);
      print('✅ Successfully created Item: ${item.displayTitle}');
      
      return item;
    } catch (error, stackTrace) {
      print('❌ Error in addItem: $error');
      print('📱 Stack trace: $stackTrace');
      rethrow;
    }
  }

  // Get single item by ID
  Future<Item?> getItem(String itemId) async {
    try {
      final response = await _client
          .from('items')
          .select()
          .eq('id', itemId)
          .maybeSingle();

      if (response != null) {
        final convertedJson = _convertToModelFormat(response);
        return Item.fromJson(convertedJson);
      }
      return null;
    } catch (error) {
      print('❌ Error in getItem: $error');
      rethrow;
    }
  }

  String _getPlatform() {
    // Detect platform
    try {
      if (const bool.hasEnvironment('dart.library.io')) {
        // Mobile or Desktop
        return 'flutter_app';
      }
      return 'web';
    } catch (e) {
      return 'unknown';
    }
  }
}
