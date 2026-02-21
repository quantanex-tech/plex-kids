class PlexMediaItem {
  final String ratingKey;
  final String title;
  final String type;

  /// Artwork for this item.
  final String? thumb;

  /// For episodes: show identity.
  final String? grandparentRatingKey;
  final String? grandparentTitle;
  final String? grandparentThumb;

  /// Sorting.
  final int? index;
  final int? parentIndex;

  /// Library section.
  final String? librarySectionId;

  const PlexMediaItem({
    required this.ratingKey,
    required this.title,
    required this.type,
    this.thumb,
    this.grandparentRatingKey,
    this.grandparentTitle,
    this.grandparentThumb,
    this.index,
    this.parentIndex,
    this.librarySectionId,
  });

  factory PlexMediaItem.fromPlexJson(Map<String, dynamic> json) {
    int? asInt(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString());
    }

    final thumb = (json['thumb'] as String?) ??
        (json['grandparentThumb'] as String?) ??
        (json['parentThumb'] as String?);

    return PlexMediaItem(
      ratingKey: (json['ratingKey'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      thumb: thumb,
      grandparentRatingKey: (json['grandparentRatingKey'] ?? '').toString().isEmpty
          ? null
          : (json['grandparentRatingKey'] ?? '').toString(),
      grandparentTitle:
          (json['grandparentTitle'] ?? '').toString().isEmpty ? null : (json['grandparentTitle'] ?? '').toString(),
      grandparentThumb:
          (json['grandparentThumb'] ?? '').toString().isEmpty ? null : (json['grandparentThumb'] ?? '').toString(),
      index: asInt(json['index']),
      parentIndex: asInt(json['parentIndex']),
      librarySectionId: (json['librarySectionID'] ?? '').toString().isEmpty
          ? null
          : (json['librarySectionID'] ?? '').toString(),
    );
  }
}

class PlexMediaContainerParser {
  static List<PlexMediaItem> parseMetadata(dynamic resData) {
    final data = resData;
    final mediaContainer = (data is Map<String, dynamic>) ? data['MediaContainer'] : null;
    final meta = (mediaContainer is Map<String, dynamic>) ? mediaContainer['Metadata'] : null;

    if (meta is List) {
      return meta
          .whereType<Map>()
          .map((e) => PlexMediaItem.fromPlexJson(e.cast<String, dynamic>()))
          .where((e) => e.ratingKey.isNotEmpty)
          .toList(growable: false);
    }

    if (meta is Map<String, dynamic>) {
      final item = PlexMediaItem.fromPlexJson(meta);
      return item.ratingKey.isEmpty ? const [] : [item];
    }

    return const [];
  }
}
