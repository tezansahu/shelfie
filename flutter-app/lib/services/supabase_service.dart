import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/item.dart';
import '../models/tag.dart';

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

  /// Ensure user is authenticated before any operation
  String get _currentUserId {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated. Please sign in to access your items.');
    }
    return user.id;
  }

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

  // Convert database data with tags to model format
  Map<String, dynamic> _convertToModelFormatWithTags(Map<String, dynamic> dbData) {
    final baseData = _convertToModelFormat(dbData);
    
    // Handle tags field from the view
    final tagsJson = dbData['tags'];
    List<Map<String, dynamic>> tags = [];
    
    if (tagsJson != null) {
      if (tagsJson is List) {
        tags = tagsJson.map((tag) {
          final tagMap = Map<String, dynamic>.from(tag as Map);
          // Ensure all required fields are present for Tag.fromJson()
          return {
            'id': tagMap['id']?.toString() ?? '',
            'name': tagMap['name']?.toString() ?? '',
            'type': tagMap['type']?.toString() ?? 'custom',
            'usageCount': tagMap['usage_count'] ?? 0,
            'createdAt': DateTime.now().toIso8601String(),
            'updatedAt': DateTime.now().toIso8601String(),
          };
        }).toList();
      } else if (tagsJson is String) {
        // Parse JSON string if needed
        try {
          final decoded = json.decode(tagsJson);
          if (decoded is List) {
            tags = decoded.map((tag) {
              final tagMap = Map<String, dynamic>.from(tag as Map);
              return {
                'id': tagMap['id']?.toString() ?? '',
                'name': tagMap['name']?.toString() ?? '',
                'type': tagMap['type']?.toString() ?? 'custom',
                'usageCount': tagMap['usage_count'] ?? 0,
                'createdAt': DateTime.now().toIso8601String(),
                'updatedAt': DateTime.now().toIso8601String(),
              };
            }).toList();
          }
        } catch (e) {
          print('❌ Error parsing tags JSON: $e');
        }
      }
    }
    
    baseData['tags'] = tags;
    return baseData;
  }

  // Get unread items (Reading + Viewing lists)
  Future<List<Item>> getUnreadItems({
    ContentType? contentType,
    int limit = 30,
    int offset = 0,
  }) async {
    try {
      // Ensure user is authenticated
      final userId = _currentUserId;
      
      // Use the view that includes tags with explicit user filtering as backup
      var query = _client
          .from('unread_items_with_tags_v')
          .select();

      if (contentType != null) {
        query = query.eq('content_type', contentType.value);
      }

      final response = await query
          .order('added_at', ascending: false)
          .range(offset, offset + limit - 1);
          
      print('📱 Database response for user $userId: $response');
      print('📱 Response type: ${response.runtimeType}');
      
      final items = response.map((json) {
        print('📱 Processing item: $json');
        final itemData = Map<String, dynamic>.from(json as Map);
        final convertedJson = _convertToModelFormatWithTags(itemData);
        print('📱 Converted item: $convertedJson');
        return Item.fromJson(convertedJson);
      }).toList();
      
      print('📱 Retrieved ${items.length} unread items for user $userId');
      return items;
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
      // Ensure user is authenticated
      final userId = _currentUserId;
      
      // Use the view that includes tags - RLS will automatically filter by user
      final response = await _client
          .from('archive_items_with_tags_v')
          .select()
          .order('finished_at', ascending: false)
          .range(offset, offset + limit - 1);

      final items = response.map((json) {
        final itemData = Map<String, dynamic>.from(json as Map);
        final convertedJson = _convertToModelFormatWithTags(itemData);
        return Item.fromJson(convertedJson);
      }).toList();
      
      print('📱 Retrieved ${items.length} archived items for user $userId');
      return items;
    } catch (error) {
      print('❌ Error in getArchivedItems: $error');
      rethrow;
    }
  }

  // Update item status
  Future<Item> updateItemStatus(String itemId, ItemStatus status) async {
    try {
      // Ensure user is authenticated
      final userId = _currentUserId;
      
      // RLS will ensure user can only update their own items
      final response = await _client
          .from('items')
          .update({'status': status.value})
          .eq('id', itemId)
          .select()
          .single();

      final convertedJson = _convertToModelFormat(response);
      print('📱 Updated item status for user $userId: $itemId -> ${status.value}');
      return Item.fromJson(convertedJson);
    } catch (error) {
      print('❌ Error in updateItemStatus: $error');
      rethrow;
    }
  }

  // Update item fields (title / description)
  Future<Item> updateItem(String itemId, {String? title, String? description}) async {
    try {
      // Ensure user is authenticated
      final userId = _currentUserId;
      
      final updateMap = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (title != null) updateMap['title'] = title;
      if (description != null) updateMap['description'] = description;

      // RLS will ensure user can only update their own items
      final response = await _client
          .from('items')
          .update(updateMap)
          .eq('id', itemId)
          .select()
          .single();

      final convertedJson = _convertToModelFormat(response);
      print('📱 Updated item for user $userId: $itemId');
      return Item.fromJson(convertedJson);
    } catch (error) {
      print('❌ Error in updateItem: $error');
      rethrow;
    }
  }

  // Delete item
  Future<void> deleteItem(String itemId) async {
    try {
      // Ensure user is authenticated
      final userId = _currentUserId;
      
      print('🗑️ Deleting item for user $userId: $itemId');
      
      // RLS will ensure user can only delete their own items
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
      // Ensure user is authenticated
      final userId = _currentUserId;
      
      print('📝 Adding URL via Edge Function for user $userId: $url');
      
      // Call the Edge Function to process the URL
      // The function will automatically set user_id based on authenticated user
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

      // Handle dynamic map properly
      final rawData = response.data as Map<dynamic, dynamic>;
      final data = Map<String, dynamic>.from(rawData);
      print('📱 Raw response data: $data');
      
      final convertedJson = _convertToModelFormat(data);
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

  // PHASE 2: Tags and Search Methods

  // Get all tags (preset + custom)
  Future<List<Tag>> getAllTags() async {
    try {
      print('🏷️ Calling get_all_tags...');
      // Call without user_id to get all preset tags and global tags
      final response = await _client.rpc('get_all_tags');
      
      print('🏷️ Raw response: $response');
      print('🏷️ Response type: ${response.runtimeType}');
      
      if (response != null) {
        return (response as List).map((json) {
          print('🏷️ Processing tag: $json');
          print('🏷️ Tag type: ${json.runtimeType}');
          
          // Handle potential null values safely
          final jsonMap = Map<String, dynamic>.from(json as Map);
          print('🏷️ Converted jsonMap: $jsonMap');
          
          // Convert the database response to the correct format for Tag.fromJson
          final tagData = {
            'id': jsonMap['id']?.toString() ?? '',
            'name': jsonMap['name']?.toString() ?? '',
            'type': jsonMap['type']?.toString() ?? 'custom', // This will be converted to TagType enum
            'usageCount': jsonMap['usage_count'] ?? 0,
            'createdAt': DateTime.now().toIso8601String(),
            'updatedAt': DateTime.now().toIso8601String(),
          };
          
          print('🏷️ Final tagData: $tagData');
          return Tag.fromJson(tagData);
        }).toList();
      }
      return [];
    } catch (error) {
      print('❌ Error in getAllTags: $error');
      rethrow;
    }
  }

  // Add tag to item
  Future<String> addTagToItem(String itemId, String tagName) async {
    try {
      final response = await _client.rpc('add_tag_to_item', params: {
        'item_id_param': itemId,
        'tag_name_param': tagName,
        // Note: Without user auth, this will create tags without user_id (global tags)
      });
      return response as String;
    } catch (error) {
      print('❌ Error in addTagToItem: $error');
      rethrow;
    }
  }

  // Remove tag from item
  Future<bool> removeTagFromItem(String itemId, String tagId) async {
    try {
      final response = await _client.rpc('remove_tag_from_item', params: {
        'item_id_param': itemId,
        'tag_id_param': tagId,
      });
      return response as bool;
    } catch (error) {
      print('❌ Error in removeTagFromItem: $error');
      rethrow;
    }
  }

  // Search items with filters
  Future<List<Item>> searchItems({
    String searchQuery = '',
    List<String> tagNames = const [],
    ContentType? contentType,
    ItemStatus? status,
    int limit = 30,
    int offset = 0,
  }) async {
    try {
      final response = await _client.rpc('search_items', params: {
        'search_query': searchQuery,
        'tag_names': tagNames,
        'content_type_filter': contentType?.value,
        'status_filter': status?.value ?? 'unread',
        'limit_count': limit,
        'offset_count': offset,
      });

      print('🔍 Search response: $response');
      print('🔍 Response type: ${response.runtimeType}');

      if (response != null && response is List) {
        return response.map((json) {
          print('🔍 Processing search result: ${json.runtimeType}');
          
          // Convert to proper map type
          final itemData = Map<String, dynamic>.from(json as Map);
          final convertedJson = _convertToModelFormatWithTags(itemData);
          
          return Item.fromJson(convertedJson);
        }).toList();
      }
      return [];
    } catch (error) {
      print('❌ Error in searchItems: $error');
      rethrow;
    }
  }

  // Add item manually using Edge Function
  Future<Item> addItemManual(String url) async {
    try {
      print('📝 Adding item manually: $url');
      
      final response = await _client.functions.invoke(
        'add-item-manual',
        body: {'url': url},
      );

      if (response.data != null) {
        print('✅ Manual add response: ${response.data}');
        print('✅ Response data type: ${response.data.runtimeType}');
        
        // Convert response to Item format - handle dynamic map properly
        final rawData = response.data;
        print('🔍 rawData type: ${rawData.runtimeType}');
        
        final data = Map<String, dynamic>.from(rawData as Map);
        print('🔍 converted data: $data');
        
        final itemData = {
          'id': data['id'],
          'user_id': null, // Add this field that's expected by _convertToModelFormat
          'url': url,
          'canonical_url': url, // Add this field
          'domain': data['domain'],
          'title': data['title'],
          'description': data['description'],
          'image_url': data['image_url'],
          'content_type': data['content_type'],
          'status': data['status'],
          'added_at': data['added_at'],
          'finished_at': null, // Add this field
          'source_client': 'app_manual',
          'source_platform': 'flutter_app',
          'notes': null, // Add this field
          'metadata': <String, dynamic>{}, // Ensure this is the right type
          'created_at': data['added_at'],
          'updated_at': data['added_at'],
        };

        print('🔍 itemData: $itemData');
        
        final convertedJson = _convertToModelFormat(itemData);
        print('🔍 convertedJson: $convertedJson');
        
        // Add tags field for the Item model
        convertedJson['tags'] = <Map<String, dynamic>>[];
        
        return Item.fromJson(convertedJson);
      }
      
      throw Exception('No response data received');
    } catch (error) {
      print('❌ Error in addItemManual: $error');
      rethrow;
    }
  }

  // Migration method to assign orphaned items to current user
  Future<void> migrateOrphanedItemsToCurrentUser() async {
    try {
      final userId = _currentUserId;
      print('🔄 Migrating orphaned items to user: $userId');
      
      await _client.rpc('migrate_orphaned_items_to_current_user');
      
      print('✅ Successfully migrated orphaned items to current user');
    } catch (error) {
      print('❌ Error migrating orphaned items: $error');
      rethrow;
    }
  }
}
