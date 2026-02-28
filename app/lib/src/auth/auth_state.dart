import '../plex/plex_home_users.dart';

class AuthState {
  final bool isLoading;
  final String? error;

  /// If true, a link code has been generated and we are waiting for the user
  /// to link the device + start/continue polling.
  final bool awaitingLink;

  final String? accountToken;
  final String? userToken;

  final String? activeUserId;
  final String? activeUserTitle;
  final String? activeUserThumb;

  /// When signing in via device PIN flow, this is the code to enter on plex.tv/link.
  final String? linkCode;

  /// Available Plex Home users (main + managed users).
  final List<PlexHomeUser> homeUsers;

  final String? serverName;
  final String? serverMachineId;
  final String? serverBaseUrl;

  const AuthState({
    required this.isLoading,
    this.error,
    this.awaitingLink = false,
    this.accountToken,
    this.userToken,
    this.activeUserId,
    this.activeUserTitle,
    this.activeUserThumb,
    this.linkCode,
    this.homeUsers = const [],
    this.serverName,
    this.serverMachineId,
    this.serverBaseUrl,
  });

  factory AuthState.initial() => const AuthState(isLoading: false, awaitingLink: false);

  AuthState copyWith({
    bool? isLoading,
    String? error,
    bool? awaitingLink,
    String? accountToken,
    String? userToken,
    String? activeUserId,
    String? activeUserTitle,
    String? activeUserThumb,
    String? linkCode,
    List<PlexHomeUser>? homeUsers,
    String? serverName,
    String? serverMachineId,
    String? serverBaseUrl,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      awaitingLink: awaitingLink ?? this.awaitingLink,
      accountToken: accountToken ?? this.accountToken,
      userToken: userToken ?? this.userToken,
      activeUserId: activeUserId ?? this.activeUserId,
      activeUserTitle: activeUserTitle ?? this.activeUserTitle,
      activeUserThumb: activeUserThumb ?? this.activeUserThumb,
      linkCode: linkCode ?? this.linkCode,
      homeUsers: homeUsers ?? this.homeUsers,
      serverName: serverName ?? this.serverName,
      serverMachineId: serverMachineId ?? this.serverMachineId,
      serverBaseUrl: serverBaseUrl ?? this.serverBaseUrl,
    );
  }
}
