import 'package:cashawy_pro/core/services/wallet_limit_service.dart';
import 'package:cashawy_pro/core/theme/parsers/cash_sms_parser.dart';
import 'package:cashawy_pro/models/transaction_model.dart';
import 'package:cashawy_pro/models/wallet_model.dart';
import 'package:flutter_test/flutter_test.dart';

TransactionModel _tx({
  required TransactionType type,
  required double amount,
  required DateTime createdAt,
  TransactionStatus status = TransactionStatus.completed,
  String walletPhone = '01000000000',
  DateTime? executedAt,
}) {
  return TransactionModel(
    id: 'TX-${createdAt.microsecondsSinceEpoch}-${type.name}-$amount',
    walletPhone: walletPhone,
    clientPhone: '01111111111',
    type: type,
    amount: amount,
    status: status,
    createdAt: createdAt,
    executedAt: executedAt,
  );
}

WalletModel _wallet({
  double balance = 100000,
  double dailyTransferLimit = 60000,
  double monthlyTransferLimit = 200000,
  double dailyReceiveLimit = 100000,
  double monthlyReceiveLimit = 200000,
}) {
  return WalletModel(
    id: 'w1',
    phoneNumber: '01000000000',
    title: 'محفظة اختبار',
    provider: WalletProvider.vodafone,
    balance: balance,
    dailyTransferLimit: dailyTransferLimit,
    monthlyTransferLimit: monthlyTransferLimit,
    dailyReceiveLimit: dailyReceiveLimit,
    monthlyReceiveLimit: monthlyReceiveLimit,
  );
}

void main() {
  final now = DateTime(2026, 11, 2, 12, 0);

  group('WalletLimitService.calculateUsage', () {
    test('يحسب عمليات اليوم والشهر الحالي فقط', () {
      final wallet = _wallet();
      final transactions = [
        _tx(type: TransactionType.transfer, amount: 1000, createdAt: now),
        _tx(
          type: TransactionType.transfer,
          amount: 500,
          createdAt: DateTime(2026, 11, 1, 10),
        ),
        _tx(type: TransactionType.receive, amount: 700, createdAt: now),
        _tx(
          type: TransactionType.transfer,
          amount: 9000,
          createdAt: DateTime(2026, 10, 30, 10),
        ),
      ];

      final usage = WalletLimitService.calculateUsage(
        wallet: wallet,
        transactions: transactions,
        now: now,
      );

      expect(usage.dailyTransfer, 1000);
      expect(usage.monthlyTransfer, 1500);
      expect(usage.dailyReceive, 700);
      expect(usage.monthlyReceive, 700);
    });

    test('يستبعد المعلقة والملغاة ويستبعد الاستلام الآجل', () {
      final wallet = _wallet();
      final transactions = [
        _tx(
          type: TransactionType.transfer,
          amount: 100,
          createdAt: now,
          status: TransactionStatus.pending,
        ),
        _tx(
          type: TransactionType.transfer,
          amount: 200,
          createdAt: now,
          status: TransactionStatus.trash,
        ),
        _tx(
          type: TransactionType.receive,
          amount: 300,
          createdAt: now,
          status: TransactionStatus.debt,
        ),
        _tx(
          type: TransactionType.transfer,
          amount: 400,
          createdAt: now,
          status: TransactionStatus.debt,
        ),
      ];

      final usage = WalletLimitService.calculateUsage(
        wallet: wallet,
        transactions: transactions,
        now: now,
      );

      expect(usage.dailyTransfer, 400);
      expect(usage.dailyReceive, 0);
    });

    test('لا يخلط بين المحافظ المختلفة', () {
      final wallet = _wallet();
      final transactions = [
        _tx(type: TransactionType.transfer, amount: 100, createdAt: now),
        _tx(
          type: TransactionType.transfer,
          amount: 999,
          createdAt: now,
          walletPhone: '01111111111',
        ),
      ];

      final usage = WalletLimitService.calculateUsage(
        wallet: wallet,
        transactions: transactions,
        now: now,
      );

      expect(usage.dailyTransfer, 100);
    });

    test('العملية المؤجلة تُحسب من لحظة اعتمادها لا إنشائها', () {
      final wallet = _wallet();
      final transactions = [
        _tx(
          type: TransactionType.transfer,
          amount: 1000,
          createdAt: DateTime(2026, 11, 1, 22),
          executedAt: now,
        ),
      ];

      final usage = WalletLimitService.calculateUsage(
        wallet: wallet,
        transactions: transactions,
        now: now,
      );

      // أُنشئت أمس لكنها نُفّذت اليوم، فتُحسب على حد اليوم.
      expect(usage.dailyTransfer, 1000);
      expect(usage.monthlyTransfer, 1000);

      final yesterdayUsage = WalletLimitService.calculateUsage(
        wallet: wallet,
        transactions: transactions,
        now: DateTime(2026, 11, 1, 23),
      );
      expect(yesterdayUsage.dailyTransfer, 0);
    });
  });

  group('WalletLimitService.check', () {
    test('يسمح بمبلغ داخل الحدود', () {
      final wallet = _wallet();
      final usage = WalletUsageSnapshot(dailyTransfer: 10000);

      final check = WalletLimitService.check(
        wallet: wallet,
        usage: usage,
        isTransfer: true,
        amount: 50000,
      );

      expect(check.allowed, isTrue);
      expect(check.maxAllowed, 50000);
    });

    test('يرفض تجاوز الحد اليومي', () {
      final wallet = _wallet();
      final usage = WalletUsageSnapshot(dailyTransfer: 58000);

      final check = WalletLimitService.check(
        wallet: wallet,
        usage: usage,
        isTransfer: true,
        amount: 5000,
      );

      expect(check.allowed, isFalse);
      expect(check.maxAllowed, 2000);
      expect(check.exceededDaily, isFalse);
      expect(check.message, contains('اليومي'));
    });

    test('يرفض تجاوز الحد الشهري', () {
      final wallet = _wallet();
      final usage = WalletUsageSnapshot(monthlyReceive: 199500);

      final check = WalletLimitService.check(
        wallet: wallet,
        usage: usage,
        isTransfer: false,
        amount: 1000,
      );

      expect(check.allowed, isFalse);
      expect(check.maxAllowed, 500);
      expect(check.message, contains('الشهري'));
    });

    test('يرفض التحويل لو رصيد المحفظة لا يكفي', () {
      final wallet = _wallet(balance: 1000);

      final check = WalletLimitService.check(
        wallet: wallet,
        usage: const WalletUsageSnapshot(),
        isTransfer: true,
        amount: 1500,
        networkFee: 10,
      );

      expect(check.allowed, isFalse);
      expect(check.insufficientBalance, isTrue);
      expect(check.message, contains('رصيد'));
    });

    test('يسمح بالمبلغ المتبقي بالضبط مع هامش التقريب', () {
      final wallet = _wallet();
      final usage = WalletUsageSnapshot(dailyTransfer: 59000);

      final check = WalletLimitService.check(
        wallet: wallet,
        usage: usage,
        isTransfer: true,
        amount: 1000,
      );

      expect(check.allowed, isTrue);
    });
  });
}
