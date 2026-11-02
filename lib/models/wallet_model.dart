import 'package:cashawy_pro/core/theme/parsers/cash_sms_parser.dart';

class WalletModel {
  final String id;
  final String
  phoneNumber; // رقم الخط أو عنوان الدفع اللحظي (IPA مثل: market@instapay)
  String title; // اسم مميز (مثال: فودافون كاش كاشير، إنستاباي الأهلي)
  final WalletProvider provider; // فودافون، أورنج، اتصالات، وي، إنستاباي
  final int simSlot; // 0 للشريحة 1، 1 للشريحة 2، -1 لإنستاباي (لا يحتاج شريحة)
  final String pinCode; // الرقم السري (للتحويل التلقائي بـ USSD للمحافظ)

  double balance; // الرصيد الفعلي الحالي

  // حدود الاستخدام (الليميت اليومي والشهري)
  final double dailyTransferLimit;
  final double monthlyTransferLimit;
  final double dailyReceiveLimit;
  final double monthlyReceiveLimit;

  // المبالغ المستخدمة فعلياً
  double usedDailyTransfer;
  double usedMonthlyTransfer;
  double usedDailyReceive;
  double usedMonthlyReceive;

  WalletModel({
    required this.id,
    required this.phoneNumber,
    required this.title,
    required this.provider,
    this.simSlot = 0,
    this.pinCode = '',
    this.balance = 0.0,
    double? dailyTransferLimit,
    double? monthlyTransferLimit,
    double? dailyReceiveLimit,
    double? monthlyReceiveLimit,
    this.usedDailyTransfer = 0.0,
    this.usedMonthlyTransfer = 0.0,
    this.usedDailyReceive = 0.0,
    this.usedMonthlyReceive = 0.0,
  }) : dailyTransferLimit =
           dailyTransferLimit ??
           (provider == WalletProvider.instapay ? 120000.0 : 60000.0),
       monthlyTransferLimit =
           monthlyTransferLimit ??
           (provider == WalletProvider.instapay ? 400000.0 : 200000.0),
       dailyReceiveLimit =
           dailyReceiveLimit ??
           (provider == WalletProvider.instapay ? 120000.0 : 100000.0),
       monthlyReceiveLimit =
           monthlyReceiveLimit ??
           (provider == WalletProvider.instapay ? 400000.0 : 200000.0);

  bool get isInstaPay => provider == WalletProvider.instapay;

  static double _percent(double used, double limit) {
    if (limit <= 0) return used > 0 ? 1.0 : 0.0;
    return (used / limit).clamp(0.0, 1.0);
  }

  double get dailyTransferPercent =>
      _percent(usedDailyTransfer, dailyTransferLimit);
  double get monthlyTransferPercent =>
      _percent(usedMonthlyTransfer, monthlyTransferLimit);
  double get dailyReceivePercent =>
      _percent(usedDailyReceive, dailyReceiveLimit);
  double get monthlyReceivePercent =>
      _percent(usedMonthlyReceive, monthlyReceiveLimit);

  double get dailyTransferRemaining =>
      (dailyTransferLimit - usedDailyTransfer).clamp(0.0, double.infinity);
  double get monthlyTransferRemaining =>
      (monthlyTransferLimit - usedMonthlyTransfer).clamp(0.0, double.infinity);
  double get dailyReceiveRemaining =>
      (dailyReceiveLimit - usedDailyReceive).clamp(0.0, double.infinity);
  double get monthlyReceiveRemaining =>
      (monthlyReceiveLimit - usedMonthlyReceive).clamp(0.0, double.infinity);

  /// أقصى مبلغ يمكن استلامه الآن (اليومي والشهري معاً).
  double get availableReceiveNow =>
      dailyReceiveRemaining < monthlyReceiveRemaining
      ? dailyReceiveRemaining
      : monthlyReceiveRemaining;

  /// أقصى مبلغ يمكن تحويله الآن (اليومي والشهري معاً).
  double get availableTransferNow =>
      dailyTransferRemaining < monthlyTransferRemaining
      ? dailyTransferRemaining
      : monthlyTransferRemaining;

  bool get isNearLimit =>
      dailyTransferPercent >= 0.85 ||
      monthlyTransferPercent >= 0.85 ||
      dailyReceivePercent >= 0.85 ||
      monthlyReceivePercent >= 0.85;

  bool get hasExceededAnyLimit =>
      usedDailyTransfer > dailyTransferLimit + 0.01 ||
      usedMonthlyTransfer > monthlyTransferLimit + 0.01 ||
      usedDailyReceive > dailyReceiveLimit + 0.01 ||
      usedMonthlyReceive > monthlyReceiveLimit + 0.01;

  WalletModel copyWith({
    String? id,
    String? phoneNumber,
    String? title,
    WalletProvider? provider,
    int? simSlot,
    String? pinCode,
    double? balance,
    double? dailyTransferLimit,
    double? monthlyTransferLimit,
    double? dailyReceiveLimit,
    double? monthlyReceiveLimit,
    double? usedDailyTransfer,
    double? usedMonthlyTransfer,
    double? usedDailyReceive,
    double? usedMonthlyReceive,
  }) {
    return WalletModel(
      id: id ?? this.id,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      title: title ?? this.title,
      provider: provider ?? this.provider,
      simSlot: simSlot ?? this.simSlot,
      pinCode: pinCode ?? this.pinCode,
      balance: balance ?? this.balance,
      dailyTransferLimit: dailyTransferLimit ?? this.dailyTransferLimit,
      monthlyTransferLimit: monthlyTransferLimit ?? this.monthlyTransferLimit,
      dailyReceiveLimit: dailyReceiveLimit ?? this.dailyReceiveLimit,
      monthlyReceiveLimit: monthlyReceiveLimit ?? this.monthlyReceiveLimit,
      usedDailyTransfer: usedDailyTransfer ?? this.usedDailyTransfer,
      usedMonthlyTransfer: usedMonthlyTransfer ?? this.usedMonthlyTransfer,
      usedDailyReceive: usedDailyReceive ?? this.usedDailyReceive,
      usedMonthlyReceive: usedMonthlyReceive ?? this.usedMonthlyReceive,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'phoneNumber': phoneNumber,
    'title': title,
    'provider': provider.name,
    'simSlot': simSlot,
    'pinCode': pinCode,
    'balance': balance,
    'dailyTransferLimit': dailyTransferLimit,
    'monthlyTransferLimit': monthlyTransferLimit,
    'dailyReceiveLimit': dailyReceiveLimit,
    'monthlyReceiveLimit': monthlyReceiveLimit,
    'usedDailyTransfer': usedDailyTransfer,
    'usedMonthlyTransfer': usedMonthlyTransfer,
    'usedDailyReceive': usedDailyReceive,
    'usedMonthlyReceive': usedMonthlyReceive,
  };

  factory WalletModel.fromJson(Map<String, dynamic> json) {
    return WalletModel(
      id: json['id'] ?? '',
      phoneNumber: json['phoneNumber'] ?? '',
      title: json['title'] ?? 'محفظة',
      provider: WalletProvider.values.firstWhere(
        (e) => e.name == json['provider'],
        orElse: () => WalletProvider.vodafone,
      ),
      simSlot: json['simSlot'] ?? 0,
      pinCode: json['pinCode'] ?? '',
      balance: (json['balance'] ?? 0.0).toDouble(),
      dailyTransferLimit: (json['dailyTransferLimit'] as num?)?.toDouble(),
      monthlyTransferLimit: (json['monthlyTransferLimit'] as num?)?.toDouble(),
      dailyReceiveLimit: (json['dailyReceiveLimit'] as num?)?.toDouble(),
      monthlyReceiveLimit: (json['monthlyReceiveLimit'] as num?)?.toDouble(),
      usedDailyTransfer: (json['usedDailyTransfer'] ?? 0.0).toDouble(),
      usedMonthlyTransfer: (json['usedMonthlyTransfer'] ?? 0.0).toDouble(),
      usedDailyReceive: (json['usedDailyReceive'] ?? 0.0).toDouble(),
      usedMonthlyReceive: (json['usedMonthlyReceive'] ?? 0.0).toDouble(),
    );
  }
}
