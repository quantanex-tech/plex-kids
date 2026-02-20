import 'package:dio/dio.dart';
import 'package:xml/xml.dart';

class PlexHomeUser {
  final String id;
  final String title;
  final bool isManaged;
  final bool isProtected;

  const PlexHomeUser({
    required this.id,
    required this.title,
    required this.isManaged,
    required this.isProtected,
  });
}

/// Plex Home endpoints are a bit inconsistent between v1 XML and v2 JSON.
///
/// For MVP we implement the XML endpoints which are widely supported.
class PlexHomeUsersApi {
  final Dio _dio;

  PlexHomeUsersApi()
      : _dio = Dio(
          BaseOptions(
            baseUrl: 'https://plex.tv',
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 20),
            responseType: ResponseType.plain,
          ),
        );

  Future<List<PlexHomeUser>> listUsers({required String accountToken}) async {
    // XML: https://plex.tv/api/home/users
    final res = await _dio.get(
      '/api/home/users',
      queryParameters: {
        'X-Plex-Token': accountToken,
      },
    );

    final xml = XmlDocument.parse(res.data as String);
    final users = <PlexHomeUser>[];

    for (final u in xml.findAllElements('User')) {
      final id = u.getAttribute('id') ?? '';
      final title = u.getAttribute('title') ?? '';
      final managed = (u.getAttribute('managed') ?? '0') == '1';
      final protected = (u.getAttribute('protected') ?? '0') == '1';

      if (id.isEmpty || title.isEmpty) continue;
      users.add(PlexHomeUser(id: id, title: title, isManaged: managed, isProtected: protected));
    }

    return users;
  }

  /// Switch to a home user and return the user token.
  Future<String> switchUser({
    required String accountToken,
    required String userId,
    String? pin,
  }) async {
    // XML: POST https://plex.tv/api/home/users/{id}/switch
    final res = await _dio.post(
      '/api/home/users/$userId/switch',
      queryParameters: {
        'X-Plex-Token': accountToken,
        if (pin != null && pin.isNotEmpty) 'pin': pin,
      },
    );

    final xml = XmlDocument.parse(res.data as String);
    final userEl = xml.findAllElements('User').firstOrNull;
    final token = userEl?.getAttribute('authenticationToken') ?? '';
    if (token.isEmpty) {
      throw StateError('Failed to switch user (no token returned).');
    }
    return token;
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
