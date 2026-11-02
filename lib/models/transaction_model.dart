import 'package:cashawy_pro/core/theme/parsers/cash_sms_parser.dart';

enum TransactionStatus {
  completed, // ناجحة
  pending, // مؤجل (تحويل مؤجل)
  debt, // آجل (دين على العميل)
  trash, // في سلة الحذف
}

class TransactionModel {
  final String id; // رقم العملية (مثل: SMS-1063597136...)
  final String walletPhone; // رقم محفظة المحل التي تمت عليها العملية
  final String clientPhone; // رقم هاتف العميل (مرسل أو مستقبل)
  final String? clientName; // اسم العميل إن وجد
  final TransactionType type; // تحويل أم استلام (سحب)
  final double amount; // المبلغ الأساسي
  final double commission; // عمولة المحل (أرباح العملية)
  final double networkFee; // رسوم التحويل الخاصة بالشبكة
  final bool deductCommission; // هل تم خصم العمولة من المبلغ؟
  final TransactionStatus status; // حالة العملية (ناجحة / مؤجل / آجل)
  final String? notes; // ملاحظة السحب أو التحويل (اختياري)
  final DateTime createdAt; // تاريخ ووقت العملية بالثانية

  /// لحظة التنفيذ الفعلي على المحفظة. تختلف عن [createdAt] في العمليات
  /// المؤجلة التي تُسجَّل أولاً ثم تُعتمد لاحقاً، وعليها يُحسب استهلاك الليميت.
  final DateTime? executedAt;

  TransactionModel({
    required this.id,
    required this.walletPhone,
    required this.clientPhone,
    this.clientName,
    required this.type,
    required this.amount,
    this.commission = 0.0,
    this.networkFee = 0.0,
    this.deductCommission = false,
    this.status = TransactionStatus.completed,
    this.notes,
    required this.createdAt,
    this.executedAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'walletPhone': walletPhone,
    'clientPhone': clientPhone,
    'clientName': clientName,
    'type': type.name,
    'amount': amount,
    'commission': commission,
    'networkFee': networkFee,
    'deductCommission': deductCommission,
    'status': status.name,
    'notes': notes,
    'createdAt': createdAt.toIso8601String(),
    'executedAt': executedAt?.toIso8601String(),
  };

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: json['id'] ?? '',
      walletPhone: json['walletPhone'] ?? '',
      clientPhone: json['clientPhone'] ?? '',
      clientName: json['clientName'],
      type: TransactionType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => TransactionType.transfer,
      ),
      amount: (json['amount'] ?? 0.0).toDouble(),
      commission: (json['commission'] ?? 0.0).toDouble(),
      networkFee: (json['networkFee'] ?? 0.0).toDouble(),
      deductCommission: json['deductCommission'] ?? false,
      status: TransactionStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => TransactionStatus.completed,
      ),
      notes: json['notes'],
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      executedAt: DateTime.tryParse(json['executedAt'] ?? ''),
    );
  }

  TransactionModel copyWith({
    String? id,
    String? walletPhone,
    String? clientPhone,
    String? clientName,
    TransactionType? type,
    double? amount,
    double? commission,
    double? networkFee,
    bool? deductCommission,
    TransactionStatus? status,
    String? notes,
    DateTime? createdAt,
    DateTime? executedAt,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      walletPhone: walletPhone ?? this.walletPhone,
      clientPhone: clientPhone ?? this.clientPhone,
      clientName: clientName ?? this.clientName,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      commission: commission ?? this.commission,
      networkFee: networkFee ?? this.networkFee,
      deductCommission: deductCommission ?? this.deductCommission,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      executedAt: executedAt ?? this.executedAt,
    );
  }
}
