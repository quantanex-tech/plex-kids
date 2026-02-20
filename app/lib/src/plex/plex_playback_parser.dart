class PlexPlaybackInfo {
  final String partKey;

  const PlexPlaybackInfo({required this.partKey});
}

class PlexPlaybackParser {
  /// Extract the first playable Part key from /library/metadata/{ratingKey}.
  static PlexPlaybackInfo? parseFirstPart(dynamic resData) {
    final data = resData;
    final mc = (data is Map<String, dynamic>) ? data['MediaContainer'] : null;
    final meta = (mc is Map<String, dynamic>) ? mc['Metadata'] : null;

    Map<String, dynamic>? item;
    if (meta is List && meta.isNotEmpty) {
      final first = meta.first;
      if (first is Map) item = first.cast<String, dynamic>();
    } else if (meta is Map<String, dynamic>) {
      item = meta;
    }

    if (item == null) return null;

    final media = item['Media'];
    Map<String, dynamic>? media0;
    if (media is List && media.isNotEmpty) {
      final first = media.first;
      if (first is Map) media0 = first.cast<String, dynamic>();
    } else if (media is Map<String, dynamic>) {
      media0 = media;
    }

    if (media0 == null) return null;

    final part = media0['Part'];
    Map<String, dynamic>? part0;
    if (part is List && part.isNotEmpty) {
      final first = part.first;
      if (first is Map) part0 = first.cast<String, dynamic>();
    } else if (part is Map<String, dynamic>) {
      part0 = part;
    }

    final key = (part0?['key'] ?? '').toString();
    if (key.isEmpty) return null;

    return PlexPlaybackInfo(partKey: key);
  }
}
