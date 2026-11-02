import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

class CashawyStorage {
  /// جلب مسار مجلد حفظ بيانات النظام الدائم في المستندات
  static Future<String> _getAppDir() async {
    if (kIsWeb) return '';
    try {
      final userProfile = Platform.environment['USERPROFILE']; // بيئة ويندوز
      if (userProfile != null) {
        final dir = Directory('$userProfile\\Documents\\CashawyData');
        if (!dir.existsSync()) {
          dir.createSync(recursive: true);
        }
        return dir.path;
      }
      final home = Platform.environment['HOME']; // بيئات لينكس وماك وأندرويد
      if (home != null) {
        final dir = Directory('$home/.cashawy_data');
        if (!dir.existsSync()) {
          dir.createSync(recursive: true);
        }
        return dir.path;
      }
    } catch (_) {}
    return Directory.current.path;
  }

  /// قراءة قاعدة البيانات من القرص الصلب
  static Future<String?> read(String key) async {
    if (kIsWeb) return null;
    try {
      final dir = await _getAppDir();
      final file = File('$dir\\$key.json');
      if (await file.exists()) {
        return await file.readAsString(encoding: utf8);
      }
    } catch (e) {
      debugPrint('خطأ أثناء قراءة ملف قاعدة البيانات: $e');
    }
    return null;
  }

  /// الكتابة الذرية الآمنة (Atomic Write) لمنع تلف ملف الـ JSON عند انقطاع الكهرباء
  static Future<void> write(String key, String content) async {
    if (kIsWeb) return;
    try {
      final dir = await _getAppDir();
      final targetFile = File('$dir\\$key.json');
      final tempFile = File('$dir\\$key.tmp');

      // 1. الكتابة في ملف مؤقت أولاً مع إجبار القرص الصلب على التثبيت المباشر
      await tempFile.writeAsString(content, flush: true, encoding: utf8);

      // 2. الاستبدال الفوري للملف بعد اكتمال كتابة البيانات 100%
      if (await tempFile.exists()) {
        if (await targetFile.exists()) {
          await targetFile.delete();
        }
        await tempFile.rename(targetFile.path);
      }
    } catch (e) {
      debugPrint('خطأ أثناء الحفظ الذري للبيانات: $e');
    }
  }

  /// تصدير وحفظ ملفات الإكسيل والتقارير في مجلد التنزيلات (Downloads)
  static Future<String?> downloadFile(String fileName, String content) async {
    if (kIsWeb) return null;
    try {
      String exportDir = Directory.systemTemp.path;
      final userProfile = Platform.environment['USERPROFILE'];
      if (userProfile != null) {
        final downloads = Directory('$userProfile\\Downloads');
        if (downloads.existsSync()) {
          exportDir = downloads.path;
        }
      }
      final filePath = '$exportDir\\$fileName';
      final file = File(filePath);
      await file.writeAsString(content, encoding: utf8, flush: true);
      return filePath;
    } catch (e) {
      debugPrint('خطأ أثناء تصدير الملف: $e');
      return null;
    }
  }
}