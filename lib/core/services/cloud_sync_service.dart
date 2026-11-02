import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../models/transaction_model.dart';
import '../../models/wallet_model.dart';

class CloudSyncService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// كود تعريف السوبر ماركت (يربط جهاز المحل بتطبيق الموبايل الخاص بالمالك)
  static String storeId = 'supermarket_main_branch';

  /// 1. إرسال إشعار وتحديث لحظي عند حدوث أي عملية (سحب، تحويل، فاتورة بيع)
  static Future<void> syncTransaction(TransactionModel tx) async {
    try {
      await _firestore
          .collection('stores')
          .doc(storeId)
          .collection('live_transactions')
          .doc(tx.id)
          .set({
            'id': tx.id,
            'walletPhone': tx.walletPhone,
            'clientPhone': tx.clientPhone,
            'clientName': tx.clientName,
            'type': tx.type.name,
            'amount': tx.amount,
            'commission': tx.commission,
            'status': tx.status.name,
            'notes': tx.notes,
            'timestamp': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      debugPrint('تنبيه مزامنة سحابية (سيتم التحديث عند توفر الإنترنت): $e');
    }
  }

  /// حذف عملية من شريط العمليات المباشر (تُستخدم عند إلغاء عملية مؤجلة).
  static Future<void> deleteTransaction(String txId) async {
    try {
      await _firestore
          .collection('stores')
          .doc(storeId)
          .collection('live_transactions')
          .doc(txId)
          .delete();
    } catch (e) {
      debugPrint('تعذر حذف العملية من السحابة: $e');
    }
  }

  /// 2. تحديث لوحة التحكم المباشرة لهاتف المالك (أرصدة المحافظ، الخزنة، والمبيعات)
  static Future<void> updateOwnerDashboardMetrics({
    required double cashInDrawer,
    required double totalCapital,
    required double todaySales,
    required double todayProfits,
    required List<WalletModel> wallets,
  }) async {
    try {
      final walletsData = wallets
          .map(
            (w) => {
              'id': w.id,
              'phone': w.phoneNumber,
              'phoneNumber': w.phoneNumber,
              'title': w.title,
              'provider': w.provider.name,
              'balance': w.balance,
              'dailyTransferLimit': w.dailyTransferLimit,
              'monthlyTransferLimit': w.monthlyTransferLimit,
              'dailyReceiveLimit': w.dailyReceiveLimit,
              'monthlyReceiveLimit': w.monthlyReceiveLimit,
              'usedDailyTransfer': w.usedDailyTransfer,
              'usedMonthlyTransfer': w.usedMonthlyTransfer,
              'usedDailyReceive': w.usedDailyReceive,
              'usedMonthlyReceive': w.usedMonthlyReceive,
              'usedTodayTransfer': w.usedDailyTransfer,
              'usedTodayReceive': w.usedDailyReceive,
              'isNearLimit': w.isNearLimit,
            },
          )
          .toList();

      await _firestore.collection('stores').doc(storeId).set({
        'lastUpdated': FieldValue.serverTimestamp(),
        'cashInDrawer': cashInDrawer,
        'totalCapital': totalCapital,
        'todaySales': todaySales,
        'todayProfits': todayProfits,
        'wallets': walletsData,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('خطأ تحديث مؤشرات المالك: $e');
    }
  }
}
