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

  String? _clientIdentifier;

  AuthController({
    required SecureStore store,
  })  : _store = store,
        _pinAuth = PlexPinAuth(),
        _homeUsers = PlexHomeUsersApi(),
        _resources = PlexResourcesApi(),
        _selector = PlexConnectionSelector(),
        super(AuthState.initial());

  Future<String> _ensureClientIdentifier() async {
    if (_clientIdentifier != null && _clientIdentifier!.isNotEmpty) {
      return _clientIdentifier!;
    }

    final existing = await _store.readClientIdentifier();
    if (existing != null && existing.isNotEmpty) {
      _clientIdentifier = existing;
      return existing;
    }

    // Best-effort unique id without extra deps.
    final id = 'plex-kids-${DateTime.now().microsecondsSinceEpoch}';
    await _store.writeClientIdentifier(id);
    _clientIdentifier = id;
    return id;
  }

  Future<void> restore() async {
    _clientIdentifier = await _store.readClientIdentifier();

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

  Future<void> signIn() async {
    state = state.copyWith(isLoading: true, error: null, linkCode: null);

    try {
      final clientIdentifier = await _ensureClientIdentifier();

      // 1) Create PIN (show code to user)
      final pin = await _pinAuth.createPin(clientIdentifier: clientIdentifier);
      state = state.copyWith(linkCode: pin.code.toUpperCase());

      // 2) Open browser to link page (user enters code)
      final url = _pinAuth.buildAuthUrl(pin: pin, clientIdentifier: clientIdentifier);
      final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (!ok) throw StateError('Could not open browser for Plex login');

      // 3) Poll for account token
      final accountToken = await _pinAuth.pollForAuthToken(pin: pin, clientIdentifier: clientIdentifier);
      await _store.writeAccountToken(accountToken);

      // 3) List home users (main + managed users)
      final users = await _homeUsers.listUsers(accountToken: accountToken);
      if (users.isEmpty) throw StateError('No Plex Home users returned.');

      state = state.copyWith(
        isLoading: false,
        accountToken: accountToken,
        homeUsers: users,
        linkCode: null,
      );
    } catch (e) {
      // Do not rethrow: keep the UI alive and show the error message.
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> selectHomeUser({required String userId, String? pin}) async {
    final accountToken = state.accountToken;
    if (accountToken == null || accountToken.isEmpty) {
      throw StateError('Not signed in');
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      // 1) Switch to selected user (managed user may require PIN)
      final userToken = await _homeUsers.switchUser(
        accountToken: accountToken,
        userId: userId,
        pin: pin,
      );
      await _store.writeUserToken(userToken);

      // 2) Discover servers (assume one server for MVP)
      final servers = await _resources.listServers(token: userToken);
      if (servers.isEmpty) throw StateError('No Plex servers found for this account');
      final server = servers.first;

      // 3) Choose best connection (local first, but short timeouts)
      final candidates = server.connections.map((c) => (c.uri, c.local)).toList(growable: false);
      final best = await _selector.chooseBest(
        candidates: candidates,
        token: userToken,
        localTimeout: const Duration(seconds: 3),
        remoteTimeout: const Duration(seconds: 8),
      );

      await _store.writeServerSelection(machineId: server.machineIdentifier, baseUrl: best.baseUrl);

      state = state.copyWith(
        isLoading: false,
        userToken: userToken,
        serverName: server.name,
        serverMachineId: server.machineIdentifier,
        serverBaseUrl: best.baseUrl,
      );
    } catch (e) {
      // Do not rethrow: keep the UI alive and show the error message.
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> signOut() async {
    await _store.clearAll();
    state = AuthState.initial();
  }
}

// (removed unused helper)
