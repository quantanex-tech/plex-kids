import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../connection/connection_selector.dart';
import '../plex/plex_home_users.dart';
import '../plex/plex_pin_auth.dart';
import '../plex/plex_resources.dart';
import '../storage/secure_store.dart';
import 'auth_state.dart';

class AuthController extends StateNotifier<AuthState> {
  final SecureStore _store;

  final PlexPinAuth _pinAuth;
  final PlexHomeUsersApi _homeUsers;
  final PlexResourcesApi _resources;
  final PlexConnectionSelector _selector;

  /// A stable client id; for now we hardcode a deterministic-ish value.
  /// Later we can persist a generated UUID.
  final String clientIdentifier;

  AuthController({
    required SecureStore store,
    required this.clientIdentifier,
  })  : _store = store,
        _pinAuth = PlexPinAuth(),
        _homeUsers = PlexHomeUsersApi(),
        _resources = PlexResourcesApi(),
        _selector = PlexConnectionSelector(),
        super(AuthState.initial());

  Future<void> restore() async {
    final account = await _store.readAccountToken();
    final user = await _store.readUserToken();
    final baseUrl = await _store.readServerBaseUrl();
    final machineId = await _store.readServerMachineId();

    state = state.copyWith(
      accountToken: account,
      userToken: user,
      serverBaseUrl: baseUrl,
      serverMachineId: machineId,
    );
  }

  Future<void> signInAndSelectKid({String? kidPin}) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      // 1) Create PIN + open browser
      final pin = await _pinAuth.createPin(clientIdentifier: clientIdentifier);
      final url = _pinAuth.buildAuthUrl(pin: pin, clientIdentifier: clientIdentifier);
      final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (!ok) {
        throw StateError('Could not open browser for Plex login');
      }

      // 2) Poll for account token
      final accountToken = await _pinAuth.pollForAuthToken(pin: pin, clientIdentifier: clientIdentifier);
      await _store.writeAccountToken(accountToken);

      // 3) List home users and pick a managed user (kid). For now: first managed user.
      final users = await _homeUsers.listUsers(accountToken: accountToken);
      final kid = users.where((u) => u.isManaged).firstOrNull;
      if (kid == null) {
        throw StateError('No managed users found. Create a managed user in Plex Home.');
      }

      // 4) Switch to that user
      final userToken = await _homeUsers.switchUser(
        accountToken: accountToken,
        userId: kid.id,
        pin: kid.isProtected ? (kidPin ?? '') : null,
      );
      await _store.writeUserToken(userToken);

      // 5) Discover servers (assume one server for MVP)
      final servers = await _resources.listServers(token: userToken);
      if (servers.isEmpty) throw StateError('No Plex servers found for this account');
      final server = servers.first;

      // 6) Choose best connection (local first, but short timeouts)
      final candidates = server.connections
          .map((c) => (c.uri, c.local))
          .toList(growable: false);

      final best = await _selector.chooseBest(
        candidates: candidates,
        token: userToken,
        localTimeout: const Duration(seconds: 3),
        remoteTimeout: const Duration(seconds: 8),
      );

      await _store.writeServerSelection(machineId: server.machineIdentifier, baseUrl: best.baseUrl);

      state = state.copyWith(
        isLoading: false,
        accountToken: accountToken,
        userToken: userToken,
        serverName: server.name,
        serverMachineId: server.machineIdentifier,
        serverBaseUrl: best.baseUrl,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _store.clearAll();
    state = AuthState.initial();
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
