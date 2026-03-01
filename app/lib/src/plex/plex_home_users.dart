import 'package:dio/dio.dart';
import 'package:xml/xml.dart';

class PlexHomeUser {
  final String id;
  final String title;
  final bool isManaged;
  final bool isProtected;
  final String? thumb;

  const PlexHomeUser({
    required this.id,
    required this.title,
    required this.isManaged,
    required this.isProtected,
    this.thumb,
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

  static List<PlexHomeUser> parseUsersXml(String xmlString) {
    final xml = XmlDocument.parse(xmlString);
    final users = <PlexHomeUser>[];

    for (final u in xml.findAllElements('User')) {
      final id = u.getAttribute('id') ?? '';
      final title = u.getAttribute('title') ?? '';
      bool truthy(String? v) {
        final s = (v ?? '').trim().toLowerCase();
        return s == '1' || s == 'true' || s == 'yes';
      }

      final managed = truthy(u.getAttribute('managed'));
      final protected = truthy(u.getAttribute('protected'));
      final thumb = (u.getAttribute('thumb') ?? '').trim();

      if (id.isEmpty || title.isEmpty) continue;
      users.add(
        PlexHomeUser(
          id: id,
          title: title,
          isManaged: managed,
          isProtected: protected,
          thumb: thumb.isEmpty ? null : thumb,
        ),
      );
    }

    return users;
  }

  Future<List<PlexHomeUser>> listUsers({required String accountToken, String? clientIdentifier}) async {
    // XML: https://plex.tv/api/home/users
    final res = await _dio.get(
      '/api/home/users',
      queryParameters: {
        'X-Plex-Token': accountToken,
        if (clientIdentifier != null && clientIdentifier.isNotEmpty) 'X-Plex-Client-Identifier': clientIdentifier,
      },
      options: Options(headers: {
        'X-Plex-Token': accountToken,
        if (clientIdentifier != null && clientIdentifier.isNotEmpty) 'X-Plex-Client-Identifier': clientIdentifier,
      }),
    );

    return parseUsersXml(res.data as String);
  }

  /// Switch to a home user and return the user token.
  Future<String> switchUser({
    required String accountToken,
    required String userId,
    String? pin,
    String? clientIdentifier,
  }) async {
    // XML: POST https://plex.tv/api/home/users/{id}/switch
    // Some Plex setups expect tokens/pins in headers rather than query params.
    // We send both where possible.
    final res = await _dio.post(
      '/api/home/users/$userId/switch',
      queryParameters: {
        'X-Plex-Token': accountToken,
        if (pin != null && pin.isNotEmpty) 'pin': pin,
        if (clientIdentifier != null && clientIdentifier.isNotEmpty) 'X-Plex-Client-Identifier': clientIdentifier,
      },
      options: Options(
        headers: {
          'X-Plex-Token': accountToken,
          if (pin != null && pin.isNotEmpty) 'X-Plex-PIN': pin,
          if (clientIdentifier != null && clientIdentifier.isNotEmpty) 'X-Plex-Client-Identifier': clientIdentifier,
        },
      ),
    );

    final xml = XmlDocument.parse(res.data as String);
    final userEl = xml.findAllElements('User').firstOrNull;
    final token = userEl?.getAttribute('authenticationToken') ?? '';
    if (token.isEmpty) {
      throw StateError('Failed to switch user (no token returned).');
    }
    return token;
  }

  static String describeSwitchError(Object e) {
    if (e is DioException) {
      final status = e.response?.statusCode;
      final body = e.response?.data;

      if (status == 401) {
        return 'Plex refused the request (401). The account token may be invalid/expired. Try Clear session and sign in again.';
      }

      if (status == 422) {
        return 'Plex refused the profile switch (422). This can happen if the profile requires a PIN, or if plex.tv did not accept the switch request for this account.\n\nDetails: $body';
      }

      return 'Plex error (HTTP $status): ${e.message}\n\nDetails: $body';
    }

    return e.toString();
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
