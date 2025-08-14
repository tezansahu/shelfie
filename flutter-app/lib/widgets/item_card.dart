import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../models/item.dart';
import '../providers/items_provider.dart';
import 'tag_widgets.dart';

class ItemCard extends ConsumerWidget {
  final Item item;
  final bool isArchive;

  const ItemCard({
    super.key,
    required this.item,
    this.isArchive = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: () => _openUrl(item.url),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with image and title
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Thumbnail
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                      width: 80,
                      height: 60,
                      child: CachedNetworkImage(
                        imageUrl: item.fallbackImageUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: theme.colorScheme.surfaceContainerHighest,
                          child: Icon(
                            item.isVideo ? Icons.play_arrow : Icons.article,
                            color: theme.colorScheme.outline,
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: theme.colorScheme.surfaceContainerHighest,
                          child: Icon(
                            item.isVideo ? Icons.play_arrow : Icons.article,
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  
                  // Title and metadata
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title
                        Text(
                          item.displayTitle,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        
                        // Domain and date
                        Row(
                          children: [
                            Icon(
                              item.isVideo ? Icons.play_circle : Icons.article,
                              size: 16,
                              color: theme.colorScheme.outline,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              item.domain,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.outline,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '•',
                              style: TextStyle(
                                color: theme.colorScheme.outline,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isArchive && item.finishedAt != null
                                  ? timeago.format(item.finishedAt!)
                                  : timeago.format(item.addedAt),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.outline,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              // Description (if available)
              if (item.description != null && item.description!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  item.description!,
                  style: theme.textTheme.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              
              // Tags (if available)
              if (item.tags.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: item.tags.map((tag) => TagChip(
                    tag: tag,
                    onTap: () => _onTagTapped(context, ref, tag),
                    showUsageCount: false,
                  )).toList(),
                ),
              ],
              
              // Actions
              const SizedBox(height: 12),
              Row(
                children: [
                  // Complete/Uncomplete button
                  if (!isArchive)
                    TextButton.icon(
                      onPressed: () => _markAsCompleted(context, ref),
                      icon: const Icon(Icons.check_circle, size: 18),
                      label: Text(item.isVideo ? 'Mark as Watched' : 'Mark as Read'),
                      style: TextButton.styleFrom(
                        foregroundColor: theme.colorScheme.primary,
                      ),
                    )
                  else
                    TextButton.icon(
                      onPressed: () => _markAsUnread(context, ref),
                      icon: const Icon(Icons.undo, size: 18),
                      label: const Text('Restore'),
                      style: TextButton.styleFrom(
                        foregroundColor: theme.colorScheme.secondary,
                      ),
                    ),
                  
                  const Spacer(),
                  
                  // Open button
                  TextButton.icon(
                    onPressed: () => _openUrl(item.url),
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: const Text('Open'),
                  ),
                  
                  // Tag management button
                  IconButton(
                    onPressed: () => _showTagSelector(context, ref),
                    icon: const Icon(Icons.label_outline),
                    tooltip: 'Manage Tags',
                  ),
                  
                  // Delete button
                  IconButton(
                    onPressed: () => _showDeleteConfirmation(context, ref),
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Delete',
                    color: theme.colorScheme.error,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _markAsCompleted(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(itemActionsProvider).markAsCompleted(item.id);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Marked "${item.displayTitle}" as completed'),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () => ref.read(itemActionsProvider).markAsUnread(item.id),
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _markAsUnread(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(itemActionsProvider).markAsUnread(item.id);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Restored "${item.displayTitle}"'),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  void _showDeleteConfirmation(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Item'),
        content: Text('Are you sure you want to delete "${item.displayTitle}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deleteItem(context, ref);
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteItem(BuildContext context, WidgetRef ref) async {
    try {
      print('🗑️ Starting delete for item: ${item.id}');
      print('🗑️ Item title: ${item.displayTitle}');
      
      await ref.read(itemActionsProvider).deleteItem(item.id);
      
      print('✅ Delete completed successfully');
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deleted "${item.displayTitle}"'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('❌ Delete failed: $e');
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting item: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  void _onTagTapped(BuildContext context, WidgetRef ref, tag) {
    // Add tag to search filters
    final currentTags = ref.read(selectedTagsProvider);
    if (!currentTags.contains(tag.id)) {
      ref.read(selectedTagsProvider.notifier).state = [...currentTags, tag.id];
    }
  }

  void _showTagSelector(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Manage Tags - ${item.displayTitle}'),
        content: SizedBox(
          width: double.maxFinite,
          child: TagSelector(
            itemId: item.id,
            currentTags: item.tags,
            onTagsChanged: () {
              Navigator.of(context).pop();
              // Refresh the items to show updated tags
              ref.invalidate(unreadArticlesProvider);
              ref.invalidate(unreadVideosProvider);
              ref.invalidate(archivedItemsProvider);
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}
