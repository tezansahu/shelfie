import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
        onTap: () => _openUrl(item.url, context),
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
                  Expanded(
                    child: !isArchive
                        ? ElevatedButton.icon(
                            onPressed: () => _markAsCompleted(context, ref),
                            icon: const Icon(Icons.check_circle, size: 18),
                            label: Text(item.isVideo ? 'Watched' : 'Read'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.colorScheme.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          )
                        : ElevatedButton.icon(
                            onPressed: () => _markAsUnread(context, ref),
                            icon: const Icon(Icons.undo, size: 18),
                            label: const Text('Restore'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.colorScheme.secondary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                  ),
                  
                  const SizedBox(width: 12),
                  
                  // Open button
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _openUrl(item.url, context),
                      icon: const Icon(Icons.open_in_new, size: 18),
                      label: const Text('Open'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: theme.colorScheme.primary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(color: theme.colorScheme.primary),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(width: 12),
                  
                  // Tag management button
                  Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: theme.colorScheme.outline.withOpacity(0.2)),
                    ),
                    child: IconButton(
                      onPressed: () => _showTagSelector(context, ref),
                      icon: Icon(Icons.label_outline, color: theme.colorScheme.primary),
                      tooltip: 'Manage Tags',
                    ),
                  ),
                  
                  const SizedBox(width: 8),
                  
                  // Delete button
                  Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.errorContainer.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: theme.colorScheme.error.withOpacity(0.2)),
                    ),
                    child: IconButton(
                      onPressed: () => _showDeleteConfirmation(context, ref),
                      icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
                      tooltip: 'Delete',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openUrl(String url, BuildContext context) async {
    try {
      print('🔗 Attempting to open URL: $url');
      
      // Validate and clean the URL
      String cleanUrl = url.trim();
      if (!cleanUrl.startsWith('http://') && !cleanUrl.startsWith('https://')) {
        cleanUrl = 'https://$cleanUrl';
      }
      
      final uri = Uri.parse(cleanUrl);
      print('🔗 Parsed URI: $uri');
      
      // Check if URL can be launched
      final canLaunch = await canLaunchUrl(uri);
      print('🔗 Can launch URL: $canLaunch');
      
      if (canLaunch) {
        // Try different launch modes for better compatibility
        bool launched = false;
        
        // For YouTube URLs, try to open in YouTube app first
        if (uri.host.contains('youtube.com') || uri.host.contains('youtu.be')) {
          try {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
            launched = true;
            print('🎥 Opened YouTube URL in external app');
          } catch (e) {
            print('⚠️ Failed to open in YouTube app, trying browser: $e');
          }
        }
        
        // If not launched yet, try browser
        if (!launched) {
          await launchUrl(
            uri,
            mode: LaunchMode.externalApplication,
            webViewConfiguration: const WebViewConfiguration(
              enableJavaScript: true,
              enableDomStorage: true,
            ),
          );
          print('🌐 Opened URL in browser');
        }
      } else {
        throw Exception('Cannot launch URL: $cleanUrl');
      }
    } catch (e) {
      print('❌ Error opening URL: $e');
      
      // Show user-friendly error message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open link: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
            action: SnackBarAction(
              label: 'Copy URL',
              textColor: Colors.white,
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: url));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('URL copied to clipboard')),
                  );
                }
              },
            ),
          ),
        );
      }
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
          height: MediaQuery.of(context).size.height * 0.6, // Limit height to 60% of screen
          child: SingleChildScrollView( // Make content scrollable
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
