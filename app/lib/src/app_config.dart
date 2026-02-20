import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  final String plexBaseUrl;
  final String plexToken;

  const AppConfig({
    required this.plexBaseUrl,
    required this.plexToken,
  });

  static AppConfig fromEnv() {
    final baseUrl = dotenv.get('PLEX_BASE_URL', fallback: '').trim();
    final token = dotenv.get('PLEX_TOKEN', fallback: '').trim();

    return AppConfig(
      plexBaseUrl: baseUrl,
      plexToken: token,
    );
  }

  bool get isConfigured => plexBaseUrl.isNotEmpty && plexToken.isNotEmpty;
}
