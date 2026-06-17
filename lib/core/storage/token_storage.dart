import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists the JWT access token in the platform secure store.
/// Windows → Windows Credential Manager
/// Android → Android Keystore
/// iOS/macOS → Keychain
class TokenStorage {
  TokenStorage._();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const _keyToken = 'pmg_auth_token';

  static Future<void> saveToken(String token) =>
      _storage.write(key: _keyToken, value: token);

  static Future<String?> getToken() => _storage.read(key: _keyToken);

  static Future<void> clearToken() => _storage.delete(key: _keyToken);

  static Future<bool> hasToken() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }
}
