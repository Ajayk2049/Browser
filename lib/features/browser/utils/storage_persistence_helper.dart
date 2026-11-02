import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Helper for retrieving internal and persistent external storage directories
/// for app data persistence across APK reinstallations.
/// Complies with rules.md §13, §29.2 (< 200 lines).
class StoragePersistenceHelper {
  static const String _backupDirName = 'Dab Browser/.data';

  /// Primary internal storage file for a given [fileName] (e.g. 'bookmarks.json').
  static Future<File> getInternalFile(String fileName) async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$fileName');
  }

  /// Persistent external storage mirror file (survives app re-installs).
  static Future<File?> getExternalBackupFile(String fileName) async {
    try {
      if (!Platform.isAndroid) return null;
      // Typical Android external Download folder: /storage/emulated/0/Download
      final candidatePaths = [
        '/storage/emulated/0/Download/$_backupDirName',
        '/sdcard/Download/$_backupDirName',
      ];

      for (final p in candidatePaths) {
        final dir = Directory(p);
        if (!dir.existsSync()) {
          try {
            dir.createSync(recursive: true);
          } catch (_) {
            continue;
          }
        }
        return File('${dir.path}/$fileName');
      }
    } catch (e) {
      debugPrint('StoragePersistenceHelper.getExternalBackupFile error: $e');
    }
    return null;
  }

  /// Loads content from internal file; falls back to external backup file if missing.
  static Future<String?> readData(String fileName) async {
    try {
      final internal = await getInternalFile(fileName);
      if (await internal.exists()) {
        final content = await internal.readAsString();
        if (content.trim().isNotEmpty) return content;
      }

      // Fallback to external backup file
      final external = await getExternalBackupFile(fileName);
      if (external != null && await external.exists()) {
        final backupContent = await external.readAsString();
        if (backupContent.trim().isNotEmpty) {
          // Restore back into internal file immediately
          await internal.writeAsString(backupContent);
          return backupContent;
        }
      }
    } catch (e) {
      debugPrint('StoragePersistenceHelper.readData error for $fileName: $e');
    }
    return null;
  }

  /// Writes data atomically to internal storage and mirrors to external backup file.
  static Future<void> writeData(String fileName, String content) async {
    try {
      // 1. Write atomically to internal storage via tmp file
      final internal = await getInternalFile(fileName);
      final tmp = File('${internal.path}.tmp');
      await tmp.writeAsString(content);
      if (await internal.exists()) await internal.delete();
      await tmp.rename(internal.path);

      // 2. Mirror to external backup storage if available
      final external = await getExternalBackupFile(fileName);
      if (external != null) {
        final extTmp = File('${external.path}.tmp');
        await extTmp.writeAsString(content);
        if (await external.exists()) await external.delete();
        await extTmp.rename(external.path);
      }
    } catch (e) {
      debugPrint('StoragePersistenceHelper.writeData error for $fileName: $e');
    }
  }
}

