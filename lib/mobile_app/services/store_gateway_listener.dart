import 'package:flutter/foundation.dart';
import '../../core/services/sms_parser_service.dart';
import 'package:another_telephony/telephony.dart';
/// دالة المعالجة في الخلفية (Background Message Handler)
@pragma('vm:entry-point')
void backgroundMessageHandler(SmsMessage message) async {
  final sender = message.address ?? '';
  final body = message.body ?? '';
  final parsed = SmsParserService.parseIncomingSms(sender, body);
  if (parsed != null) {
    await SmsParserService.syncParsedTransactionToCloud(parsed);
  }
}

class StoreGatewayListener {
  static final Telephony _telephony = Telephony.instance;

  /// بدء تشغيل الرادار والاستماع لرسائل المحافظ
  static Future<bool> startListening() async {
    final bool? permissionsGranted = await _telephony.requestPhoneAndSmsPermissions;

    if (permissionsGranted == true) {
      _telephony.listenIncomingSms(
        onNewMessage: (SmsMessage message) async {
          final sender = message.address ?? '';
          final body = message.body ?? '';
          debugPrint('📩 [Foreground SMS] Received from: $sender');

          final parsed = SmsParserService.parseIncomingSms(sender, body);
          if (parsed != null) {
            await SmsParserService.syncParsedTransactionToCloud(parsed);
          }
        },
        onBackgroundMessage: backgroundMessageHandler,
      );
      return true;
    } else {
      debugPrint('⚠️ SMS permissions denied by user.');
      return false;
    }
  }
}