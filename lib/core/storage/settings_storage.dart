import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../models/ai_mode.dart';

/// Persists non-sensitive user settings (e.g. preferred AI mode).
class SettingsStorage {
  SettingsStorage._();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const _keyAiMode = 'pmg_ai_mode';

  static Future<void> saveAiMode(AiMode mode) =>
      _storage.write(key: _keyAiMode, value: mode.name);

  /// Returns the saved AiMode, defaulting to [AiMode.backend] for demo readiness.
  static Future<AiMode> loadAiMode() async {
    try {
      final value = await _storage.read(key: _keyAiMode);
      if (value == null) return AiMode.backend;
      return AiMode.values.firstWhere(
        (m) => m.name == value,
        orElse: () => AiMode.backend,
      );
    } catch (_) {
      return AiMode.backend;
    }
  }
}
