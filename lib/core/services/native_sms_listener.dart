import 'dart:async';
import 'package:cashawy_pro/core/theme/parsers/cash_sms_parser.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../security/cashawy_security_shield.dart';

class NativeSmsListener {
  static const EventChannel _smsEventChannel = EventChannel('cashawy/sms_stream');
  static const MethodChannel _permissionChannel = MethodChannel('cashawy/permissions');

  static StreamSubscription? _subscription;
  static int keptPrivateSmsCount = 0; // عداد الرسائل الشخصية والـ OTP التي تم حمايتها وعدم رفعها

  static bool get _isAndroid => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<bool> checkPermissions() async {
    if (!_isAndroid) return true;
    try {
      final bool granted = await _permissionChannel.invokeMethod('checkSmsPermissions');
      return granted;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> requestPermissions() async {
    if (!_isAndroid) return true;
    try {
      final bool granted = await _permissionChannel.invokeMethod('requestSmsPermissions');
      return granted;
    } catch (_) {
      return false;
    }
  }

  static void startListening({
    required void Function(ParsedCashSms parsedSms) onCashSmsReceived,
    void Function(String sender, ParsedCashSms parsedSms)? onSecureCashSmsReceived,
    void Function(String sender, String rawBody)? onAnySmsReceived,
  }) {
    if (!_isAndroid) return;

    _subscription?.cancel();
    _subscription = _smsEventChannel.receiveBroadcastStream().listen((dynamic event) {
      if (event is Map) {
        final String sender = event['sender']?.toString() ?? '';
        final String body = event['body']?.toString() ?? '';

        // 1. فلتر الخصوصية: تجاهل رسائل الـ OTP والرسائل الشخصية تماماً
        if (!CashawySecurityShield.isFinancialSms(sender, body)) {
          keptPrivateSmsCount++;
          return;
        }

        if (onAnySmsReceived != null) {
          onAnySmsReceived(sender, body);
        }

        final parsed = CashSmsParser.parse(sender: sender, messageBody: body);
        if (parsed != null) {
          onCashSmsReceived(parsed);
          if (onSecureCashSmsReceived != null) {
            onSecureCashSmsReceived(sender, parsed);
          }
        }
      }
    });
  }

  static void stopListening() {
    _subscription?.cancel();
    _subscription = null;
  }
}