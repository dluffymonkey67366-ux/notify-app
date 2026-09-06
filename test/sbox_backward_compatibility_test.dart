import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:notify_app/services/crypto_utils.dart';
import 'package:notify_app/services/encrypted_cache_service.dart';

/// Exact implementation of Aes256Cbc with the PRE-FIX S-box bug (0x5e at index 167 instead of 0x5c)
class OldBrokenAes256Cbc {
  static const int blockSize = 16;
  static const int keySize = 32;
  static const int rounds = 14;

  static const List<int> _brokenSBox = [
    0x63, 0x7c, 0x77, 0x7b, 0xf2, 0x6b, 0x6f, 0xc5, 0x30, 0x01, 0x67, 0x2b, 0xfe, 0xd7, 0xab, 0x76,
    0xca, 0x82, 0xc9, 0x7d, 0xfa, 0x59, 0x47, 0xf0, 0xad, 0xd4, 0xa2, 0xaf, 0x9c, 0xa4, 0x72, 0xc0,
    0xb7, 0xfd, 0x93, 0x26, 0x36, 0x3f, 0xf7, 0xcc, 0x34, 0xa5, 0xe5, 0xf1, 0x71, 0xd8, 0x31, 0x15,
    0x04, 0xc7, 0x23, 0xc3, 0x18, 0x96, 0x05, 0x9a, 0x07, 0x12, 0x80, 0xe2, 0xeb, 0x27, 0xb2, 0x75,
    0x09, 0x83, 0x2c, 0x1a, 0x1b, 0x6e, 0x5a, 0xa0, 0x52, 0x3b, 0xd6, 0xb3, 0x29, 0xe3, 0x2f, 0x84,
    0x53, 0xd1, 0x00, 0xed, 0x20, 0xfc, 0xb1, 0x5b, 0x6a, 0xcb, 0xbe, 0x39, 0x4a, 0x4c, 0x58, 0xcf,
    0xd0, 0xef, 0xaa, 0xfb, 0x43, 0x4d, 0x33, 0x85, 0x45, 0xf9, 0x02, 0x7f, 0x50, 0x3c, 0x9f, 0xa8,
    0x51, 0xa3, 0x40, 0x8f, 0x92, 0x9d, 0x38, 0xf5, 0xbc, 0xb6, 0xda, 0x21, 0x10, 0xff, 0xf3, 0xd2,
    0xcd, 0x0c, 0x13, 0xec, 0x5f, 0x97, 0x44, 0x17, 0xc4, 0xa7, 0x7e, 0x3d, 0x64, 0x5d, 0x19, 0x73,
    0x60, 0x81, 0x4f, 0xdc, 0x22, 0x2a, 0x90, 0x88, 0x46, 0xee, 0xb8, 0x14, 0xde, 0x5e, 0x0b, 0xdb,
    0xe0, 0x32, 0x3a, 0x0a, 0x49, 0x06, 0x24, 0x5e, 0xc2, 0xd3, 0xac, 0x62, 0x91, 0x95, 0xe4, 0x79, // BUG: 0x5e at index 167
    0xe7, 0xc8, 0x37, 0x6d, 0x8d, 0xd5, 0x4e, 0xa9, 0x6c, 0x56, 0xf4, 0xea, 0x65, 0x7a, 0xae, 0x08,
    0xba, 0x78, 0x25, 0x2e, 0x1c, 0xa6, 0xb4, 0xc6, 0xe8, 0xdd, 0x74, 0x1f, 0x4b, 0xbd, 0x8b, 0x8a,
    0x70, 0x3e, 0xb5, 0x66, 0x48, 0x03, 0xf6, 0x0e, 0x61, 0x35, 0x57, 0xb9, 0x86, 0xc1, 0x1d, 0x9e,
    0xe1, 0xf8, 0x98, 0x11, 0x69, 0xd9, 0x8e, 0x94, 0x9b, 0x1e, 0x87, 0xe9, 0xce, 0x55, 0x28, 0xdf,
    0x8c, 0xa1, 0x89, 0x0d, 0xbf, 0xe6, 0x42, 0x68, 0x41, 0x99, 0x2d, 0x0f, 0xb0, 0x54, 0xbb, 0x16
  ];

  static const List<int> _rcon = [
    0x00, 0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x80, 0x1b, 0x36
  ];

  static int _gMul(int a, int b) {
    int p = 0;
    for (int i = 0; i < 8; i++) {
      if ((b & 1) != 0) p ^= a;
      bool hi = (a & 0x80) != 0;
      a = (a << 1) & 0xff;
      if (hi) a ^= 0x1b;
      b >>= 1;
    }
    return p;
  }

  static Uint32List _expandKey(Uint8List key) {
    final w = Uint32List(60);
    final byteData = ByteData.sublistView(key);
    for (int i = 0; i < 8; i++) {
      w[i] = byteData.getUint32(i * 4, Endian.big);
    }
    for (int i = 8; i < 60; i++) {
      int temp = w[i - 1];
      if (i % 8 == 0) {
        temp = ((temp << 8) | (temp >>> 24)) & 0xffffffff;
        temp = (_brokenSBox[(temp >>> 24) & 0xff] << 24) |
               (_brokenSBox[(temp >>> 16) & 0xff] << 16) |
               (_brokenSBox[(temp >>> 8) & 0xff] << 8) |
               _brokenSBox[temp & 0xff];
        temp ^= (_rcon[i ~/ 8] << 24);
      } else if (i % 8 == 4) {
        temp = (_brokenSBox[(temp >>> 24) & 0xff] << 24) |
               (_brokenSBox[(temp >>> 16) & 0xff] << 16) |
               (_brokenSBox[(temp >>> 8) & 0xff] << 8) |
               _brokenSBox[temp & 0xff];
      }
      w[i] = (w[i - 8] ^ temp) & 0xffffffff;
    }
    return w;
  }

  static void _encryptBlock(Uint8List block, Uint32List w, Uint8List out) {
    var state = List<int>.from(block);
    void addRoundKey(int round) {
      for (int c = 0; c < 4; c++) {
        final word = w[round * 4 + c];
        state[c * 4 + 0] ^= (word >>> 24) & 0xff;
        state[c * 4 + 1] ^= (word >>> 16) & 0xff;
        state[c * 4 + 2] ^= (word >>> 8) & 0xff;
        state[c * 4 + 3] ^= word & 0xff;
      }
    }
    void subBytes() {
      for (int i = 0; i < 16; i++) {
        state[i] = _brokenSBox[state[i]];
      }
    }
    void shiftRows() {
      final t = List<int>.from(state);
      state[1] = t[5]; state[5] = t[9]; state[9] = t[13]; state[13] = t[1];
      state[2] = t[10]; state[6] = t[14]; state[10] = t[2]; state[14] = t[6];
      state[3] = t[15]; state[7] = t[3]; state[11] = t[7]; state[15] = t[11];
    }
    void mixColumns() {
      for (int c = 0; c < 4; c++) {
        final i = c * 4;
        final a0 = state[i], a1 = state[i + 1], a2 = state[i + 2], a3 = state[i + 3];
        state[i + 0] = _gMul(0x02, a0) ^ _gMul(0x03, a1) ^ a2 ^ a3;
        state[i + 1] = a0 ^ _gMul(0x02, a1) ^ _gMul(0x03, a2) ^ a3;
        state[i + 2] = a0 ^ a1 ^ _gMul(0x02, a2) ^ _gMul(0x03, a3);
        state[i + 3] = _gMul(0x03, a0) ^ a1 ^ a2 ^ _gMul(0x02, a3);
      }
    }
    addRoundKey(0);
    for (int r = 1; r < rounds; r++) {
      subBytes();
      shiftRows();
      mixColumns();
      addRoundKey(r);
    }
    subBytes();
    shiftRows();
    addRoundKey(rounds);
    for (int i = 0; i < 16; i++) {
      out[i] = state[i];
    }
  }

  static Uint8List encrypt({
    required Uint8List plainBytes,
    required Uint8List key,
    required Uint8List iv,
  }) {
    final expandedKey = _expandKey(key);
    final padLength = blockSize - (plainBytes.length % blockSize);
    final padded = Uint8List(plainBytes.length + padLength);
    padded.setRange(0, plainBytes.length, plainBytes);
    for (int i = plainBytes.length; i < padded.length; i++) {
      padded[i] = padLength;
    }
    final output = Uint8List(padded.length);
    var prevBlock = Uint8List.fromList(iv);
    final currentBlock = Uint8List(blockSize);
    final encryptedBlock = Uint8List(blockSize);
    for (int offset = 0; offset < padded.length; offset += blockSize) {
      for (int i = 0; i < blockSize; i++) {
        currentBlock[i] = padded[offset + i] ^ prevBlock[i];
      }
      _encryptBlock(currentBlock, expandedKey, encryptedBlock);
      output.setRange(offset, offset + blockSize, encryptedBlock);
      prevBlock = Uint8List.fromList(encryptedBlock);
    }
    return output;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AES S-Box Incompatibility & Cache Invalidation Tests', () {
    test('Content encrypted with old broken S-box produces different ciphertext and fails under fixed AES', () {
      final key = Uint8List.fromList(List.generate(32, (i) => (i * 17 + 5) % 256));
      final iv = Uint8List.fromList(List.generate(16, (i) => (i * 3 + 1) % 256));

      const sampleHtml =
          '<h1>Direct Taxation</h1><p>Comprehensive study material covering Section 44AB tax audit threshold and corporate taxation provisions for CA Final exam preparation.</p>';
      final plainBytes = Uint8List.fromList(utf8.encode(sampleHtml));

      // 1. Encrypt with old broken S-box (as was on disk before the fix)
      final oldCiphertext = OldBrokenAes256Cbc.encrypt(
        plainBytes: plainBytes,
        key: key,
        iv: iv,
      );

      // 2. Encrypt with new fixed S-box
      final newCiphertext = Aes256Cbc.encrypt(
        plainBytes: plainBytes,
        key: key,
        iv: iv,
      );

      // Ciphertexts diverge due to the S-box substitution difference
      expect(listEquals(oldCiphertext, newCiphertext), false);

      // 3. Attempting to decrypt old ciphertext with fixed AES fails (throws FormatException)
      expect(
        () => Aes256Cbc.decrypt(
          cipherBytes: oldCiphertext,
          key: key,
          iv: iv,
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('ensureCacheVersionMigrated purges legacy v1 cache directory and upgrades stored version to v2', () async {
      SharedPreferences.setMockInitialValues({
        'notify_encrypted_cache_schema_version': 1,
      });

      final tempDir = await Directory.systemTemp.createTemp('notify_v1_cache_test_');
      final cacheService = EncryptedCacheService();
      cacheService.setCustomCacheDir(tempDir.path);
      cacheService.resetMigrationForTesting();

      // Create dummy old encrypted files in the cache directory
      final dummyOldFile = File('${tempDir.path}/ca_final_law.enc');
      await dummyOldFile.writeAsString('stale_broken_encrypted_payload');
      expect(await dummyOldFile.exists(), true);

      // Trigger migration
      await cacheService.ensureCacheVersionMigrated();

      // Verify directory was wiped and recreated fresh
      expect(await dummyOldFile.exists(), false);

      // Verify SharedPreferences updated to version 2
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('notify_encrypted_cache_schema_version'), EncryptedCacheService.currentCacheVersion);

      // Cleanup
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('readDecryptedContent auto-purges corrupt/incompatible cache file and returns null for transparent re-fetch', () async {
      SharedPreferences.setMockInitialValues({
        'notify_encrypted_cache_schema_version': 2,
      });

      final tempDir = await Directory.systemTemp.createTemp('notify_purge_test_');
      final cacheService = EncryptedCacheService();
      cacheService.setCustomCacheDir(tempDir.path);
      cacheService.resetMigrationForTesting();

      // Plant a broken/corrupt ciphertext file simulating old S-box encryption
      final corruptFile = File('${tempDir.path}/part_corrupt_123.enc');
      // 16-byte IV + random garbage bytes
      final garbageBytes = Uint8List.fromList(List.generate(64, (i) => (i * 13) % 256));
      await corruptFile.writeAsBytes(garbageBytes);
      expect(await corruptFile.exists(), true);

      // readDecryptedContent should catch the decryption failure, purge the bad file, and return null
      final result = await cacheService.readDecryptedContent('part_corrupt_123');
      expect(result, isNull);
      expect(await corruptFile.exists(), false); // Purged!

      // Cleanup
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });
  });
}
