class AuthState {
  final bool isLoading;
  final String? error;

  final String? accountToken;
  final String? userToken;

  final String? serverName;
  final String? serverMachineId;
  final String? serverBaseUrl;

  const AuthState({
    required this.isLoading,
    this.error,
    this.accountToken,
    this.userToken,
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
    String? serverName,
    String? serverMachineId,
    String? serverBaseUrl,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      accountToken: accountToken ?? this.accountToken,
      userToken: userToken ?? this.userToken,
      serverName: serverName ?? this.serverName,
      serverMachineId: serverMachineId ?? this.serverMachineId,
      serverBaseUrl: serverBaseUrl ?? this.serverBaseUrl,
    );
  }
}
