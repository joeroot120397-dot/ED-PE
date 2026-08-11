import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vitalrise/core/security/crypto_box.dart';

void main() {
  group('CryptoBox', () {
    late InMemoryKeyStore keys;

    setUp(() => keys = InMemoryKeyStore());

    test('round-trips a payload', () async {
      final CryptoBox box = await CryptoBox.open(keys);
      const String plain = '{"b_achieve":"few","a_age":42}';
      expect(await box.decrypt(await box.encrypt(plain)), plain);
    });

    test('round-trips unicode and empty strings', () async {
      final CryptoBox box = await CryptoBox.open(keys);
      for (final String plain in <String>[
        '',
        'café — 🔥 ünïcode',
        'a' * 20000,
      ]) {
        expect(await box.decrypt(await box.encrypt(plain)), plain);
      }
    });

    test('ciphertext does not leak the plaintext', () async {
      final CryptoBox box = await CryptoBox.open(keys);
      final String payload = await box.encrypt('erectile dysfunction severe');
      expect(payload, isNot(contains('erectile')));
      expect(payload, isNot(contains('severe')));
    });

    test('each encryption uses a fresh nonce', () async {
      final CryptoBox box = await CryptoBox.open(keys);
      final String a = await box.encrypt('same input');
      final String b = await box.encrypt('same input');
      expect(a, isNot(b), reason: 'a repeated nonce would leak equality');
      expect(await box.decrypt(a), 'same input');
      expect(await box.decrypt(b), 'same input');
    });

    test('the key persists across instances', () async {
      final CryptoBox first = await CryptoBox.open(keys);
      final String payload = await first.encrypt('persisted');

      final CryptoBox second = await CryptoBox.open(keys);
      expect(await second.decrypt(payload), 'persisted');
    });

    test('a different key cannot read the data', () async {
      final CryptoBox mine = await CryptoBox.open(keys);
      final String payload = await mine.encrypt('private');

      final CryptoBox theirs = await CryptoBox.open(InMemoryKeyStore());
      expect(await theirs.decrypt(payload), isNull);
    });

    test(
      'tampering is detected by the MAC rather than silently decoded',
      () async {
        final CryptoBox box = await CryptoBox.open(keys);
        final List<int> raw = base64Decode(await box.encrypt('trustworthy'));

        // Flip one bit in the ciphertext body.
        raw[20] = raw[20] ^ 0x01;
        expect(await box.decrypt(base64Encode(raw)), isNull);
      },
    );

    test(
      'truncated and malformed payloads return null, not an exception',
      () async {
        final CryptoBox box = await CryptoBox.open(keys);
        final String payload = await box.encrypt('something');

        expect(await box.decrypt(payload.substring(0, 12)), isNull);
        expect(await box.decrypt('not base64 at all !!!'), isNull);
        expect(await box.decrypt(''), isNull);
      },
    );

    test('destroying the key makes existing data unreadable', () async {
      final CryptoBox box = await CryptoBox.open(keys);
      final String payload = await box.encrypt('to be forgotten');

      await CryptoBox.destroyKey(keys);

      // A fresh open generates a new key, so the old record is gone for good.
      final CryptoBox rebuilt = await CryptoBox.open(keys);
      expect(await rebuilt.decrypt(payload), isNull);
    });

    test('a corrupt stored key rotates instead of crashing', () async {
      await keys.write('vitalrise.data_key.v1', 'not-a-valid-key');
      final CryptoBox box = await CryptoBox.open(keys);
      expect(await box.decrypt(await box.encrypt('recovered')), 'recovered');
    });

    test('the generated key is 256 bits', () async {
      await CryptoBox.open(keys);
      final String? stored = await keys.read('vitalrise.data_key.v1');
      expect(stored, isNotNull);
      expect(base64Decode(stored!).length, 32);
    });
  });
}
