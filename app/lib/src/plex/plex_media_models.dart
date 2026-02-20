class PlexMediaItem {
  final String ratingKey;
  final String title;
  final String type;
  final String? thumb;

  const PlexMediaItem({
    required this.ratingKey,
    required this.title,
    required this.type,
    this.thumb,
  });

  factory PlexMediaItem.fromPlexJson(Map<String, dynamic> json) {
    return PlexMediaItem(
      ratingKey: (json['ratingKey'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      thumb: (json['thumb'] as String?) ?? (json['grandparentThumb'] as String?) ?? (json['parentThumb'] as String?),
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
