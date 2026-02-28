import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../connection/connection_selector.dart';
import '../plex/plex_home_users.dart';
import '../plex/plex_pin_auth.dart';
import '../plex/plex_resources.dart';
import '../storage/secure_store.dart';
import 'auth_state.dart';
import 'pending_pin.dart';

class AuthController extends StateNotifier<AuthState> {
  final SecureStore _store;

  final PlexPinAuth _pinAuth;
  final PlexHomeUsersApi _homeUsers;
  final PlexResourcesApi _resources;
  final PlexConnectionSelector _selector;

  String? _clientIdentifier;
  PendingPin? _pendingPin;

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

    // Best-effort: load home users so profile switcher works after app restart.
    if (account != null && account.isNotEmpty) {
      await loadHomeUsers();
    }
  }

  Future<void> loadHomeUsers() async {
    final accountToken = state.accountToken;
    if (accountToken == null || accountToken.isEmpty) return;

    try {
      final users = await _homeUsers.listUsers(accountToken: accountToken);
      if (users.isEmpty) return;

      // Pick a reasonable active user if we don't have one.
      final activeId = state.activeUserId ?? users.first.id;
      final active = users.where((u) => u.id == activeId).firstOrNull ?? users.first;

      state = state.copyWith(
        homeUsers: users,
        activeUserId: active.id,
        activeUserTitle: active.title,
        activeUserThumb: active.thumb,
      );
    } catch (e) {
      // Don't block app startup for this.
      state = state.copyWith(error: e.toString());
    }
  }

  /// Step 1: Generate a link code (do not open browser, do not poll).
  Future<void> generateLinkCode() async {
    if (state.isLoading) return;

    state = state.copyWith(isLoading: true, error: null, linkCode: null, awaitingLink: false);

    try {
      final clientIdentifier = await _ensureClientIdentifier();
      final pin = await _pinAuth.createPin(clientIdentifier: clientIdentifier);

      _pendingPin = PendingPin(pin: pin, clientIdentifier: clientIdentifier);

      state = state.copyWith(
        isLoading: false,
        linkCode: pin.code.toUpperCase(),
        awaitingLink: true,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Step 2: Open plex.tv/link in the browser.
  Future<void> openLinkPage() async {
    final pending = _pendingPin;
    if (pending == null) return;

    final url = _pinAuth.buildAuthUrl(pin: pending.pin, clientIdentifier: pending.clientIdentifier);
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  /// Step 3: Poll until the account token is available.
  Future<void> startPollingForAccountToken() async {
    final pending = _pendingPin;
    if (pending == null) {
      state = state.copyWith(error: 'No link code. Generate a new code first.');
      return;
    }

    if (state.isLoading) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      final accountToken = await _pinAuth.pollForAuthToken(
        pin: pending.pin,
        clientIdentifier: pending.clientIdentifier,
      );
      await _store.writeAccountToken(accountToken);

      final users = await _homeUsers.listUsers(accountToken: accountToken);
      if (users.isEmpty) throw StateError('No Plex Home users returned.');

      _pendingPin = null;
      state = state.copyWith(
        isLoading: false,
        accountToken: accountToken,
        homeUsers: users,
        linkCode: null,
        awaitingLink: false,
        // Default to the first user (usually the main account) until a profile
        // is explicitly selected.
        activeUserId: users.first.id,
        activeUserTitle: users.first.title,
        activeUserThumb: users.first.thumb,
      );
    } catch (e) {
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
      // 1) Switch to selected user.
      // For the main (non-managed) account user, we do NOT need to switch; the
      // account token already represents that user.
      final selected = state.homeUsers.where((u) => u.id == userId).firstOrNull;
      if (selected == null) throw StateError('Unknown user');

      final userToken = !selected.isManaged
          ? accountToken
          : await _homeUsers.switchUser(
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
        activeUserId: selected.id,
        activeUserTitle: selected.title,
        activeUserThumb: selected.thumb,
        serverName: server.name,
        serverMachineId: server.machineIdentifier,
        serverBaseUrl: best.baseUrl,
      );
    } catch (e) {
      // Do not rethrow: keep the UI alive and show the error message.
      state = state.copyWith(isLoading: false, error: PlexHomeUsersApi.describeSwitchError(e));
    }
  }

  Future<void> signOut() async {
    _pendingPin = null;
    await _store.clearAll();
    state = AuthState.initial();
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
