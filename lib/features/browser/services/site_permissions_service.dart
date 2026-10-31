import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Manages per-origin site permissions (Location, Camera, Microphone, Notifications).
/// Persists user preferences locally to disk.
/// Complies with rules.md §13, §25.1, §25.2, §25.7, and §29.2 (< 250 lines).
class SitePermissionsService extends ChangeNotifier {
  static final SitePermissionsService instance = SitePermissionsService._internal();

  SitePermissionsService._internal();

  final Map<String, Map<String, bool>> _permissionsByHost = {};
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;
    _isInitialized = true;
    try {
      final file = await _getStorageFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.trim().isNotEmpty) {
          final decoded = jsonDecode(content) as Map<String, dynamic>;
          _permissionsByHost.clear();
          decoded.forEach((host, perms) {
            if (perms is Map<String, dynamic>) {
              _permissionsByHost[host] = perms.map((k, v) => MapEntry(k, v as bool));
            }
          });
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('SitePermissionsService.init error: $e');
    }
  }

  /// Checks if [permission] is allowed for [host].
  bool isAllowed(String host, String permission) {
    final cleanHost = _cleanHost(host);
    return _permissionsByHost[cleanHost]?[permission] ?? false;
  }

  /// Returns only the permissions explicitly allowed by the user for [host].
  List<String> getAllowedPermissions(String host) {
    final cleanHost = _cleanHost(host);
    final perms = _permissionsByHost[cleanHost];
    if (perms == null) return const [];
    return perms.entries.where((e) => e.value == true).map((e) => e.key).toList();
  }

  /// Updates allowed state for [permission] on [host].
  Future<void> setPermission(String host, String permission, bool allowed) async {
    final cleanHost = _cleanHost(host);
    if (cleanHost.isEmpty) return;

    if (!allowed) {
      _permissionsByHost[cleanHost]?.remove(permission);
      if (_permissionsByHost[cleanHost]?.isEmpty == true) {
        _permissionsByHost.remove(cleanHost);
      }
    } else {
      final hostPerms = _permissionsByHost.putIfAbsent(cleanHost, () => {});
      hostPerms[permission] = true;
    }
    notifyListeners();
    await _persist();
  }

  /// Resets all permissions for [host] back to blocked/default.
  Future<void> resetPermissions(String host) async {
    final cleanHost = _cleanHost(host);
    _permissionsByHost.remove(cleanHost);
    notifyListeners();
    await _persist();
  }

  @visibleForTesting
  void setPermissionsForTesting(Map<String, Map<String, bool>> data) {
    _permissionsByHost.clear();
    _permissionsByHost.addAll(data);
    _isInitialized = true;
    notifyListeners();
  }

  String _cleanHost(String raw) {
    if (raw.isEmpty) return '';
    final uri = Uri.tryParse(raw.startsWith('http') ? raw : 'https://$raw');
    return uri?.host.isNotEmpty == true ? uri!.host.toLowerCase() : raw.toLowerCase();
  }

  Future<File> _getStorageFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/site_permissions.json');
  }

  Future<void> _persist() async {
    try {
      final file = await _getStorageFile();
      final data = jsonEncode(_permissionsByHost);
      await file.writeAsString(data);
    } catch (e) {
      debugPrint('SitePermissionsService._persist error: $e');
    }
  }
}

