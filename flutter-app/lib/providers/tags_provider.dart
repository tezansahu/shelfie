import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/tag.dart';
import '../services/supabase_service.dart';

// Provider for the Items service
final itemsServiceProvider = Provider<ItemsService>((ref) {
  return ItemsService();
});

// Provider for all available tags
final tagsProvider = StateNotifierProvider<TagsNotifier, AsyncValue<List<Tag>>>((ref) {
  final service = ref.watch(itemsServiceProvider);
  return TagsNotifier(service);
});

// Provider for selected tag filters
final selectedTagsProvider = StateProvider<List<String>>((ref) => []);

// Provider for search query
final searchQueryProvider = StateProvider<String>((ref) => '');

class TagsNotifier extends StateNotifier<AsyncValue<List<Tag>>> {
  final ItemsService _service;

  TagsNotifier(this._service) : super(const AsyncValue.loading()) {
    loadTags();
  }

  Future<void> loadTags() async {
    state = const AsyncValue.loading();
    try {
      final tags = await _service.getAllTags();
      state = AsyncValue.data(tags);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> addTagToItem(String itemId, String tagName) async {
    try {
      await _service.addTagToItem(itemId, tagName);
      // Reload tags to update usage counts
      await loadTags();
    } catch (error) {
      // Handle error - could emit a notification
      print('❌ Failed to add tag: $error');
      rethrow;
    }
  }

  Future<void> removeTagFromItem(String itemId, String tagId) async {
    try {
      await _service.removeTagFromItem(itemId, tagId);
      // Reload tags to update usage counts
      await loadTags();
    } catch (error) {
      // Handle error - could emit a notification
      print('❌ Failed to remove tag: $error');
      rethrow;
    }
  }

  List<Tag> getPresetTags() {
    return state.when(
      data: (tags) => tags.where((tag) => tag.isPreset).toList(),
      loading: () => [],
      error: (_, __) => [],
    );
  }

  List<Tag> getCustomTags() {
    return state.when(
      data: (tags) => tags.where((tag) => tag.isCustom).toList(),
      loading: () => [],
      error: (_, __) => [],
    );
  }

  List<Tag> searchTags(String query) {
    if (query.isEmpty) return [];
    
    return state.when(
      data: (tags) => tags
          .where((tag) => tag.name.toLowerCase().contains(query.toLowerCase()))
          .toList(),
      loading: () => [],
      error: (_, __) => [],
    );
  }
}
