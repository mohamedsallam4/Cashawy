enum TransactionType { receive, transfer, unknown }

enum WalletProvider {
  vodafone,
  orange,
  etisalat,
  we,
  instapay, // دعم حسابات إنستاباي البنكية
}

class ParsedCashSms {
  final TransactionType type;       // نوع العملية: استلام أو تحويل
  final WalletProvider provider;    // الشبكة (فودافون، اتصالات، إلخ)
  final double amount;              // المبلغ المحول أو المستلم
  final String partyPhone;          // رقم هاتف العميل (الراسل أو المستلم)
  final String? partyName;          // اسم العميل لو موجود في الرسالة
  final double? balanceAfter;       // رصيد المحفظة المتبقي بعد العملية
  final String transactionRef;      // رقم العملية المرجعي (SMS-...)
  final String rawMessage;          // نص الرسالة الأصلي
  final DateTime timestamp;         // وقت العملية

  ParsedCashSms({
    required this.type,
    required this.provider,
    required this.amount,
    required this.partyPhone,
    this.partyName,
    this.balanceAfter,
    required this.transactionRef,
    required this.rawMessage,
    required this.timestamp,
  });
}

class CashSmsParser {
  /// دالة ذكية لتحليل أي رسالة كاش واستخراج كافة تفاصيلها المالية
  static ParsedCashSms? parse({
    required String sender,
    required String messageBody,
  }) {
    // توحيد الأرقام لو الرسالة فيها أرقام عربية (٠١٢٣٤٥٦٧٨٩)
    final normalizedBody = _normalizeArabicNumbers(messageBody);

    // 1. تحديد نوع الشبكة من اسم الراسل أو محتوى الرسالة
    final provider = _detectProvider(sender, normalizedBody);

    // 2. تحديد نوع العملية (استلام أموال أم تحويل أموال)
    final type = _detectTransactionType(normalizedBody);
    if (type == TransactionType.unknown) return null;

    // 3. استخراج المبلغ الأساسي للعملية
    final amount = _extractAmount(normalizedBody, type);
    if (amount == null || amount <= 0) return null;

    // 4. استخراج رقم هاتف الطرف الآخر (العميل)
    final phone = _extractPhoneNumber(normalizedBody) ?? 'غير معروف';

    // 5. استخراج اسم العميل (إن وجد في الرسالة)
    final clientName = _extractClientName(normalizedBody, phone);

    // 6. استخراج الرصيد المتبقي بعد العملية (مهم جداً لتحديث المحفظة تلقائياً)
    final balanceAfter = _extractBalanceAfter(normalizedBody);

    // 7. استخراج أو توليد رقم العملية المرجعي بنفس الصيغة الاحترافية
    final txRef = _extractOrGenerateRef(normalizedBody, amount);

    return ParsedCashSms(
      type: type,
      provider: provider,
      amount: amount,
      partyPhone: phone,
      partyName: clientName,
      balanceAfter: balanceAfter,
      transactionRef: txRef,
      rawMessage: messageBody,
      timestamp: DateTime.now(),
    );
  }

  static WalletProvider _detectProvider(String sender, String body) {
    final s = sender.toLowerCase();
    if (s.contains('vf-cash') || s.contains('vodafone') || body.contains('فودافون كاش')) {
      return WalletProvider.vodafone;
    } else if (s.contains('etisalat') || s.contains('e&') || body.contains('اتصالات كاش')) {
      return WalletProvider.etisalat;
    } else if (s.contains('orange') || body.contains('اورنج كاش')) {
      return WalletProvider.orange;
    } else if (s.contains('we') || body.contains('we pay')) {
      return WalletProvider.we;
    }
    // تحديد تلقائي من بداية رقم الهاتف لو المرسل غير واضح
    final phone = _extractPhoneNumber(body);
    if (phone != null) {
      if (phone.startsWith('010')) return WalletProvider.vodafone;
      if (phone.startsWith('011')) return WalletProvider.etisalat;
      if (phone.startsWith('012')) return WalletProvider.orange;
      if (phone.startsWith('015')) return WalletProvider.we;
    }
    return WalletProvider.vodafone;
  }

  static TransactionType _detectTransactionType(String body) {
    if (body.contains('تم استلام') ||
        body.contains('استلمت') ||
        body.contains('تم إيداع') ||
        body.contains('وصلك مبلغ')) {
      return TransactionType.receive;
    }
    if (body.contains('تم تحويل') ||
        body.contains('حولت') ||
        body.contains('تم خصم') ||
        body.contains('تم ارسال')) {
      return TransactionType.transfer;
    }
    return TransactionType.unknown;
  }

  static double? _extractAmount(String body, TransactionType type) {
    // البحث عن الأرقام التي تأتي بعد كلمات المفتاح أو قبل كلمة جنيه / ج.م
    final patterns = [
      RegExp(r'(?:تم استلام|تم تحويل|مبلغ|بقيمة)\s*([0-9]+(?:\.[0-9]+)?)\s*(?:جنيه|ج\.م|EGP|ج)?'),
      RegExp(r'([0-9]+(?:\.[0-9]+)?)\s*(?:جنيه|ج\.م|EGP)'),
    ];

    for (final regex in patterns) {
      final match = regex.firstMatch(body);
      if (match != null && match.group(1) != null) {
        return double.tryParse(match.group(1)!);
      }
    }
    return null;
  }

  static String? _extractPhoneNumber(String body) {
    // صيغة أرقام الموبايل المصرية (11 رقم يبدأ بـ 010 أو 011 أو 012 أو 015)
    final phoneRegex = RegExp(r'\b(01[0125][0-9]{8})\b');
    final match = phoneRegex.firstMatch(body);
    return match?.group(1);
  }

  static String? _extractClientName(String body, String phone) {
    // في بعض الرسائل يكون الاسم مكتوباً بعد الرقم أو بين قوسين أو بعد كلمة "باسم" أو "لـ"
    final namePatterns = [
      RegExp('(?:باسم|العميل|لـ|من)\\s+$phone\\s*[-–]?\\s*([A-Za-zأ-ي\\s]{3,30})'),
      RegExp('([A-Za-z]{2,}\\s+[A-Za-z\\s]{2,})'), // للأسماء الإنجليزية في الرسائل مثل Mohamed A Abdelhamid
    ];

    for (final regex in namePatterns) {
      final match = regex.firstMatch(body);
      if (match != null && match.group(1) != null) {
        final candidate = match.group(1)!.trim();
        if (!candidate.toLowerCase().contains('vodafone') &&
            !candidate.toLowerCase().contains('cash') &&
            !candidate.toLowerCase().contains('egp')) {
          return candidate;
        }
      }
    }
    return null;
  }

  static double? _extractBalanceAfter(String body) {
    // استخراج الرصيد المتبقي مثل: "رصيد حسابك الحالي 803.00 جنيه" أو "رصيدك الحالي هو 803 جنيه"
    final balanceRegex = RegExp(
      r'(?:رصيدك الحالي|رصيد حسابك|الرصيد المتبقي|رصيدك هو)[^0-9]*([0-9]+(?:\.[0-9]+)?)',
    );
    final match = balanceRegex.firstMatch(body);
    if (match != null && match.group(1) != null) {
      return double.tryParse(match.group(1)!);
    }
    return null;
  }

  static String _extractOrGenerateRef(String body, double amount) {
    // محاولة استخراج رقم العملية من الرسالة
    final refRegex = RegExp(r'(?:رقم العملية|رقم المرجع|عملية رقم)[^0-9]*([0-9]{6,20})');
    final match = refRegex.firstMatch(body);
    final extractedId = match?.group(1) ?? DateTime.now().millisecondsSinceEpoch.toString().substring(3);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final cleanAmount = amount.toInt();

    // توليد الكود الاحترافي المطابق للنظام: SMS-1063597136-1789525713000-10
    return 'SMS-$extractedId-$timestamp-$cleanAmount';
  }

  static String _normalizeArabicNumbers(String input) {
    const arabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    var result = input;
    for (int i = 0; i < arabic.length; i++) {
      result = result.replaceAll(arabic[i], english[i]);
    }
    return result;
  }
}