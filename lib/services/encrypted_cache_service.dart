import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/reader_annotation_models.dart';
import 'crypto_utils.dart';

/// EncryptedCacheService handles local offline caching of HTML note content.
///
/// Security non-negotiable:
/// - Content is stored on disk strictly encrypted via AES-256-CBC with PKCS7 padding.
/// - The 256-bit encryption key is securely generated and hardware-bound in FlutterSecureStorage.
/// - Any attempt to inspect or decode the disk file directly produces high-entropy encrypted
///   binary data or UTF-8 decode failure, rendering the file completely unreadable without
///   the derived key in secure storage.
class EncryptedCacheService {
  static final EncryptedCacheService _instance = EncryptedCacheService._internal();
  factory EncryptedCacheService() => _instance;
  EncryptedCacheService._internal();

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  static const String _storageKeyAes = 'notify_note_encryption_key_aes256';

  /// Current schema version for offline AES-encrypted cache files.
  /// Version 1: Legacy cache created prior to the FIPS-197 AES S-box fix.
  /// Version 2: Standard AES-256 cache with corrected bijective S-box.
  static const int currentCacheVersion = 2;
  static const String _cacheVersionKey = 'notify_encrypted_cache_schema_version';

  Uint8List? _cachedKey;
  String? _customCacheDirPath;
  bool _migrationChecked = false;

  @visibleForTesting
  void setCustomCacheDir(String path) {
    _customCacheDirPath = path;
  }

  @visibleForTesting
  void setCustomKey(Uint8List key) {
    _cachedKey = key;
  }

  @visibleForTesting
  void resetMigrationForTesting() {
    _migrationChecked = false;
  }

  /// One-time cache migration: Invalidate and purge stale AES encrypted files
  /// created prior to the FIPS-197 AES S-box fix (v1 -> v2).
  Future<void> ensureCacheVersionMigrated() async {
    if (_migrationChecked) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedVersion = prefs.getInt(_cacheVersionKey) ?? 1;
      if (storedVersion < currentCacheVersion) {
        debugPrint(
          'EncryptedCacheService: Upgrading cache from v$storedVersion to v$currentCacheVersion. '
          'Purging legacy/incompatible encrypted cache files.',
        );
        final rawDir = await _resolveCacheDirectoryRaw();
        if (await rawDir.exists()) {
          await rawDir.delete(recursive: true);
          await rawDir.create(recursive: true);
        }
        await prefs.setInt(_cacheVersionKey, currentCacheVersion);
      }
    } catch (e) {
      debugPrint('EncryptedCacheService: Cache migration check error: $e');
    } finally {
      _migrationChecked = true;
    }
  }

  Future<Directory> _resolveCacheDirectoryRaw() async {
    if (_customCacheDirPath != null) {
      return Directory(_customCacheDirPath!);
    }
    final tempDir = Directory.systemTemp;
    return Directory('${tempDir.path}/notify_secure_notes_cache');
  }

  /// Retrieves or cryptographically generates the 32-byte (256-bit) AES key
  Future<Uint8List> getOrCreateEncryptionKey() async {
    if (_cachedKey != null) return _cachedKey!;

    String? base64Key = await _secureStorage.read(key: _storageKeyAes);
    if (base64Key == null || base64Key.isEmpty) {
      final random = Random.secure();
      final keyBytes = Uint8List(32);
      for (int i = 0; i < 32; i++) {
        keyBytes[i] = random.nextInt(256);
      }
      base64Key = base64Encode(keyBytes);
      await _secureStorage.write(key: _storageKeyAes, value: base64Key);
      _cachedKey = keyBytes;
      return keyBytes;
    }

    _cachedKey = Uint8List.fromList(base64Decode(base64Key));
    return _cachedKey!;
  }

  /// Resolves the cache directory on disk, ensuring schema migration has executed.
  Future<Directory> _getCacheDirectory() async {
    await ensureCacheVersionMigrated();
    final dir = await _resolveCacheDirectoryRaw();
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  File _getCacheFile(Directory dir, String partId) {
    // Sanitize partId for filename safety
    final safeId = partId.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
    return File('${dir.path}/$safeId.enc');
  }

  /// Encrypts and writes HTML content to local disk cache.
  /// Disk layout: [16-byte random IV][AES-256-CBC ciphertext with PKCS7]
  Future<File> saveEncryptedContent(String partId, String htmlContent) async {
    final key = await getOrCreateEncryptionKey();
    final cacheDir = await _getCacheDirectory();
    final file = _getCacheFile(cacheDir, partId);

    // 1. Generate cryptographically secure 16-byte IV
    final random = Random.secure();
    final iv = Uint8List(16);
    for (int i = 0; i < 16; i++) {
      iv[i] = random.nextInt(256);
    }

    // 2. Encrypt plaintext HTML using AES-256-CBC
    final plainBytes = Uint8List.fromList(utf8.encode(htmlContent));
    final cipherBytes = Aes256Cbc.encrypt(
      plainBytes: plainBytes,
      key: key,
      iv: iv,
    );

    // 3. Prepend IV to ciphertext
    final diskPayload = Uint8List(iv.length + cipherBytes.length);
    diskPayload.setRange(0, 16, iv);
    diskPayload.setRange(16, diskPayload.length, cipherBytes);

    // 4. Atomic write to disk
    await file.writeAsBytes(diskPayload, flush: true);
    return file;
  }

  /// Reads and decrypts cached note content.
  /// Returns the decrypted HTML string, or null if not cached or if the cached
  /// file was corrupted/incompatible (in which case it is purged for clean re-download).
  Future<String?> readDecryptedContent(String partId) async {
    final cacheDir = await _getCacheDirectory();
    final file = _getCacheFile(cacheDir, partId);

    if (!await file.exists()) {
      return null;
    }

    try {
      final diskPayload = await file.readAsBytes();
      if (diskPayload.length < 16 + Aes256Cbc.blockSize) {
        await removeCachedContent(partId);
        return null;
      }

      // Extract IV and ciphertext
      final iv = Uint8List.fromList(diskPayload.sublist(0, 16));
      final cipherBytes = Uint8List.fromList(diskPayload.sublist(16));

      final key = await getOrCreateEncryptionKey();

      // Decrypt using AES-256
      final plainBytes = Aes256Cbc.decrypt(
        cipherBytes: cipherBytes,
        key: key,
        iv: iv,
      );

      return utf8.decode(plainBytes);
    } catch (e) {
      debugPrint(
        'EncryptedCacheService: Failed to decrypt cached content for partId=$partId ($e). '
        'Purging corrupted or stale cache file to trigger fresh fetch.',
      );
      await removeCachedContent(partId);
      return null;
    }
  }

  /// Returns the raw encrypted disk file bytes without decryption.
  Future<Uint8List?> getRawDiskBytes(String partId) async {
    final cacheDir = await _getCacheDirectory();
    final file = _getCacheFile(cacheDir, partId);
    if (!await file.exists()) return null;
    return await file.readAsBytes();
  }

  File _getAnnotationsFile(Directory dir, String partId) {
    final safeId = partId.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
    return File('${dir.path}/${safeId}_annotations.enc');
  }

  /// Encrypts and writes annotations bundle (highlights, bookmarks) to AES-256 encrypted cache
  Future<File> saveEncryptedAnnotations(String partId, NoteAnnotationsBundle bundle) async {
    final jsonStr = bundle.toJson();
    final key = await getOrCreateEncryptionKey();
    final cacheDir = await _getCacheDirectory();
    final file = _getAnnotationsFile(cacheDir, partId);

    final random = Random.secure();
    final iv = Uint8List(16);
    for (int i = 0; i < 16; i++) {
      iv[i] = random.nextInt(256);
    }

    final plainBytes = Uint8List.fromList(utf8.encode(jsonStr));
    final cipherBytes = Aes256Cbc.encrypt(
      plainBytes: plainBytes,
      key: key,
      iv: iv,
    );

    final diskPayload = Uint8List(iv.length + cipherBytes.length);
    diskPayload.setRange(0, 16, iv);
    diskPayload.setRange(16, diskPayload.length, cipherBytes);

    await file.writeAsBytes(diskPayload, flush: true);
    return file;
  }

  /// Reads and decrypts annotations bundle for a part.
  /// Returns NoteAnnotationsBundle or null if not yet saved or if unreadable.
  Future<NoteAnnotationsBundle?> readDecryptedAnnotations(String partId) async {
    final cacheDir = await _getCacheDirectory();
    final file = _getAnnotationsFile(cacheDir, partId);

    if (!await file.exists()) {
      return null;
    }

    try {
      final diskPayload = await file.readAsBytes();
      if (diskPayload.length < 16 + Aes256Cbc.blockSize) {
        if (await file.exists()) await file.delete();
        return null;
      }

      final iv = Uint8List.fromList(diskPayload.sublist(0, 16));
      final cipherBytes = Uint8List.fromList(diskPayload.sublist(16));
      final key = await getOrCreateEncryptionKey();

      final plainBytes = Aes256Cbc.decrypt(
        cipherBytes: cipherBytes,
        key: key,
        iv: iv,
      );

      final jsonStr = utf8.decode(plainBytes);
      return NoteAnnotationsBundle.fromJson(jsonStr);
    } catch (e) {
      debugPrint(
        'EncryptedCacheService: Failed to decrypt annotations for partId=$partId ($e). '
        'Purging stale/incompatible annotations.',
      );
      if (await file.exists()) await file.delete();
      return null;
    }
  }

  /// Checks whether encrypted cache exists for a part
  Future<bool> hasCachedContent(String partId) async {
    final cacheDir = await _getCacheDirectory();
    final file = _getCacheFile(cacheDir, partId);
    return await file.exists();
  }

  /// Removes cached file for a part
  Future<void> removeCachedContent(String partId) async {
    final cacheDir = await _getCacheDirectory();
    final file = _getCacheFile(cacheDir, partId);
    if (await file.exists()) {
      await file.delete();
    }
    final annotFile = _getAnnotationsFile(cacheDir, partId);
    if (await annotFile.exists()) {
      await annotFile.delete();
    }
  }

  /// Clears all encrypted cache
  Future<void> clearAllCache() async {
    final cacheDir = await _getCacheDirectory();
    if (await cacheDir.exists()) {
      await cacheDir.delete(recursive: true);
    }
  }
}
