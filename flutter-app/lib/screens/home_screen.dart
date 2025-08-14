import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/item.dart';
import '../providers/items_provider.dart';
import '../widgets/item_card.dart';
import '../widgets/add_item_dialog.dart';
import '../widgets/search_filter_bar.dart';
import 'analytics_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Shelfie',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.article), text: 'Reading'),
            Tab(icon: Icon(Icons.video_library), text: 'Viewing'),
            Tab(icon: Icon(Icons.archive), text: 'Archive'),
            Tab(icon: Icon(Icons.analytics), text: 'Analytics'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddItemDialog(context),
            tooltip: 'Add URL',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _refreshData(),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Reading Tab (Articles)
          ItemsListWithSearch(
            provider: unreadArticlesProvider,
            emptyMessage: 'No articles to read',
            emptyIcon: Icons.article,
            contentType: ContentType.article,
          ),
          // Viewing Tab (Videos)
          ItemsListWithSearch(
            provider: unreadVideosProvider,
            emptyMessage: 'No videos to watch',
            emptyIcon: Icons.video_library,
            contentType: ContentType.video,
          ),
          // Archive Tab
          ItemsListWithSearch(
            provider: archivedItemsProvider,
            emptyMessage: 'No completed items',
            emptyIcon: Icons.archive,
            isArchive: true,
          ),
          // Analytics Tab
          const AnalyticsScreen(),
        ],
      ),
    );
  }

  void _showAddItemDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const AddItemDialog(),
    );
  }

  void _refreshData() {
    ref.invalidate(unreadArticlesProvider);
    ref.invalidate(unreadVideosProvider);
    ref.invalidate(archivedItemsProvider);
  }
}

class ItemsList extends ConsumerWidget {
  final FutureProvider<List<Item>> provider;
  final String emptyMessage;
  final IconData emptyIcon;
  final bool isArchive;

  const ItemsList({
    super.key,
    required this.provider,
    required this.emptyMessage,
    required this.emptyIcon,
    this.isArchive = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(provider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(provider);
        await ref.read(provider.future);
      },
      child: itemsAsync.when(
        data: (items) {
          if (items.isEmpty) {
            return _buildEmptyState(context);
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ItemCard(
                  item: item,
                  isArchive: isArchive,
                ),
              );
            },
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Error loading items',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(provider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            emptyIcon,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            emptyMessage,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            isArchive
                ? 'Items you mark as completed will appear here'
                : 'Add some URLs to get started!',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class ItemsListWithSearch extends ConsumerWidget {
  final FutureProvider<List<Item>>? provider;
  final String emptyMessage;
  final IconData emptyIcon;
  final bool isArchive;
  final ContentType? contentType;

  const ItemsListWithSearch({
    super.key,
    this.provider,
    required this.emptyMessage,
    required this.emptyIcon,
    this.isArchive = false,
    this.contentType,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Automatically set content type filter based on the tab
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentFilter = ref.read(contentTypeFilterProvider);
      if (contentType != null) {
        // Set the content type for specific tabs (Reading/Viewing)
        if (currentFilter != contentType) {
          ref.read(contentTypeFilterProvider.notifier).state = contentType;
        }
      } else {
        // Clear content type filter for Archive tab to allow both types
        if (currentFilter != null) {
          ref.read(contentTypeFilterProvider.notifier).state = null;
        }
      }
    });

    return Column(
      children: [
        // Search and Filter Bar - pass contentType to hide content type filter
        SearchAndFilterBar(autoContentType: contentType),
        
        // Items List
        Expanded(
          child: _buildItemsList(context, ref),
        ),
      ],
    );
  }

  Widget _buildItemsList(BuildContext context, WidgetRef ref) {
    // Check if search is active
    final searchQuery = ref.watch(searchQueryProvider);
    final selectedTags = ref.watch(selectedTagsProvider);
    final isSearchActive = searchQuery.isNotEmpty || selectedTags.isNotEmpty;

    if (isSearchActive) {
      // Use search results - need to build search query
      final query = searchQuery.isEmpty ? '*' : searchQuery;
      final searchResults = ref.watch(searchResultsProvider(query));
      return _buildSearchResults(context, ref, searchResults, query);
    } else {
      // Use regular provider
      if (provider == null) return const SizedBox.shrink();
      final itemsAsync = ref.watch(provider!);
      return _buildRegularResults(context, ref, itemsAsync);
    }
  }

  Widget _buildSearchResults(BuildContext context, WidgetRef ref, AsyncValue<List<Item>> searchResults, String query) {
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(searchResultsProvider(query));
        await ref.read(searchResultsProvider(query).future);
      },
      child: searchResults.when(
        data: (items) => _buildItemsGrid(context, items),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _buildErrorState(context, ref, () {
          ref.invalidate(searchResultsProvider(query));
        }),
      ),
    );
  }

  Widget _buildRegularResults(BuildContext context, WidgetRef ref, AsyncValue<List<Item>> itemsAsync) {
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(provider!);
        await ref.read(provider!.future);
      },
      child: itemsAsync.when(
        data: (items) => _buildItemsGrid(context, items),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _buildErrorState(context, ref, () {
          ref.invalidate(provider!);
        }),
      ),
    );
  }

  Widget _buildItemsGrid(BuildContext context, List<Item> items) {
    if (items.isEmpty) {
      return _buildEmptyState(context);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: ItemCard(
            item: item,
            isArchive: isArchive,
          ),
        );
      },
    );
  }

  Widget _buildErrorState(BuildContext context, WidgetRef ref, VoidCallback onRetry) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            'Error loading items',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onRetry,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            emptyIcon,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            emptyMessage,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            isArchive
                ? 'Items you mark as completed will appear here'
                : 'Add some URLs to get started!',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
