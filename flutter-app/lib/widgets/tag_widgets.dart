import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/tag.dart';
import '../providers/items_provider.dart';

class TagChip extends ConsumerWidget {
  final Tag tag;
  final bool isSelected;
  final VoidCallback? onTap;
  final VoidCallback? onDeleted;
  final bool showUsageCount;

  const TagChip({
    super.key,
    required this.tag,
    this.isSelected = false,
    this.onTap,
    this.onDeleted,
    this.showUsageCount = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(tag.name),
          if (showUsageCount && tag.usageCount > 0) ...[
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${tag.usageCount}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
      selected: isSelected,
      onSelected: onTap != null ? (_) => onTap!() : null,
      onDeleted: onDeleted,
      avatar: tag.isPreset
          ? Icon(
              Icons.star,
              size: 16,
              color: theme.colorScheme.primary,
            )
          : null,
      backgroundColor: tag.isPreset
          ? theme.colorScheme.primary.withOpacity(0.1)
          : theme.colorScheme.surface,
      selectedColor: theme.colorScheme.primary.withOpacity(0.3),
      checkmarkColor: theme.colorScheme.primary,
    );
  }
}

class TagSelector extends ConsumerStatefulWidget {
  final String itemId;
  final List<Tag> currentTags;
  final VoidCallback? onTagsChanged;

  const TagSelector({
    super.key,
    required this.itemId,
    required this.currentTags,
    this.onTagsChanged,
  });

  @override
  ConsumerState<TagSelector> createState() => _TagSelectorState();
}

class _TagSelectorState extends ConsumerState<TagSelector> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isExpanded = false;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tagsAsync = ref.watch(tagsProvider);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Current tags
        if (widget.currentTags.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: widget.currentTags.map((tag) {
              return TagChip(
                tag: tag,
                isSelected: true, // Set to true for current tags to show delete button
                onTap: () {}, // Provide empty callback to prevent disabled state
                onDeleted: () => _removeTag(tag),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
        ],
        
        // Add tag section
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                decoration: InputDecoration(
                  hintText: 'Add tag...',
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: _addCustomTag,
                  ),
                ),
                onSubmitted: (_) => _addCustomTag(),
                onTap: () => setState(() => _isExpanded = true),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(_isExpanded ? Icons.expand_less : Icons.expand_more),
              onPressed: () => setState(() => _isExpanded = !_isExpanded),
            ),
          ],
        ),
        
        // Available tags (when expanded)
        if (_isExpanded) ...[
          const SizedBox(height: 12),
          tagsAsync.when(
            data: (allTags) {
              final availableTags = allTags
                  .where((tag) => !widget.currentTags.any((ct) => ct.id == tag.id))
                  .toList();
              
              if (availableTags.isEmpty) {
                return const Text('No more tags available');
              }
              
              // Group by type
              final presetTags = availableTags.where((t) => t.isPreset).toList();
              final customTags = availableTags.where((t) => t.isCustom).toList();
              
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (presetTags.isNotEmpty) ...[
                    Text(
                      'Preset Tags',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: presetTags.map((tag) {
                        return TagChip(
                          tag: tag,
                          onTap: () => _addTag(tag),
                          showUsageCount: true,
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (customTags.isNotEmpty) ...[
                    Text(
                      'Custom Tags',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: customTags.map((tag) {
                        return TagChip(
                          tag: tag,
                          onTap: () => _addTag(tag),
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
        ],
      ],
    );
  }

  void _addCustomTag() {
    final tagName = _controller.text.trim();
    if (tagName.isNotEmpty) {
      _addTagByName(tagName);
      _controller.clear();
    }
  }

  void _addTag(Tag tag) {
    _addTagByName(tag.name);
  }

  Future<void> _addTagByName(String tagName) async {
    try {
      final actions = ref.read(itemActionsProvider);
      await actions.addTagToItem(widget.itemId, tagName);
      widget.onTagsChanged?.call();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add tag: $error')),
        );
      }
    }
  }

  Future<void> _removeTag(Tag tag) async {
    try {
      final actions = ref.read(itemActionsProvider);
      await actions.removeTagFromItem(widget.itemId, tag.id);
      widget.onTagsChanged?.call();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to remove tag: $error')),
        );
      }
    }
  }
}
