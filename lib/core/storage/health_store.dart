import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../security/crypto_box.dart';

/// Key-value persistence where every health value is encrypted at rest.
///
/// Non-health preferences (theme, whether onboarding is done) are stored in
/// the clear so the app can render its first frame without touching the
/// keystore. Anything describing the user's body, symptoms or answers goes
/// through [CryptoBox].
class HealthStore {
  HealthStore(this._prefs, this._crypto);

  static Future<HealthStore> open({KeyStore? keyStore}) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final CryptoBox crypto = await CryptoBox.open(
      keyStore ?? const PlatformKeyStore(),
    );
    return HealthStore(prefs, crypto);
  }

  final SharedPreferences _prefs;
  final CryptoBox _crypto;

  // ---- Encrypted health data ----------------------------------------

  Future<void> writeJson(String key, Map<String, dynamic> value) async {
    final String payload = await _crypto.encrypt(jsonEncode(value));
    await _prefs.setString(_healthKey(key), payload);
  }

  Future<Map<String, dynamic>?> readJson(String key) async {
    final String? payload = _prefs.getString(_healthKey(key));
    if (payload == null) return null;
    final String? plain = await _crypto.decrypt(payload);
    if (plain == null) return null;
    try {
      return jsonDecode(plain) as Map<String, dynamic>;
    } on FormatException {
      return null;
    }
  }

  Future<void> writeJsonList(
    String key,
    List<Map<String, dynamic>> value,
  ) async {
    final String payload = await _crypto.encrypt(jsonEncode(value));
    await _prefs.setString(_healthKey(key), payload);
  }

  Future<List<Map<String, dynamic>>> readJsonList(String key) async {
    final String? payload = _prefs.getString(_healthKey(key));
    if (payload == null) return const <Map<String, dynamic>>[];
    final String? plain = await _crypto.decrypt(payload);
    if (plain == null) return const <Map<String, dynamic>>[];
    try {
      final Object? decoded = jsonDecode(plain);
      if (decoded is! List) return const <Map<String, dynamic>>[];
      return decoded.whereType<Map<String, dynamic>>().toList(growable: false);
    } on FormatException {
      return const <Map<String, dynamic>>[];
    }
  }

  Future<void> remove(String key) => _prefs.remove(_healthKey(key));

  // ---- Plain preferences ---------------------------------------------

  bool getFlag(String key, {bool fallback = false}) =>
      _prefs.getBool('pref.$key') ?? fallback;

  Future<void> setFlag(String key, {required bool value}) =>
      _prefs.setBool('pref.$key', value);

  String? getString(String key) => _prefs.getString('pref.$key');

  Future<void> setString(String key, String value) =>
      _prefs.setString('pref.$key', value);

  /// Wipes every VitalRise key. Used by "delete my data" and on sign-out.
  Future<void> clearAll() async {
    final Set<String> keys = _prefs
        .getKeys()
        .where((String k) => k.startsWith('health.') || k.startsWith('pref.'))
        .toSet();
    for (final String key in keys) {
      await _prefs.remove(key);
    }
  }

  static String _healthKey(String key) => 'health.$key';

  // Keys used across the app, in one place so they cannot drift.
  static const String kResponses = 'assessment.responses';
  static const String kResult = 'assessment.result';
  static const String kProgramStart = 'program.started_on';
  static const String kHabitLogs = 'habits.logs';
  static const String kProgressEntries = 'progress.entries';
  static const String kDietPreferences = 'diet.preferences';
  static const String kChatHistory = 'coach.history';
}

/// [KeyStore] backed by the platform keychain / keystore.
///
/// Android uses AES-GCM under an RSA-wrapped keystore key; iOS is pinned to
/// `first_unlock_this_device`, so the key never leaves the device in an
/// iCloud backup and is unavailable before first unlock.
class PlatformKeyStore implements KeyStore {
  const PlatformKeyStore();

  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      storageCipherAlgorithm: StorageCipherAlgorithm.AES_GCM_NoPadding,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  @override
  Future<String?> read(String name) => _storage.read(key: name);

  @override
  Future<void> write(String name, String value) =>
      _storage.write(key: name, value: value);

  @override
  Future<void> delete(String name) => _storage.delete(key: name);
}
