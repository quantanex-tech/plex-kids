class PlexUrl {
  static String imageUrl({required String baseUrl, required String path, required String token}) {
    final p = path.startsWith('/') ? path : '/$path';
    return '$baseUrl$p?X-Plex-Token=$token';
  }

  static String absolute({required String baseUrl, required String path}) {
    final p = path.startsWith('/') ? path : '/$path';
    return '$baseUrl$p';
  }
}
