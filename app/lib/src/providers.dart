import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'app_config.dart';
import 'auth/auth_controller.dart';
import 'auth/auth_state.dart';
import 'plex/plex_client.dart';
import 'plex/plex_models.dart';
import 'storage/secure_store.dart';

final appConfigProvider = Provider<AppConfig>((ref) {
  return AppConfig.fromEnv();
});

final secureStoreProvider = Provider<SecureStore>((ref) {
  return const SecureStore(FlutterSecureStorage());
});

final clientIdentifierProvider = Provider<String>((ref) {
  // TODO: persist a generated UUID in secure storage once we add a simple prefs layer.
  final r = Random();
  return 'plex-kids-${DateTime.now().millisecondsSinceEpoch}-${r.nextInt(1 << 32)}';
});

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>((ref) {
  final store = ref.watch(secureStoreProvider);
  final clientId = ref.watch(clientIdentifierProvider);
  final ctl = AuthController(store: store, clientIdentifier: clientId);
  // Fire-and-forget restore.
  ctl.restore();
  return ctl;
});

final plexClientProvider = Provider<PlexClient?>((ref) {
  // Prefer auth-selected server/user tokens if present.
  final auth = ref.watch(authControllerProvider);
  if (auth.userToken != null && auth.serverBaseUrl != null) {
    return PlexClient(baseUrl: auth.serverBaseUrl!, token: auth.userToken!);
  }

  // Dev backdoor: allow .env PLEX_BASE_URL + PLEX_TOKEN.
  final cfg = ref.watch(appConfigProvider);
  if (!cfg.isConfigured) return null;
  return PlexClient(baseUrl: cfg.plexBaseUrl, token: cfg.plexToken);
});

final plexLibrariesProvider = FutureProvider<List<PlexLibrary>>((ref) async {
  final client = ref.watch(plexClientProvider);
  if (client == null) return const [];
  return client.listLibraries();
});
