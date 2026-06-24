import 'package:flutter/foundation.dart';
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

  /// Returns [AiMode.backend] always.
  ///
  /// This app is a backend-integrated demo: all grading is done server-side
  /// and the teacher must not configure an OpenRouter/Gemini API key in the
  /// frontend.  If an old session stored `openRouter`, `gemini`, or `mock`,
  /// that legacy value is migrated to `backend` on the first read.
  static Future<AiMode> loadAiMode() async {
    try {
      final value = await _storage.read(key: _keyAiMode);
      if (value == 'backend') {
        debugPrint('[SettingsStorage] loadAiMode: backend (already set)');
        return AiMode.backend;
      }
      // Migrate any legacy value (openRouter / gemini / mock / null)
      debugPrint('[SettingsStorage] loadAiMode: migrating "$value" → backend');
      await _storage.write(key: _keyAiMode, value: 'backend');
      return AiMode.backend;
    } catch (_) {
      return AiMode.backend;
    }
  }
}
