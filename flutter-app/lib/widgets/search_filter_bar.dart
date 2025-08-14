import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/item.dart';
import '../models/tag.dart';
import '../providers/items_provider.dart';
import 'tag_widgets.dart';

class SearchAndFilterBar extends ConsumerStatefulWidget {
  final ContentType? autoContentType; // When set, content type is auto-managed and not user-editable
  
  const SearchAndFilterBar({
    super.key,
    this.autoContentType,
  });

  @override
  ConsumerState<SearchAndFilterBar> createState() => _SearchAndFilterBarState();
}

class _SearchAndFilterBarState extends ConsumerState<SearchAndFilterBar> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _isFiltersExpanded = false;

  @override
  void initState() {
    super.initState();
    // Initialize search controller with current search query
    final currentQuery = ref.read(searchQueryProvider);
    _searchController.text = currentQuery;
    
    // Listen to search input changes
    _searchController.addListener(() {
      ref.read(searchQueryProvider.notifier).state = _searchController.text;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedTags = ref.watch(selectedTagsProvider);
    final contentTypeFilter = ref.watch(contentTypeFilterProvider);
    final tagsAsync = ref.watch(tagsProvider);
    
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(0.1),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Enhanced search bar
            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: theme.colorScheme.outline.withOpacity(0.1),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      decoration: InputDecoration(
                        hintText: 'Search titles, descriptions, domains...',
                        hintStyle: TextStyle(
                          color: theme.colorScheme.onSurface.withOpacity(0.5),
                        ),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          color: theme.colorScheme.primary,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: Icon(
                                  Icons.clear_rounded,
                                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                                ),
                                onPressed: () {
                                  _searchController.clear();
                                  ref.read(searchQueryProvider.notifier).state = '';
                                },
                              )
                            : null,
                      ),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: _hasActiveFilters() 
                          ? theme.colorScheme.primary.withOpacity(0.1)
                          : theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _hasActiveFilters() 
                            ? theme.colorScheme.primary.withOpacity(0.3)
                            : theme.colorScheme.outline.withOpacity(0.1),
                      ),
                    ),
                    child: IconButton(
                      icon: Icon(
                        Icons.tune_rounded,
                        color: _hasActiveFilters() 
                            ? theme.colorScheme.primary 
                            : theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                      onPressed: () => setState(() => _isFiltersExpanded = !_isFiltersExpanded),
                      tooltip: 'Filters',
                    ),
                  ),
                ],
              ),
            ),
            
            // Active filters summary
            if (_hasActiveFilters() && !_isFiltersExpanded) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.filter_alt,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      _getActiveFiltersText(),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _clearAllFilters,
                    child: const Text('Clear'),
                  ),
                ],
              ),
            ],
            
            // Expanded filters
            if (_isFiltersExpanded) ...[
              const SizedBox(height: 16),
              _buildExpandedFilters(context, selectedTags, contentTypeFilter, tagsAsync),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildExpandedFilters(
    BuildContext context,
    List<String> selectedTags,
    ContentType? contentTypeFilter,
    AsyncValue<List<Tag>> tagsAsync,
  ) {
    final theme = Theme.of(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Content type filter - only show if not auto-managed
        if (widget.autoContentType == null) ...[
          Text(
            'Content Type',
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              FilterChip(
                label: const Text('Articles'),
                selected: contentTypeFilter == ContentType.article,
                onSelected: (selected) {
                  ref.read(contentTypeFilterProvider.notifier).state =
                      selected ? ContentType.article : null;
                },
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('Videos'),
                selected: contentTypeFilter == ContentType.video,
                onSelected: (selected) {
                  ref.read(contentTypeFilterProvider.notifier).state =
                      selected ? ContentType.video : null;
                },
              ),
              const Spacer(),
              if (contentTypeFilter != null)
                TextButton(
                  onPressed: () {
                    ref.read(contentTypeFilterProvider.notifier).state = null;
                  },
                  child: const Text('Clear'),
                ),
            ],
          ),
          const SizedBox(height: 16),
        ],
        
        // Tag filters
        Row(
          children: [
            Text(
              'Tags',
              style: theme.textTheme.titleSmall,
            ),
            const Spacer(),
            if (selectedTags.isNotEmpty)
              TextButton(
                onPressed: () {
                  ref.read(selectedTagsProvider.notifier).state = [];
                },
                child: const Text('Clear'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        
        tagsAsync.when(
          data: (allTags) {
            if (allTags.isEmpty) {
              return const Text('No tags available');
            }
            
            // Group by type
            final presetTags = allTags.where((t) => t.isPreset).toList();
            final customTags = allTags.where((t) => t.isCustom).toList();
            
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (presetTags.isNotEmpty) ...[
                  Text(
                    'Preset Tags',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: presetTags.map((tag) {
                      final isSelected = selectedTags.contains(tag.name);
                      return TagChip(
                        tag: tag,
                        isSelected: isSelected,
                        onTap: () => _toggleTagFilter(tag.name),
                        showUsageCount: true,
                      );
                    }).toList(),
                  ),
                  if (customTags.isNotEmpty) const SizedBox(height: 12),
                ],
                if (customTags.isNotEmpty) ...[
                  Text(
                    'Custom Tags',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: customTags.map((tag) {
                      final isSelected = selectedTags.contains(tag.name);
                      return TagChip(
                        tag: tag,
                        isSelected: isSelected,
                        onTap: () => _toggleTagFilter(tag.name),
                        showUsageCount: true,
                      );
                    }).toList(),
                  ),
                ],
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Text('Error loading tags: $error'),
        ),
        
        const SizedBox(height: 16),
        
        // Action buttons
        Row(
          children: [
            TextButton(
              onPressed: _clearAllFilters,
              child: const Text('Clear All'),
            ),
            const Spacer(),
            FilledButton(
              onPressed: () => setState(() => _isFiltersExpanded = false),
              child: const Text('Done'),
            ),
          ],
        ),
      ],
    );
  }

  void _toggleTagFilter(String tagName) {
    final current = ref.read(selectedTagsProvider);
    if (current.contains(tagName)) {
      ref.read(selectedTagsProvider.notifier).state =
          current.where((t) => t != tagName).toList();
    } else {
      ref.read(selectedTagsProvider.notifier).state = [...current, tagName];
    }
  }

  bool _hasActiveFilters() {
    final selectedTags = ref.read(selectedTagsProvider);
    final contentTypeFilter = ref.read(contentTypeFilterProvider);
    
    // Don't count auto content type as an active filter
    final hasContentFilter = contentTypeFilter != null && 
                             contentTypeFilter != widget.autoContentType;
    
    return selectedTags.isNotEmpty || hasContentFilter;
  }

  String _getActiveFiltersText() {
    final selectedTags = ref.read(selectedTagsProvider);
    final contentTypeFilter = ref.read(contentTypeFilterProvider);
    
    final parts = <String>[];
    
    // Don't show auto content type in active filters text
    if (contentTypeFilter != null && contentTypeFilter != widget.autoContentType) {
      parts.add(contentTypeFilter == ContentType.article ? 'Articles' : 'Videos');
    }
    
    if (selectedTags.isNotEmpty) {
      parts.add('${selectedTags.length} tag${selectedTags.length == 1 ? '' : 's'}');
    }
    
    return parts.join(' • ');
  }

  void _clearAllFilters() {
    ref.read(selectedTagsProvider.notifier).state = [];
    // Don't clear auto content type, only clear if it's user-set
    if (widget.autoContentType == null) {
      ref.read(contentTypeFilterProvider.notifier).state = null;
    }
  }
}
