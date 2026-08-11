import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Where the data-encryption key lives.
///
/// On device this is backed by the platform keystore (Keychain on iOS,
/// EncryptedSharedPreferences/StrongBox on Android). Tests substitute an
/// in-memory implementation.
abstract interface class KeyStore {
  Future<String?> read(String name);
  Future<void> write(String name, String value);
  Future<void> delete(String name);
}

/// In-memory key store for tests and the offline demo build.
class InMemoryKeyStore implements KeyStore {
  final Map<String, String> _values = <String, String>{};

  @override
  Future<String?> read(String name) async => _values[name];

  @override
  Future<void> write(String name, String value) async => _values[name] = value;

  @override
  Future<void> delete(String name) async => _values.remove(name);
}

/// Authenticated encryption for health data at rest.
///
/// AES-256-GCM. Every record gets a fresh 96-bit nonce, and the MAC is
/// verified on read, so a tampered or truncated record fails loudly rather
/// than decrypting to garbage.
///
/// The threat model this addresses is a device backup, a filesystem dump or
/// a shared/rooted device - not a live attacker with debugger access, which
/// no client-side scheme defends against. See `docs/SECURITY_PRIVACY.md`.
class CryptoBox {
  CryptoBox._(this._algorithm, this._key);

  static const String _keyName = 'vitalrise.data_key.v1';
  static const int _nonceLength = 12;

  final AesGcm _algorithm;
  final SecretKey _key;

  /// Loads the device key, generating one on first run.
  static Future<CryptoBox> open(KeyStore store) async {
    final AesGcm algorithm = AesGcm.with256bits();

    final String? existing = await store.read(_keyName);
    if (existing != null) {
      // A malformed or wrong-length key means stored records are unreadable
      // either way; rotating is strictly better than crashing on every read
      // and locking the user out of the app permanently.
      try {
        final Uint8List bytes = base64Decode(existing);
        if (bytes.length == 32) {
          return CryptoBox._(algorithm, SecretKey(bytes));
        }
      } on FormatException {
        // Fall through and generate a fresh key.
      }
    }

    final SecretKey key = await algorithm.newSecretKey();
    final List<int> bytes = await key.extractBytes();
    await store.write(_keyName, base64Encode(bytes));
    return CryptoBox._(algorithm, key);
  }

  /// Encrypts [plaintext] into a self-contained base64 envelope of
  /// `nonce || ciphertext || mac`.
  Future<String> encrypt(String plaintext) async {
    final List<int> nonce = _randomNonce();
    final SecretBox box = await _algorithm.encrypt(
      utf8.encode(plaintext),
      secretKey: _key,
      nonce: nonce,
    );
    return base64Encode(<int>[
      ...box.nonce,
      ...box.cipherText,
      ...box.mac.bytes,
    ]);
  }

  /// Reverses [encrypt]. Returns null when the payload is corrupt, was
  /// written with a different key, or fails authentication.
  Future<String?> decrypt(String payload) async {
    try {
      final Uint8List raw = base64Decode(payload);
      final int macLength = _algorithm.macAlgorithm.macLength;
      // An empty plaintext is legitimate and encrypts to exactly
      // nonce + mac with no body, so this bound must not be inclusive.
      if (raw.length < _nonceLength + macLength) return null;

      final SecretBox box = SecretBox(
        raw.sublist(_nonceLength, raw.length - macLength),
        nonce: raw.sublist(0, _nonceLength),
        mac: Mac(raw.sublist(raw.length - macLength)),
      );
      return utf8.decode(await _algorithm.decrypt(box, secretKey: _key));
    } on Object {
      return null;
    }
  }

  /// Destroys the key, rendering every stored record permanently
  /// unreadable. This is how "delete my data" is honoured locally, and it
  /// is why it cannot be undone.
  static Future<void> destroyKey(KeyStore store) => store.delete(_keyName);

  static List<int> _randomNonce() {
    final Random random = Random.secure();
    return List<int>.generate(_nonceLength, (_) => random.nextInt(256));
  }
}
