abstract class PlatformStorage {
  static Future<String?> read(String key) => throw UnsupportedError('Platform not supported');
  static Future<void> write(String key, String value) => throw UnsupportedError('Platform not supported');
  static Future<String?> downloadFile(String fileName, String content) => throw UnsupportedError('Platform not supported');
}