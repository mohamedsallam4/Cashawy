import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class WalletParsedData {
  final String provider; // Vodafone, InstaPay, Orange, etc.
  final String type;     // receive or transfer
  final double amount;
  final double currentBalance;
  final String senderOrReceiver;
  final String rawMessage;
  final String? gatewayName; // اسم هاتف الشريحة الذي التقط العملية

  WalletParsedData({
    required this.provider,
    required this.type,
    required this.amount,
    required this.currentBalance,
    required this.senderOrReceiver,
    required this.rawMessage,
    this.gatewayName,
  });
}

class SmsParserService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _storeId = 'supermarket_main_branch';

  static WalletParsedData? parseIncomingSms(String sender, String body, {String? gatewayName}) {
    final cleanSender = sender.toUpperCase().trim();
    final cleanBody = body.trim();

    WalletParsedData? data;

    if (cleanSender.contains('VODAFONE') || cleanSender.contains('VF-CASH') || cleanBody.contains('فودافون كاش')) {
      data = _parseVodafoneCash(cleanBody);
    } else if (cleanSender.contains('INSTAPAY') || cleanBody.contains('انستاباي') || cleanBody.contains('InstaPay')) {
      data = _parseInstaPay(cleanBody);
    } else if (cleanSender.contains('ORANGE') || cleanBody.contains('أورنچ كاش') || cleanBody.contains('اورنج كاش')) {
      data = _parseOrangeCash(cleanBody);
    }

    if (data != null && gatewayName != null) {
      return WalletParsedData(
        provider: data.provider,
        type: data.type,
        amount: data.amount,
        currentBalance: data.currentBalance,
        senderOrReceiver: data.senderOrReceiver,
        rawMessage: data.rawMessage,
        gatewayName: gatewayName,
      );
    }

    return data;
  }

  static WalletParsedData? _parseVodafoneCash(String body) {
    try {
      double amount = 0.0;
      double balance = 0.0;
      String type = 'receive';
      String party = 'غير محدد';

      final balanceRegex = RegExp(r'رصيدك الحالي (?:هو\s*)?:?\s*([\d\.]+)');
      final balanceMatch = balanceRegex.firstMatch(body);
      if (balanceMatch != null) {
        balance = double.tryParse(balanceMatch.group(1) ?? '0') ?? 0.0;
      }

      if (body.contains('تم استلام') || body.contains('استلمت') || body.contains('تم إيداع')) {
        type = 'receive';
        final amtRegex = RegExp(r'(?:مبلغ|قيمة|تم استلام)\s*([\d\.]+)\s*جنيه');
        final amtMatch = amtRegex.firstMatch(body);
        if (amtMatch != null) {
          amount = double.tryParse(amtMatch.group(1) ?? '0') ?? 0.0;
        }

        final fromRegex = RegExp(r'من\s*(01\d{9})');
        final fromMatch = fromRegex.firstMatch(body);
        if (fromMatch != null) party = fromMatch.group(1)!;
      } else if (body.contains('تم تحويل') || body.contains('حول')) {
        type = 'transfer';
        final amtRegex = RegExp(r'(?:تم تحويل|مبلغ)\s*([\d\.]+)\s*جنيه');
        final amtMatch = amtRegex.firstMatch(body);
        if (amtMatch != null) {
          amount = double.tryParse(amtMatch.group(1) ?? '0') ?? 0.0;
        }

        final toRegex = RegExp(r'إلى\s*(01\d{9})|الى\s*(01\d{9})');
        final toMatch = toRegex.firstMatch(body);
        if (toMatch != null) party = toMatch.group(1) ?? toMatch.group(2) ?? 'رقم محول إليه';
      }

      if (amount > 0 || balance > 0) {
        return WalletParsedData(
          provider: 'فودافون كاش',
          type: type,
          amount: amount,
          currentBalance: balance,
          senderOrReceiver: party,
          rawMessage: body,
        );
      }
    } catch (e) {
      debugPrint('Error parsing Vodafone SMS: $e');
    }
    return null;
  }

  static WalletParsedData? _parseInstaPay(String body) {
    try {
      double amount = 0.0;
      double balance = 0.0;
      String type = 'receive';

      final amtRegex = RegExp(r'(?:مبلغ|بقيمة)\s*([\d\.,]+)\s*(?:جم|EGP|جنيه)');
      final amtMatch = amtRegex.firstMatch(body);
      if (amtMatch != null) {
        final raw = amtMatch.group(1)!.replaceAll(',', '');
        amount = double.tryParse(raw) ?? 0.0;
      }

      final balRegex = RegExp(r'(?:الرصيد المتاح|رصيدك المتاح|الرصيد الحالي)\s*([\d\.,]+)');
      final balMatch = balRegex.firstMatch(body);
      if (balMatch != null) {
        final raw = balMatch.group(1)!.replaceAll(',', '');
        balance = double.tryParse(raw) ?? 0.0;
      }

      if (body.contains('خصم') || body.contains('تحويل إلى')) {
        type = 'transfer';
      }

      if (amount > 0) {
        return WalletParsedData(
          provider: 'إنستاباي (InstaPay)',
          type: type,
          amount: amount,
          currentBalance: balance,
          senderOrReceiver: 'عميل إنستاباي',
          rawMessage: body,
        );
      }
    } catch (e) {
      debugPrint('Error parsing InstaPay SMS: $e');
    }
    return null;
  }

  static WalletParsedData? _parseOrangeCash(String body) {
    try {
      double amount = 0.0;
      double balance = 0.0;
      String type = 'receive';

      final amtRegex = RegExp(r'([\d\.]+)\s*جنيه');
      final amtMatch = amtRegex.firstMatch(body);
      if (amtMatch != null) {
        amount = double.tryParse(amtMatch.group(1) ?? '0') ?? 0.0;
      }

      final balRegex = RegExp(r'رصيدك الحالي\s*([\d\.]+)');
      final balMatch = balRegex.firstMatch(body);
      if (balMatch != null) {
        balance = double.tryParse(balMatch.group(1) ?? '0') ?? 0.0;
      }

      if (body.contains('تم تحويل') || body.contains('سحب')) {
        type = 'transfer';
      }

      if (amount > 0 || balance > 0) {
        return WalletParsedData(
          provider: 'أورنج كاش',
          type: type,
          amount: amount,
          currentBalance: balance,
          senderOrReceiver: 'رقم محفظة',
          rawMessage: body,
        );
      }
    } catch (e) {
      debugPrint('Error parsing Orange SMS: $e');
    }
    return null;
  }

  /// ترحيل المعاملة السحابية مع حفظ اسم الهاتف الملتقط
  static Future<void> syncParsedTransactionToCloud(WalletParsedData data) async {
    try {
      final batch = _firestore.batch();

      final txRef = _firestore
          .collection('stores')
          .doc(_storeId)
          .collection('live_transactions')
          .doc();

      final deviceLabel = data.gatewayName != null && data.gatewayName!.isNotEmpty
          ? ' [بواسطة: ${data.gatewayName}]'
          : '';

      batch.set(txRef, {
        'id': txRef.id,
        'amount': data.amount,
        'type': data.type,
        'walletPhone': data.provider,
        'clientPhone': data.senderOrReceiver,
        'notes': 'التقاط آلي من رسائل SMS: ${data.provider}$deviceLabel',
        'gatewayDevice': data.gatewayName ?? 'هاتف الفرع',
        'status': 'completed',
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (data.currentBalance > 0) {
        final storeRef = _firestore.collection('stores').doc(_storeId);
        batch.set(storeRef, {
          'lastSmsSync': {
            'provider': data.provider,
            'updatedBalance': data.currentBalance,
            'gatewayDevice': data.gatewayName ?? 'هاتف الفرع',
            'timestamp': FieldValue.serverTimestamp(),
          },
        }, SetOptions(merge: true));
      }

      await batch.commit();
      debugPrint('✅ [SMS Gateway] Synced TX from ${data.gatewayName} of ${data.amount} EGP.');
    } catch (e) {
      debugPrint('❌ [SMS Gateway] Failed to sync to Firestore: $e');
    }
  }
}