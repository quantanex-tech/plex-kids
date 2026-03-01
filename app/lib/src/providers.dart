import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'app_config.dart';
import 'auth/auth_controller.dart';
import 'auth/auth_state.dart';
import 'plex/plex_client.dart';
import 'plex/plex_media_models.dart';
import 'plex/plex_models.dart';
import 'storage/secure_store.dart';

final appConfigProvider = Provider<AppConfig>((ref) {
  return AppConfig.fromEnv();
});

final secureStoreProvider = Provider<SecureStore>((ref) {
  return const SecureStore(FlutterSecureStorage());
});

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>((ref) {
  final store = ref.watch(secureStoreProvider);
  final ctl = AuthController(store: store);
  // Fire-and-forget restore.
  ctl.restore();
  return ctl;
});

final plexClientProvider = Provider<PlexClient?>((ref) {
  // Prefer auth-selected server/user tokens if present.
  final auth = ref.watch(authControllerProvider);
  if (auth.serverBaseUrl != null && auth.clientIdentifier != null) {
    final token = auth.serverAccessToken ?? auth.userToken;
    if (token != null) {
      return PlexClient(
        baseUrl: auth.serverBaseUrl!,
        token: token,
        clientIdentifier: auth.clientIdentifier!,
      );
    }
  }

  // Dev backdoor: allow .env PLEX_BASE_URL + PLEX_TOKEN.
  final cfg = ref.watch(appConfigProvider);
  if (!cfg.isConfigured) return null;
  // For dev .env mode, we don't have a stable per-install identifier; use a
  // constant. (For signed builds, AuthController persists a real identifier.)
  return PlexClient(baseUrl: cfg.plexBaseUrl, token: cfg.plexToken, clientIdentifier: 'plex-kids-dev');
});

final plexLibrariesProvider = FutureProvider<List<PlexLibrary>>((ref) async {
  final client = ref.watch(plexClientProvider);
  if (client == null) return const [];

  final libs = await client.listLibraries();
  // MVP: only TV + Movies.
  return libs.where((l) => l.type == 'movie' || l.type == 'show').toList(growable: false);
});

final selectedLibraryProvider = StateProvider<PlexLibrary?>((ref) {
  return null;
});

final onDeckProvider = FutureProvider((ref) async {
  final client = ref.watch(plexClientProvider);
  if (client == null) return const <PlexMediaItem>[];
  return client.onDeck(size: 30);
});

final recentlyAddedProvider = FutureProvider.family((ref, String libraryId) async {
  final client = ref.watch(plexClientProvider);
  if (client == null) return const <PlexMediaItem>[];
  return client.recentlyAdded(libraryId: libraryId, size: 30);
});

final randomPicksProvider = FutureProvider.family((ref, String libraryId) async {
  final client = ref.watch(plexClientProvider);
  if (client == null) return const <PlexMediaItem>[];
  return client.randomPicks(libraryId: libraryId, size: 30);
});

final showEpisodesProvider = FutureProvider.family((ref, String showRatingKey) async {
  final client = ref.watch(plexClientProvider);
  if (client == null) return const <PlexMediaItem>[];
  final eps = await client.showEpisodes(showRatingKey: showRatingKey, size: 500);
  // Ensure oldest -> newest (season then episode).
  final sorted = [...eps];
  sorted.sort((a, b) {
    final p = (a.parentIndex ?? 0).compareTo(b.parentIndex ?? 0);
    if (p != 0) return p;
    return (a.index ?? 0).compareTo(b.index ?? 0);
  });
  return sorted;
});
