import 'package:cashawy_pro/core/theme/parsers/cash_sms_parser.dart';


/// نتيجة الفحص الأمني للرسالة (مستوحاة من نظام Tahweel)
enum SecurityVerification {
  verified,          // موثوقة ومطابقة للرصيد 100%
  balanceMismatch,   // خطر: الرصيد بالرسالة لا يطابق (الرصيد السابق + المبلغ)!
  noBalanceInSms,    // تحذير: الرسالة لا تحتوي على الرصيد المتبقي
  untrustedSender,   // خطر نصاب: الرسالة مرسلة من رقم شخصي وليست من الشركة!
  aboveReviewLimit,  // معلقة: المبلغ أكبر من حد المراجعة الآمن
  duplicateSms,      // مكررة: تم تسجيل هذه الرسالة مسبقاً (Fingerprint موجود)
}

class SecurityCheckResult {
  final SecurityVerification status;
  final bool isSafeForAutoSave; // هل نسمح بالعد التنازلي والتسجيل التلقائي؟
  final double? expectedBalance;
  final String fingerprint;
  final String securityMessage;

  SecurityCheckResult({
    required this.status,
    required this.isSafeForAutoSave,
    this.expectedBalance,
    required this.fingerprint,
    required this.securityMessage,
  });
}

class CashawySecurityShield {
  // قائمة المرسلين الموثوقين رسمياً (Trusted Senders Gate)
  static const List<String> trustedSenders = [
    'vf-cash',
    'vodafone',
    'vfcash',
    'e& money',
    'etisalat',
    'orange cash',
    'orangecash',
    'we pay',
    'wepay',
  ];

  // الكلمات المالية المسموح بها لفلتر الخصوصية (لمنع قراءة رسائل الـ OTP الشخصية)
  static const List<String> financialKeywords = [
    'جنيه',
    'ج.م',
    'تم استلام',
    'تم تحويل',
    'رصيدك',
    'رصيد حسابك',
    'egp',
    'balance',
  ];

  // سجل البصمات لمنع تسجيل نفس الرسالة مرتين (Fingerprint Deduplication)
  static final Set<String> _processedFingerprints = {};

  /// 1. فلتر الخصوصية: هل هذه الرسالة تخص الكاش أم رسالة شخصية / OTP؟
  static bool isFinancialSms(String sender, String body) {
    final lowerSender = sender.toLowerCase().trim();
    final lowerBody = body.toLowerCase();

    // استبعاد فوري لأي رسالة تحتوي على كود تفعيل سري (OTP)
    if (lowerBody.contains('otp') ||
        lowerBody.contains('كود التفعيل') ||
        lowerBody.contains('رمز التحقق') ||
        lowerBody.contains('لا تشارك')) {
      return false;
    }

    final isTrusted = trustedSenders.any((s) => lowerSender.contains(s));
    final hasKeyword = financialKeywords.any((k) => lowerBody.contains(k));

    return isTrusted || hasKeyword;
  }

  /// 2. توليد بصمة رقمية فريدة للرسالة لمنع التكرار
  static String generateFingerprint(String sender, String body, String txRef) {
    final raw = '${sender.trim().toLowerCase()}|${body.trim()}|$txRef';
    int hash = 5381;
    for (int i = 0; i < raw.length; i++) {
      hash = ((hash << 5) + hash) + raw.codeUnitAt(i);
    }
    return 'FP-${hash.abs().toRadixString(16).toUpperCase()}';
  }

  /// 3. الفحص الأمني الشامل للرسالة ومطابقة الرصيد الرياضي
  static SecurityCheckResult inspectSms({
    required String sender,
    required ParsedCashSms parsedSms,
    required double currentWalletBalance,
    bool verifyBalanceEnabled = true,
    double balanceMargin = 0.05, // هامش فروق القروش البسيطة (5 قروش)
    double? reviewAboveAmount = 3000.0, // تعليق تلقائي لأي عملية فوق 3000 جنيه للمراجعة
  }) {
    final fingerprint = generateFingerprint(sender, parsedSms.rawMessage, parsedSms.transactionRef);

    // أ. فحص التكرار (Duplicate Fingerprint)
    if (_processedFingerprints.contains(fingerprint)) {
      return SecurityCheckResult(
        status: SecurityVerification.duplicateSms,
        isSafeForAutoSave: false,
        fingerprint: fingerprint,
        securityMessage: '🚫 رسالة مكررة! تم التقاط وتسجيل هذه العملية من قبل.',
      );
    }

    // ب. فحص المرسل الموثوق (Trusted Sender Gate) ضد رسائل النصب من أرقام شخصية
    final normalizedSender = sender.toLowerCase().trim();
    final isPhoneSender = RegExp(r'^\+?[0-9]{10,14}$').hasMatch(normalizedSender);
    final isTrusted = !isPhoneSender &&
        trustedSenders.any((trusted) => normalizedSender.contains(trusted));

    if (!isTrusted) {
      return SecurityCheckResult(
        status: SecurityVerification.untrustedSender,
        isSafeForAutoSave: false,
        fingerprint: fingerprint,
        securityMessage:
            '🚨 تحذير أمني خطير: الرسالة مرسلة من رقم غير موثوق ($sender) وليست من شركة الاتصالات! قد تكون رسالة مزيفة.',
      );
    }

    // ج. الحساب الرياضي لتطابق الرصيد (Balance Verification)
    final double expectedBalance = parsedSms.type == TransactionType.receive
        ? currentWalletBalance + parsedSms.amount
        : currentWalletBalance - parsedSms.amount;

    if (verifyBalanceEnabled) {
      if (parsedSms.balanceAfter == null) {
        return SecurityCheckResult(
          status: SecurityVerification.noBalanceInSms,
          isSafeForAutoSave: false,
          expectedBalance: expectedBalance,
          fingerprint: fingerprint,
          securityMessage:
              '⚠️ معلقة للمراجعة: الرسالة لا تحتوي على "الرصيد الحالي" للتأكد من صحة الإيداع.',
        );
      }

      final diff = (expectedBalance - parsedSms.balanceAfter!).abs();
      // في التحويل قد توجد رسوم شبكة (1 إلى 15 جنيه)، أما في الاستلام فالرصيد يجب أن يتطابق بدقة!
      final allowedDiff = parsedSms.type == TransactionType.receive ? balanceMargin : 15.0;

      if (diff > allowedDiff) {
        return SecurityCheckResult(
          status: SecurityVerification.balanceMismatch,
          isSafeForAutoSave: false,
          expectedBalance: expectedBalance,
          fingerprint: fingerprint,
          securityMessage:
              '🚨 عدم تطابق الرصيد! الرصيد المتوقع بالمحفظة (${expectedBalance.toStringAsFixed(2)} ج.م) بينما المكتوب بالرسالة (${parsedSms.balanceAfter!.toStringAsFixed(2)} ج.م). راجع المحفظة فوراً!',
        );
      }
    }

    // د. فحص سقف المبالغ الكبيرة (Review Above Amount)
    if (reviewAboveAmount != null && parsedSms.amount >= reviewAboveAmount) {
      return SecurityCheckResult(
        status: SecurityVerification.aboveReviewLimit,
        isSafeForAutoSave: false,
        expectedBalance: expectedBalance,
        fingerprint: fingerprint,
        securityMessage:
            '🛡️ مبلغ كبير (${parsedSms.amount.toInt()} ج.م): تم إيقاف التسجيل التلقائي لحين المراجعة اليدوية والاعتماد.',
      );
    }

    // هـ. العملية سليمة وموثوقة 100%
    return SecurityCheckResult(
      status: SecurityVerification.verified,
      isSafeForAutoSave: true,
      expectedBalance: expectedBalance,
      fingerprint: fingerprint,
      securityMessage: '✅ رسالة أصلية موثوقة وتطابق رصيد المحفظة الفعلي.',
    );
  }

  /// اعتماد البصمة بعد حفظ العملية لمنع تكرارها مستقبلاً
  static void markFingerprintAsProcessed(String fingerprint) {
    _processedFingerprints.add(fingerprint);
  }
}