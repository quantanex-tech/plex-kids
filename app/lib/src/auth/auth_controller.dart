import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../connection/connection_selector.dart';
import '../plex/plex_home_users.dart';
import '../plex/plex_pin_auth.dart';
import '../plex/plex_resources.dart';
import '../plex/plex_tv_user.dart';
import '../storage/secure_store.dart';
import 'auth_state.dart';
import 'pending_pin.dart';

class AuthController extends StateNotifier<AuthState> {
  final SecureStore _store;

  final PlexPinAuth _pinAuth;
  final PlexHomeUsersApi _homeUsers;
  final PlexResourcesApi _resources;
  final PlexConnectionSelector _selector;
  final PlexTvApi _plexTv;

  String? _clientIdentifier;
  PendingPin? _pendingPin;

  AuthController({
    required SecureStore store,
  })  : _store = store,
        _pinAuth = PlexPinAuth(),
        _homeUsers = PlexHomeUsersApi(),
        _resources = PlexResourcesApi(),
        _selector = PlexConnectionSelector(),
        _plexTv = PlexTvApi(),
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
      final users = await _homeUsers.listUsers(
        accountToken: accountToken,
        clientIdentifier: await _ensureClientIdentifier(),
      );
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

      final users = await _homeUsers.listUsers(
        accountToken: accountToken,
        clientIdentifier: pending.clientIdentifier,
      );
      if (users.isEmpty) throw StateError('No Plex Home users returned.');

      _pendingPin = null;
      final tokenUser = await _plexTv.getUser(token: accountToken);

      state = state.copyWith(
        isLoading: false,
        accountToken: accountToken,
        homeUsers: users,
        linkCode: null,
        awaitingLink: false,
        ownerUserId: users.first.id,
        // Default to owner until a profile is explicitly selected.
        activeUserId: users.first.id,
        activeUserTitle: users.first.title,
        activeUserThumb: users.first.thumb,
        activeTokenUsername: tokenUser.username ?? tokenUser.email ?? tokenUser.title,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> selectHomeUser({required String userId, String? pin}) async {
    final accountToken = state.accountToken;
    if (accountToken == null || accountToken.isEmpty) {
      state = state.copyWith(error: 'Not signed in');
      return false;
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      // 1) Switch to selected user.
      // For the main (non-managed) account user, we do NOT need to switch; the
      // account token already represents that user.
      final selected = state.homeUsers.where((u) => u.id == userId).firstOrNull;
      if (selected == null) throw StateError('Unknown user');

      // Do not rely on plex.tv returning a reliable "managed" flag. In practice
      // for Plex Home the owner token represents only the owner, and all other
      // home users should be switched.
      final ownerId = state.ownerUserId ?? (state.homeUsers.isNotEmpty ? state.homeUsers.first.id : null);
      final shouldSwitch = ownerId == null ? true : selected.id != ownerId;

      final userToken = !shouldSwitch
          ? accountToken
          : await _homeUsers.switchUser(
              accountToken: accountToken,
              userId: userId,
              pin: pin,
              clientIdentifier: await _ensureClientIdentifier(),
            );

      await _store.writeUserToken(userToken);

      final tokenUser = await _plexTv.getUser(token: userToken);

      // If we already have a working server selection, don't redo connection
      // selection during profile switching. Just swap the token and keep the
      // same server URL; this avoids timeouts and keeps switching snappy.
      if (state.serverBaseUrl != null && state.serverMachineId != null) {
        state = state.copyWith(
          isLoading: false,
          userToken: userToken,
          activeUserId: selected.id,
          activeUserTitle: selected.title,
          activeUserThumb: selected.thumb,
          activeTokenUsername: tokenUser.username ?? tokenUser.email ?? tokenUser.title,
        );

        return true;
      }

      // Fallback: discover servers (assume one server for MVP)
      final servers = await _resources.listServers(token: userToken);
      if (servers.isEmpty) throw StateError('No Plex servers found for this account');
      final server = servers.first;

      // Choose best connection (local first, but short timeouts)
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
        activeTokenUsername: tokenUser.username ?? tokenUser.email ?? tokenUser.title,
        serverName: server.name,
        serverMachineId: server.machineIdentifier,
        serverBaseUrl: best.baseUrl,
      );

      return true;
    } catch (e) {
      // Do not rethrow: keep the UI alive and show the error message.
      state = state.copyWith(isLoading: false, error: PlexHomeUsersApi.describeSwitchError(e));
      return false;
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
