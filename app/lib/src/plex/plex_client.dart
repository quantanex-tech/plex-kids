import 'package:dio/dio.dart';

import 'plex_models.dart';

class PlexClient {
  final Dio _dio;

  PlexClient({
    required String baseUrl,
    required String token,
  }) : _dio = Dio(
          BaseOptions(
            baseUrl: baseUrl,
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 20),
            // Plex can return XML by default; we explicitly request JSON.
            headers: {
              'X-Plex-Token': token,
              'Accept': 'application/json',
            },
            queryParameters: const {
              'X-Plex-Token': null, // keep token in header only
            },
          ),
        );

  Future<bool> ping() async {
    final res = await _dio.get('/');
    return res.statusCode != null && res.statusCode! >= 200 && res.statusCode! < 400;
  }

  Future<List<PlexLibrary>> listLibraries() async {
    // /library/sections is the primary way to enumerate libraries.
    final res = await _dio.get(
      '/library/sections',
      queryParameters: const {
        'X-Plex-Container-Start': 0,
        'X-Plex-Container-Size': 100,
      },
    );

    final data = res.data;
    final mediaContainer = (data is Map<String, dynamic>) ? data['MediaContainer'] : null;
    final dirs = (mediaContainer is Map<String, dynamic>) ? mediaContainer['Directory'] : null;

    if (dirs is List) {
      return dirs
          .whereType<Map>()
          .map((e) => PlexLibrary.fromPlexJson(e.cast<String, dynamic>()))
          .toList();
    }

    // Some Plex installations may return a single object.
    if (dirs is Map<String, dynamic>) {
      return [PlexLibrary.fromPlexJson(dirs)];
    }

    return const [];
  }
}
