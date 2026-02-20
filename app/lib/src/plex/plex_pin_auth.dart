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
    final res = await _dio.post(
      '/api/v2/pins',
      queryParameters: {
        'strong': 'true',
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
  String buildAuthUrl({required PlexPin pin, required String clientIdentifier}) {
    // app.plex.tv auth page consumes the pin code.
    // This mirrors how many Plex apps do login.
    final code = Uri.encodeComponent(pin.code);
    final clientId = Uri.encodeComponent(clientIdentifier);

    return 'https://app.plex.tv/auth#?'
        'clientID=$clientId'
        '&code=$code'
        '&context%5Bdevice%5D%5Bproduct%5D=Plex%20Kids';
  }

  Future<String> pollForAuthToken({
    required PlexPin pin,
    required String clientIdentifier,
    Duration pollEvery = const Duration(seconds: 2),
    Duration timeout = const Duration(minutes: 3),
  }) async {
    final deadline = DateTime.now().add(timeout);

    while (DateTime.now().isBefore(deadline)) {
      final res = await _dio.get(
        '/api/v2/pins/${pin.id}',
        options: Options(headers: {
          'X-Plex-Client-Identifier': clientIdentifier,
        }),
      );

      final json = (res.data as Map).cast<String, dynamic>();
      final token = (json['authToken'] ?? '').toString();
      if (token.isNotEmpty) return token;

      await Future.delayed(pollEvery);
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
