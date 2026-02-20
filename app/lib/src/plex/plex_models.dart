class PlexLibrary {
  final String id;
  final String title;
  /// Usually "movie" or "show".
  final String type;

  const PlexLibrary({
    required this.id,
    required this.title,
    required this.type,
  });

  factory PlexLibrary.fromPlexJson(Map<String, dynamic> json) {
    return PlexLibrary(
      id: (json['key'] ?? json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
    );
  }
}
