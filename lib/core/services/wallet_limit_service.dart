import 'dart:math' as math;

import '../../models/transaction_model.dart';
import '../../models/wallet_model.dart';
import '../theme/parsers/cash_sms_parser.dart';

/// لقطة بالمبالغ المستهلكة من حدود المحفظة في الفترة الحالية.
///
/// القيم تُحسب من سجل المعاملات نفسه وليس من عدّادات قابلة للانحراف،
/// وبالتالي تتصفّر تلقائياً مع بداية اليوم/الشهر ولا تفقد قيمتها بعد
/// إعادة تشغيل البرنامج أو المزامنة السحابية.
class WalletUsageSnapshot {
  final double dailyTransfer;
  final double monthlyTransfer;
  final double dailyReceive;
  final double monthlyReceive;

  const WalletUsageSnapshot({
    this.dailyTransfer = 0.0,
    this.monthlyTransfer = 0.0,
    this.dailyReceive = 0.0,
    this.monthlyReceive = 0.0,
  });
}

/// نتيجة فحص إمكانية تنفيذ عملية على محفظة معينة.
class WalletLimitCheck {
  final bool allowed;
  final String? message;

  /// أقصى مبلغ يمكن تنفيذه الآن مع مراعاة اليومي والشهري والرصيد.
  final double maxAllowed;

  final double dailyRemaining;
  final double monthlyRemaining;
  final double balanceAvailable;

  final bool exceededDaily;
  final bool exceededMonthly;
  final bool insufficientBalance;

  const WalletLimitCheck({
    required this.allowed,
    required this.maxAllowed,
    required this.dailyRemaining,
    required this.monthlyRemaining,
    required this.balanceAvailable,
    this.message,
    this.exceededDaily = false,
    this.exceededMonthly = false,
    this.insufficientBalance = false,
  });
}

class WalletLimitService {
  WalletLimitService._();

  static const double tolerance = 0.01;

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static bool _sameMonth(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month;

  /// هل العملية تم تنفيذها فعلياً على المحفظة؟
  ///
  /// - التحويل: يُنفذ فوراً حتى لو كان آجل (العميل سيسدد كاش لاحقاً).
  /// - الاستلام: لا يُحتسب إلا لو وصل المبلغ فعلاً؛ الاستلام الآجل معناه
  ///   أن المحل سلّم كاش ولم يصل تحويل بعد، لذلك لا يستهلك ليميت الاستلام.
  static bool isExecuted(TransactionModel tx) {
    if (tx.status == TransactionStatus.trash ||
        tx.status == TransactionStatus.pending) {
      return false;
    }
    if (tx.type == TransactionType.transfer) return true;
    if (tx.type == TransactionType.receive) {
      return tx.status == TransactionStatus.completed;
    }
    return false;
  }

  static bool belongsToWallet(TransactionModel tx, WalletModel wallet) {
    final walletPhone = tx.walletPhone.trim();
    if (walletPhone.isEmpty) return false;

    final phone = wallet.phoneNumber.trim();
    final title = wallet.title.trim();

    return (phone.isNotEmpty && walletPhone == phone) ||
        (title.isNotEmpty && walletPhone == title);
  }

  /// حساب المستهلك من كل حد خلال اليوم والشهر الحاليين.
  static WalletUsageSnapshot calculateUsage({
    required WalletModel wallet,
    required List<TransactionModel> transactions,
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();

    double dailyTransfer = 0.0;
    double monthlyTransfer = 0.0;
    double dailyReceive = 0.0;
    double monthlyReceive = 0.0;

    for (final tx in transactions) {
      if (!isExecuted(tx)) continue;
      if (!belongsToWallet(tx, wallet)) continue;

      final isTransfer = tx.type == TransactionType.transfer;
      final isReceive = tx.type == TransactionType.receive;
      if (!isTransfer && !isReceive) continue;

      // العملية المؤجلة تُحسب من لحظة اعتمادها لا من لحظة تسجيلها،
      // وإلا أصبح التأجيل طريقة للالتفاف على الحد اليومي/الشهري.
      final effectiveDate = tx.executedAt ?? tx.createdAt;
      final sameDay = _sameDay(effectiveDate, current);
      final sameMonth = _sameMonth(effectiveDate, current);

      if (isTransfer) {
        if (sameMonth) monthlyTransfer += tx.amount;
        if (sameDay) dailyTransfer += tx.amount;
      } else {
        if (sameMonth) monthlyReceive += tx.amount;
        if (sameDay) dailyReceive += tx.amount;
      }
    }

    return WalletUsageSnapshot(
      dailyTransfer: dailyTransfer,
      monthlyTransfer: monthlyTransfer,
      dailyReceive: dailyReceive,
      monthlyReceive: monthlyReceive,
    );
  }

  /// فحص عملية جديدة قبل تنفيذها.
  static WalletLimitCheck check({
    required WalletModel wallet,
    required WalletUsageSnapshot usage,
    required bool isTransfer,
    required double amount,
    double networkFee = 0.0,
    bool checkBalance = true,
  }) {
    final dailyLimit = isTransfer
        ? wallet.dailyTransferLimit
        : wallet.dailyReceiveLimit;
    final monthlyLimit = isTransfer
        ? wallet.monthlyTransferLimit
        : wallet.monthlyReceiveLimit;
    final dailyUsed = isTransfer ? usage.dailyTransfer : usage.dailyReceive;
    final monthlyUsed = isTransfer
        ? usage.monthlyTransfer
        : usage.monthlyReceive;

    final dailyRemaining = math.max(0.0, dailyLimit - dailyUsed);
    final monthlyRemaining = math.max(0.0, monthlyLimit - monthlyUsed);

    // رصيد المحفظة المتاح للتحويل بعد خصم رسوم الشبكة.
    final balanceAvailable = isTransfer
        ? math.max(0.0, wallet.balance - networkFee)
        : wallet.balance;

    final exceededDaily = dailyRemaining <= tolerance;
    final exceededMonthly = monthlyRemaining <= tolerance;
    final insufficientBalance =
        isTransfer && checkBalance && balanceAvailable + tolerance < amount;

    var maxAllowed = math.min(dailyRemaining, monthlyRemaining);
    if (isTransfer && checkBalance) {
      maxAllowed = math.min(maxAllowed, balanceAvailable);
    }

    final requested = math.max(0.0, amount);
    if (requested > maxAllowed + tolerance) {
      final String reason;
      if (insufficientBalance &&
          balanceAvailable <= dailyRemaining + tolerance &&
          balanceAvailable <= monthlyRemaining + tolerance) {
        reason =
            'رصيد المحفظة لا يكفي. المتاح للتحويل: ${balanceAvailable.toStringAsFixed(2)} ج.م';
      } else if (dailyRemaining <= monthlyRemaining) {
        reason =
            'تم الوصول للحد اليومي (${isTransfer ? 'التحويل' : 'الاستلام'}). '
            'المتاح اليوم: ${dailyRemaining.toStringAsFixed(2)} ج.م';
      } else {
        reason =
            'تم الوصول للحد الشهري (${isTransfer ? 'التحويل' : 'الاستلام'}). '
            'المتاح هذا الشهر: ${monthlyRemaining.toStringAsFixed(2)} ج.م';
      }

      return WalletLimitCheck(
        allowed: false,
        message: reason,
        maxAllowed: maxAllowed,
        dailyRemaining: dailyRemaining,
        monthlyRemaining: monthlyRemaining,
        balanceAvailable: balanceAvailable,
        exceededDaily: exceededDaily,
        exceededMonthly: exceededMonthly,
        insufficientBalance: insufficientBalance,
      );
    }

    return WalletLimitCheck(
      allowed: true,
      maxAllowed: maxAllowed,
      dailyRemaining: dailyRemaining,
      monthlyRemaining: monthlyRemaining,
      balanceAvailable: balanceAvailable,
      exceededDaily: exceededDaily,
      exceededMonthly: exceededMonthly,
      insufficientBalance: insufficientBalance,
    );
  }
}
