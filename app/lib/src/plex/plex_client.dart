import 'package:dio/dio.dart';

import 'plex_media_models.dart';
import 'plex_models.dart';
import 'plex_playback_parser.dart';

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

  /// Continue Watching (Plex "On Deck")
  Future<List<PlexMediaItem>> onDeck({int size = 30}) async {
    final res = await _dio.get(
      '/library/onDeck',
      queryParameters: {
        'X-Plex-Container-Start': 0,
        'X-Plex-Container-Size': size,
      },
    );

    return PlexMediaContainerParser.parseMetadata(res.data);
  }

  /// Recently added items for a specific library section.
  Future<List<PlexMediaItem>> recentlyAdded({required String libraryId, int size = 30}) async {
    final res = await _dio.get(
      '/library/sections/$libraryId/recentlyAdded',
      queryParameters: {
        'X-Plex-Container-Start': 0,
        'X-Plex-Container-Size': size,
      },
    );

    return PlexMediaContainerParser.parseMetadata(res.data);
  }

  /// For a show ratingKey, list episodes (leaves). Intended for a super-simple
  /// show page with episodes in season order.
  Future<List<PlexMediaItem>> showEpisodes({required String showRatingKey, int size = 500}) async {
    final res = await _dio.get(
      '/library/metadata/$showRatingKey/allLeaves',
      queryParameters: {
        'X-Plex-Container-Start': 0,
        'X-Plex-Container-Size': size,
      },
    );

    return PlexMediaContainerParser.parseMetadata(res.data);
  }

  /// Random picks from a library.
  ///
  /// Plex supports `sort=random` on many endpoints.
  Future<List<PlexMediaItem>> randomPicks({required String libraryId, int size = 30}) async {
    final res = await _dio.get(
      '/library/sections/$libraryId/all',
      queryParameters: {
        'sort': 'random',
        'X-Plex-Container-Start': 0,
        'X-Plex-Container-Size': size,
      },
    );

    return PlexMediaContainerParser.parseMetadata(res.data);
  }

  /// Fetch metadata for a given ratingKey and return the first playable Part key.
  Future<String> getFirstPartKey({required String ratingKey}) async {
    final res = await _dio.get('/library/metadata/$ratingKey');
    final info = PlexPlaybackParser.parseFirstPart(res.data);
    if (info == null) {
      throw StateError('No playable part found for ratingKey=$ratingKey');
    }
    return info.partKey;
  }
}

