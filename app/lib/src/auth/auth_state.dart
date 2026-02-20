import '../plex/plex_home_users.dart';

class AuthState {
  final bool isLoading;
  final String? error;

  final String? accountToken;
  final String? userToken;

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
      homeUsers: homeUsers ?? this.homeUsers,
      serverName: serverName ?? this.serverName,
      serverMachineId: serverMachineId ?? this.serverMachineId,
      serverBaseUrl: serverBaseUrl ?? this.serverBaseUrl,
    );
  }
}
