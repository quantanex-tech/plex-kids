import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_config.dart';
import 'plex/plex_client.dart';
import 'plex/plex_models.dart';

final appConfigProvider = Provider<AppConfig>((ref) {
  return AppConfig.fromEnv();
});

final plexClientProvider = Provider<PlexClient?>((ref) {
  final cfg = ref.watch(appConfigProvider);
  if (!cfg.isConfigured) return null;

  return PlexClient(
    baseUrl: cfg.plexBaseUrl,
    token: cfg.plexToken,
  );
});

final plexLibrariesProvider = FutureProvider<List<PlexLibrary>>((ref) async {
  final client = ref.watch(plexClientProvider);
  if (client == null) return const [];
  return client.listLibraries();
});
