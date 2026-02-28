import 'package:dio/dio.dart';

class PlexTvUser {
  final String? username;
  final String? email;
  final String? title;

  const PlexTvUser({this.username, this.email, this.title});

  factory PlexTvUser.fromJson(Map<String, dynamic> json) {
    return PlexTvUser(
      username: (json['username'] ?? '').toString().isEmpty ? null : (json['username'] ?? '').toString(),
      email: (json['email'] ?? '').toString().isEmpty ? null : (json['email'] ?? '').toString(),
      title: (json['title'] ?? '').toString().isEmpty ? null : (json['title'] ?? '').toString(),
    );
  }
}

class PlexTvApi {
  final Dio _dio;

  PlexTvApi()
      : _dio = Dio(
          BaseOptions(
            baseUrl: 'https://plex.tv',
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 20),
            headers: const {'Accept': 'application/json'},
          ),
        );

  Future<PlexTvUser> getUser({required String token}) async {
    final res = await _dio.get(
      '/api/v2/user',
      queryParameters: {
        'X-Plex-Token': token,
      },
      options: Options(headers: {
        'X-Plex-Token': token,
      }),
    );

    final data = (res.data as Map).cast<String, dynamic>();
    return PlexTvUser.fromJson(data);
  }
}
