import 'package:cashawy_pro/core/theme/parsers/cash_sms_parser.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class NativeUssdService {
  static const MethodChannel _ussdChannel = MethodChannel('cashawy/ussd_channel');

  static bool get _isAndroid => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// فحص هل خدمة الإدخال التلقائي للرقم السري (Accessibility) مفعلة أم لا
  static Future<bool> isAccessibilityEnabled() async {
    if (!_isAndroid) return true;
    try {
      final bool enabled = await _ussdChannel.invokeMethod('isAccessibilityEnabled');
      return enabled;
    } catch (_) {
      return false;
    }
  }

  /// فتح شاشة إعدادات إمكانية الوصول في الهاتف لتفعيل Cashawy
  static Future<void> openAccessibilitySettings() async {
    if (!_isAndroid) return;
    await _ussdChannel.invokeMethod('openAccessibilitySettings');
  }

  /// توليد كود الـ USSD الصحيح حسب شبكة المحفظة في مصر
  static String buildTransferUssdCode({
    required WalletProvider provider,
    required String targetPhone,
    required int amount,
  }) {
    switch (provider) {
      case WalletProvider.vodafone:
        return '*9*7*$targetPhone*$amount#';
      case WalletProvider.etisalat:
        return '*777*1*$targetPhone*$amount#';
      case WalletProvider.orange:
        return '#7115#';
      case WalletProvider.we:
        return '*322#';
      default:
        return '*9*7*$targetPhone*$amount#';
    }
  }

  /// تنفيذ التحويل المباشر بضغطة واحدة
  static Future<bool> executeUssd({
    required String ussdCode,
    String pinCode = '',
    int simSlot = 0,
  }) async {
    if (!_isAndroid) return false;
    try {
      final bool success = await _ussdChannel.invokeMethod('executeUssdTransfer', {
        'ussdCode': ussdCode,
        'pinCode': pinCode,
        'simSlot': simSlot,
      });
      return success;
    } catch (_) {
      return false;
    }
  }
}