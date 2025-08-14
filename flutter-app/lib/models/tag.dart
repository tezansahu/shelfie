import 'package:freezed_annotation/freezed_annotation.dart';

part 'tag.freezed.dart';
part 'tag.g.dart';

@freezed
class Tag with _$Tag {
  const factory Tag({
    required String id,
    String? userId,
    required String name,
    required TagType type,
    required DateTime createdAt,
    required DateTime updatedAt,
    @Default(0) int usageCount,
  }) = _Tag;

  factory Tag.fromJson(Map<String, dynamic> json) => _$TagFromJson(json);
}

@JsonEnum(valueField: 'value')
enum TagType {
  preset('preset'),
  custom('custom');

  const TagType(this.value);
  final String value;
}

extension TagExtensions on Tag {
  bool get isPreset => type == TagType.preset;
  bool get isCustom => type == TagType.custom;
}
