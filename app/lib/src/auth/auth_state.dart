import '../plex/plex_home_users.dart';

class AuthState {
  final bool isLoading;
  final String? error;

  final String? accountToken;
  final String? userToken;

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
    this.accountToken,
    this.userToken,
    this.linkCode,
    this.homeUsers = const [],
    this.serverName,
    this.serverMachineId,
    this.serverBaseUrl,
  });

  factory AuthState.initial() => const AuthState(isLoading: false);

  AuthState copyWith({
    bool? isLoading,
    String? error,
    String? accountToken,
    String? userToken,
    String? linkCode,
    List<PlexHomeUser>? homeUsers,
    String? serverName,
    String? serverMachineId,
    String? serverBaseUrl,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      accountToken: accountToken ?? this.accountToken,
      userToken: userToken ?? this.userToken,
      linkCode: linkCode ?? this.linkCode,
      homeUsers: homeUsers ?? this.homeUsers,
      serverName: serverName ?? this.serverName,
      serverMachineId: serverMachineId ?? this.serverMachineId,
      serverBaseUrl: serverBaseUrl ?? this.serverBaseUrl,
    );
  }
}
