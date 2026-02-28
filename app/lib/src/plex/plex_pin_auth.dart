import 'dart:async';

import 'package:dio/dio.dart';

/// Implements Plex "PIN" auth (device code) flow.
///
/// This is the simplest reliable way to use external browser login without
/// needing a custom redirect URI.
class PlexPinAuth {
  final Dio _dio;

  PlexPinAuth()
      : _dio = Dio(
          BaseOptions(
            baseUrl: 'https://plex.tv',
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 20),
            headers: const {
              'Accept': 'application/json',
            },
          ),
        );

  Future<PlexPin> createPin({required String clientIdentifier}) async {
    // NOTE: "strong" PINs appear to generate longer codes that are NOT accepted
    // by the https://plex.tv/link 4-character code entry UI.
    // For device link UX, we use the standard short code.
    final res = await _dio.post(
      '/api/v2/pins',
      queryParameters: const {
        'strong': 'false',
      },
      data: {
        'X-Plex-Client-Identifier': clientIdentifier,
      },
      options: Options(
        headers: {
          'X-Plex-Client-Identifier': clientIdentifier,
        },
      ),
    );

    final json = (res.data as Map).cast<String, dynamic>();
    return PlexPin.fromJson(json);
  }

  /// Open this URL in an external browser.
  ///
  /// We intentionally use the classic link flow. The app.plex.tv hash route has
  /// proven brittle (dead-end "unable to complete this request" on some setups).
  String buildAuthUrl({required PlexPin pin, required String clientIdentifier}) {
    // We open the link page and let the user enter the 4-character code.
    // Passing code=... in the URL has been unreliable.
    return 'https://plex.tv/link';
  }

  Future<String> pollForAuthToken({
    required PlexPin pin,
    required String clientIdentifier,
    Duration pollEvery = const Duration(seconds: 2),
    Duration timeout = const Duration(minutes: 3),
  }) async {
    final deadline = DateTime.now().add(timeout);
    var attempt = 0;

    while (DateTime.now().isBefore(deadline)) {
      attempt += 1;
      try {
        final res = await _dio.get(
          '/api/v2/pins/${pin.id}',
          queryParameters: {
            // Some Plex deployments appear to behave better when the client id is
            // present as a query param as well as a header.
            'X-Plex-Client-Identifier': clientIdentifier,
          },
          options: Options(headers: {
            'X-Plex-Client-Identifier': clientIdentifier,
          }),
        );

        final json = (res.data as Map).cast<String, dynamic>();
        final token = (json['authToken'] ?? '').toString();
        if (token.isNotEmpty) return token;
      } catch (_) {
        // Treat transient network issues (e.g. connection abort) as retryable.
        // We'll keep polling until overall timeout.
      }

      // Light backoff to avoid hammering plex.tv.
      final backoff = Duration(milliseconds: (pollEvery.inMilliseconds * (attempt < 5 ? 1 : 2)));
      await Future.delayed(backoff);
    }

    throw TimeoutException('Plex login timed out.');
  }
}

class PlexPin {
  final int id;
  final String code;

  const PlexPin({required this.id, required this.code});

  factory PlexPin.fromJson(Map<String, dynamic> json) {
    return PlexPin(
      id: (json['id'] as num).toInt(),
      code: (json['code'] ?? '').toString(),
    );
  }
}
