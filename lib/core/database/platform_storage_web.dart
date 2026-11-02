// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

class PlatformStorage {
  static Future<String?> read(String key) async {
    return html.window.localStorage[key];
  }

  static Future<void> write(String key, String value) async {
    html.window.localStorage[key] = value;
  }

  static Future<String?> downloadFile(String fileName, String content) async {
    final bytes = html.Blob([content], 'text/csv;charset=utf-8');
    final url = html.Url.createObjectUrlFromBlob(bytes);
    final anchor = html.document.createElement('a') as html.AnchorElement
      ..href = url
      ..style.display = 'none'
      ..download = fileName;
    html.document.body?.children.add(anchor);
    anchor.click();
    html.document.body?.children.remove(anchor);
    html.Url.revokeObjectUrl(url);
    return 'مجلد التنزيلات بالمتصفح';
  }
}