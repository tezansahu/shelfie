import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../models/item.dart';
import '../providers/items_provider.dart';
import 'tag_widgets.dart';
import 'edit_item_dialog.dart';

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
                        
                        // Responsive: show domain + date on one line for wide cards, otherwise stack
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final singleLine = constraints.maxWidth > 420;

                            if (singleLine) {
                              // Render domain and time on same row
                              return Row(
                                children: [
                                  Icon(
                                    Icons.language,
                                    size: 16,
                                    color: theme.colorScheme.outline,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      item.domain,
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.outline,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(
                                    Icons.access_time,
                                    size: 14,
                                    color: theme.colorScheme.outline,
                                  ),
                                  const SizedBox(width: 6),
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(maxWidth: 120),
                                    child: Text(
                                      isArchive && item.finishedAt != null
                                          ? timeago.format(item.finishedAt!)
                                          : timeago.format(item.addedAt),
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.outline,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.right,
                                    ),
                                  ),
                                ],
                              );
                            }

                            // Stacked layout for narrow cards
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.language,
                                      size: 16,
                                      color: theme.colorScheme.outline,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        item.domain,
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: theme.colorScheme.outline,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 4),

                                Row(
                                  children: [
                                    Icon(
                                      Icons.access_time,
                                      size: 14,
                                      color: theme.colorScheme.outline,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        isArchive && item.finishedAt != null
                                            ? timeago.format(item.finishedAt!)
                                            : timeago.format(item.addedAt),
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: theme.colorScheme.outline,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            );
                          },
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
              
              // Actions: first row (Read/Restore + Open), second row (Edit, Manage Tags, Delete)
              const SizedBox(height: 12),
              // Use LayoutBuilder to show labels on wide viewports and icons-only on narrow
              LayoutBuilder(
                builder: (context, constraints) {
                  final showLabels = constraints.maxWidth > 600; // adjust breakpoint as needed

                  Widget buildSmallAction({
                    required IconData icon,
                    required String label,
                    required VoidCallback onPressed,
                    Color? iconColor,
                    Color? bgColor,
                    Color? borderColor,
                  }) {
                    return OutlinedButton(
                      onPressed: onPressed,
                      style: OutlinedButton.styleFrom(
                        backgroundColor: bgColor ?? theme.colorScheme.surface,
                        foregroundColor: iconColor ?? theme.colorScheme.primary,
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                        side: BorderSide(color: borderColor ?? theme.colorScheme.outline.withOpacity(0.2)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        minimumSize: const Size(double.infinity, 44),
                        // Ensure button takes available width when used inside Expanded
                      ),
                      child: showLabels
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.max,
                              children: [
                                Icon(icon, color: iconColor ?? theme.colorScheme.primary, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    label,
                                    textAlign: TextAlign.center,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            )
                          : Icon(icon, color: iconColor ?? theme.colorScheme.primary),
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // First row:
                      Row(
                        children: [
                          // Open button (left) - primary styled
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _openUrl(item.url, context),
                              icon: const Icon(Icons.open_in_new, size: 18),
                              label: const Text('Open'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: theme.colorScheme.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                minimumSize: const Size.fromHeight(44),
                              ),
                            ),
                          ),

                          const SizedBox(width: 12),

                          // Read / Restore button (right) - outlined style
                          Expanded(
                            child: !isArchive
                                ? OutlinedButton.icon(
                                    onPressed: () => _markAsCompleted(context, ref),
                                    icon: const Icon(Icons.check_circle, size: 18),
                                    label: Text(item.isVideo ? 'Watched' : 'Read'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: theme.colorScheme.primary,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      side: BorderSide(color: theme.colorScheme.primary),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      minimumSize: const Size.fromHeight(44),
                                    ),
                                  )
                                : OutlinedButton.icon(
                                    onPressed: () => _markAsUnread(context, ref),
                                    icon: const Icon(Icons.undo, size: 18),
                                    label: const Text('Restore'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: theme.colorScheme.secondary,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      side: BorderSide(color: theme.colorScheme.secondary),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      minimumSize: const Size.fromHeight(44),
                                    ),
                                  ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      // Second row: evenly distributed small actions (Edit, Manage Tags, Delete)
                      Row(
                        children: [
                          Expanded(
                            child: buildSmallAction(
                              icon: Icons.edit_outlined,
                              label: 'Edit',
                              onPressed: () => showDialog(
                                context: context,
                                builder: (context) => EditItemDialog(item: item),
                              ),
                              iconColor: theme.colorScheme.primary,
                              bgColor: theme.colorScheme.surface,
                              borderColor: theme.colorScheme.outline.withOpacity(0.2),
                            ),
                          ),

                          const SizedBox(width: 8),

                          Expanded(
                            child: buildSmallAction(
                              icon: Icons.label_outline,
                              label: 'Manage Tags',
                              onPressed: () => _showTagSelector(context, ref),
                              iconColor: theme.colorScheme.primary,
                              bgColor: theme.colorScheme.surface,
                              borderColor: theme.colorScheme.outline.withOpacity(0.2),
                            ),
                          ),

                          const SizedBox(width: 8),

                          Expanded(
                            child: buildSmallAction(
                              icon: Icons.delete_outline,
                              label: 'Delete',
                              onPressed: () => _showDeleteConfirmation(context, ref),
                              iconColor: theme.colorScheme.error,
                              bgColor: theme.colorScheme.errorContainer.withOpacity(0.1),
                              borderColor: theme.colorScheme.error.withOpacity(0.2),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
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
