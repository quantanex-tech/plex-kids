import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStore {
  static const _kAccountToken = 'plex.accountToken';
  static const _kUserToken = 'plex.userToken';
  static const _kServerMachineId = 'plex.serverMachineId';
  static const _kServerBaseUrl = 'plex.serverBaseUrl';

  final FlutterSecureStorage _storage;

  const SecureStore(this._storage);

  Future<String?> readAccountToken() => _storage.read(key: _kAccountToken);
  Future<void> writeAccountToken(String token) => _storage.write(key: _kAccountToken, value: token);

  Future<String?> readUserToken() => _storage.read(key: _kUserToken);
  Future<void> writeUserToken(String token) => _storage.write(key: _kUserToken, value: token);

  Future<void> writeServerSelection({required String machineId, required String baseUrl}) async {
    await _storage.write(key: _kServerMachineId, value: machineId);
    await _storage.write(key: _kServerBaseUrl, value: baseUrl);
  }

  Future<String?> readServerMachineId() => _storage.read(key: _kServerMachineId);
  Future<String?> readServerBaseUrl() => _storage.read(key: _kServerBaseUrl);

  Future<void> clearAll() => _storage.deleteAll();
}
