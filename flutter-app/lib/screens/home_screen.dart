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
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.primary.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.library_books,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text('Shelfie'),
          ],
        ),
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TabBar(
              controller: _tabController,
              dividerColor: Colors.transparent,
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: theme.colorScheme.primary,
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.primary.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              labelColor: Colors.white,
              unselectedLabelColor: theme.colorScheme.onSurface.withOpacity(0.7),
              labelStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              tabs: [
                _buildModernTab(Icons.article_outlined, 'Reading', theme),
                _buildModernTab(Icons.video_library_outlined, 'Viewing', theme),
                _buildModernTab(Icons.archive_outlined, 'Archive', theme),
                _buildModernTab(Icons.analytics_outlined, 'Analytics', theme),
              ],
            ),
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: Row(
              children: [
                _buildModernActionButton(
                  context,
                  icon: Icons.add_rounded,
                  onPressed: () => _showAddItemDialog(context),
                  tooltip: 'Add URL',
                ),
                const SizedBox(width: 8),
                _buildModernActionButton(
                  context,
                  icon: Icons.refresh_rounded,
                  onPressed: () => _refreshData(),
                  tooltip: 'Refresh',
                ),
              ],
            ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              theme.colorScheme.background,
              theme.colorScheme.surface,
            ],
          ),
        ),
        child: TabBarView(
          controller: _tabController,
          children: [
            // Reading Tab (Articles)
            _buildModernTabContent(
              ItemsListWithSearch(
                provider: unreadArticlesProvider,
                emptyMessage: 'No articles to read',
                emptyIcon: Icons.article_outlined,
                contentType: ContentType.article,
              ),
            ),
            // Viewing Tab (Videos)
            _buildModernTabContent(
              ItemsListWithSearch(
                provider: unreadVideosProvider,
                emptyMessage: 'No videos to watch',
                emptyIcon: Icons.video_library_outlined,
                contentType: ContentType.video,
              ),
            ),
            // Archive Tab
            _buildModernTabContent(
              ItemsListWithSearch(
                provider: archivedItemsProvider,
                emptyMessage: 'No completed items',
                emptyIcon: Icons.archive_outlined,
                isArchive: true,
              ),
            ),
            // Analytics Tab
            _buildModernTabContent(const AnalyticsScreen()),
          ],
        ),
      ),
    );
  }

  Widget _buildModernTab(IconData icon, String text, ThemeData theme) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // On mobile screens, show icon only to save space
          final isMobile = MediaQuery.of(context).size.width < 600;
          
          if (isMobile) {
            return Tooltip(
              message: text,
              child: Icon(icon, size: 20),
            );
          }
          
          // On larger screens, show both icon and text
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18),
              const SizedBox(width: 6),
              Text(text),
            ],
          );
        },
      ),
    );
  }

  Widget _buildModernTabContent(Widget child) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      child: child,
    );
  }

  Widget _buildModernActionButton(
    BuildContext context, {
    required IconData icon,
    required VoidCallback onPressed,
    required String tooltip,
  }) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(0.2),
        ),
      ),
      child: IconButton(
        icon: Icon(icon, color: theme.colorScheme.primary),
        onPressed: onPressed,
        tooltip: tooltip,
        padding: const EdgeInsets.all(8),
        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
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
