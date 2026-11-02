import 'dart:io';

class PlatformStorage {
  static File _getFile(String key) {
    final userProfile = Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'] ?? Directory.systemTemp.path;
    final dir = Directory('$userProfile/CashawyData');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return File('${dir.path}/$key.json');
  }

  static Future<String?> read(String key) async {
    try {
      final file = _getFile(key);
      if (await file.exists()) {
        return await file.readAsString();
      }
    } catch (_) {}
    return null;
  }

  static Future<void> write(String key, String value) async {
    try {
      final file = _getFile(key);
      await file.writeAsString(value);
    } catch (_) {}
  }

  static Future<String?> downloadFile(String fileName, String content) async {
    try {
      String dirPath = Directory.systemTemp.path;
      final userProfile = Platform.environment['USERPROFILE'];
      if (userProfile != null) {
        final downloads = Directory('$userProfile\\Downloads');
        if (downloads.existsSync()) {
          dirPath = downloads.path;
        }
      }
      final targetPath = '$dirPath\\$fileName';
      final file = File(targetPath);
      await file.writeAsString(content);
      return targetPath;
    } catch (_) {
      return null;
    }
  }
}