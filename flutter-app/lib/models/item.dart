import 'package:freezed_annotation/freezed_annotation.dart';

part 'item.freezed.dart';
part 'item.g.dart';

@freezed
class Item with _$Item {
  const factory Item({
    required String id,
    String? userId,
    required String url,
    String? canonicalUrl,
    required String domain,
    String? title,
    String? description,
    String? imageUrl,
    required ContentType contentType,
    required ItemStatus status,
    required DateTime addedAt,
    DateTime? finishedAt,
    required String sourceClient,
    String? sourcePlatform,
    String? notes,
    @JsonKey(name: 'metadata') Map<String, dynamic>? rawMetadata,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _Item;

  factory Item.fromJson(Map<String, dynamic> json) => _$ItemFromJson(json);
}

@JsonEnum(valueField: 'value')
enum ContentType {
  article('article'),
  video('video');

  const ContentType(this.value);
  final String value;
}

@JsonEnum(valueField: 'value')
enum ItemStatus {
  unread('unread'),
  completed('completed');

  const ItemStatus(this.value);
  final String value;
}

extension ItemExtensions on Item {
  bool get isArticle => contentType == ContentType.article;
  bool get isVideo => contentType == ContentType.video;
  bool get isCompleted => status == ItemStatus.completed;
  bool get isUnread => status == ItemStatus.unread;
  
  String get displayTitle => title ?? domain ?? 'Untitled';
  
  String get fallbackImageUrl {
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return imageUrl!;
    }
    // Fallback to domain favicon
    return 'https://www.google.com/s2/favicons?sz=64&domain_url=$domain';
  }
}
