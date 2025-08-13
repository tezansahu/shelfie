import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/item.dart';
import '../services/supabase_service.dart';

// Items service provider
final itemsServiceProvider = Provider<ItemsService>((ref) {
  return ItemsService();
});

// Unread items providers
final unreadArticlesProvider = FutureProvider<List<Item>>((ref) async {
  final service = ref.read(itemsServiceProvider);
  return service.getUnreadItems(contentType: ContentType.article);
});

final unreadVideosProvider = FutureProvider<List<Item>>((ref) async {
  final service = ref.read(itemsServiceProvider);
  return service.getUnreadItems(contentType: ContentType.video);
});

// All unread items
final allUnreadItemsProvider = FutureProvider<List<Item>>((ref) async {
  final service = ref.read(itemsServiceProvider);
  return service.getUnreadItems();
});

// Archived items provider
final archivedItemsProvider = FutureProvider<List<Item>>((ref) async {
  final service = ref.read(itemsServiceProvider);
  return service.getArchivedItems();
});

// Item actions provider
final itemActionsProvider = Provider<ItemActions>((ref) {
  return ItemActions(ref);
});

class ItemActions {
  final Ref _ref;
  
  ItemActions(this._ref);

  Future<void> markAsCompleted(String itemId) async {
    final service = _ref.read(itemsServiceProvider);
    await service.updateItemStatus(itemId, ItemStatus.completed);
    
    // Refresh the relevant providers
    _ref.invalidate(allUnreadItemsProvider);
    _ref.invalidate(unreadArticlesProvider);
    _ref.invalidate(unreadVideosProvider);
    _ref.invalidate(archivedItemsProvider);
  }

  Future<void> markAsUnread(String itemId) async {
    final service = _ref.read(itemsServiceProvider);
    await service.updateItemStatus(itemId, ItemStatus.unread);
    
    // Refresh the relevant providers
    _ref.invalidate(allUnreadItemsProvider);
    _ref.invalidate(unreadArticlesProvider);
    _ref.invalidate(unreadVideosProvider);
    _ref.invalidate(archivedItemsProvider);
  }

  Future<void> deleteItem(String itemId) async {
    print('🗑️ Provider: Starting delete for item: $itemId');
    final service = _ref.read(itemsServiceProvider);
    await service.deleteItem(itemId);
    
    print('🔄 Provider: Refreshing all item lists after delete');
    // Refresh all item providers
    _ref.invalidate(allUnreadItemsProvider);
    _ref.invalidate(unreadArticlesProvider);
    _ref.invalidate(unreadVideosProvider);
    _ref.invalidate(archivedItemsProvider);
    print('✅ Provider: All providers refreshed');
  }

  Future<Item> addItem(String url) async {
    print('📝 Provider: Starting add item for URL: $url');
    final service = _ref.read(itemsServiceProvider);
    final item = await service.addItem(url);
    
    print('🔄 Provider: Refreshing relevant lists after add');
    // Refresh the relevant providers
    _ref.invalidate(allUnreadItemsProvider);
    if (item.contentType == ContentType.article) {
      _ref.invalidate(unreadArticlesProvider);
      print('📖 Provider: Refreshed article list');
    } else {
      _ref.invalidate(unreadVideosProvider);
      print('🎥 Provider: Refreshed video list');
    }
    
    print('✅ Provider: Item added and providers refreshed');
    return item;
  }
}
