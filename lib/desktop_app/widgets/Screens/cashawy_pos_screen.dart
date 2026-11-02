import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:cashawy_pro/core/database/cashawy_store.dart';
import 'package:cashawy_pro/core/security/cashawy_security_shield.dart';
import 'package:cashawy_pro/core/services/native_sms_listener.dart';
import 'package:cashawy_pro/core/theme/app_theme.dart';
import 'package:cashawy_pro/core/theme/parsers/cash_sms_parser.dart';
import 'package:cashawy_pro/desktop_app/widgets/dashboard_overview_panel.dart';
import 'package:cashawy_pro/desktop_app/widgets/transaction_form_panel.dart';
import 'package:cashawy_pro/mobile_app/screens/sms_parser_test_screen.dart';
import 'package:cashawy_pro/models/transaction_model.dart';

import '../live_transaction_toast.dart';

class CashawyPosScreen extends StatefulWidget {
  const CashawyPosScreen({super.key});

  @override
  State<CashawyPosScreen> createState() => _CashawyPosScreenState();
}

class _CashawyPosScreenState extends State<CashawyPosScreen> {
  StreamSubscription? _cloudTxSubscription;
  StreamSubscription? _cloudStoreSubscription;
  Timer? _limitRefreshTimer;

  @override
  void initState() {
    super.initState();
    // 1. استعادة أرصدة الدرج والمحافظ المحفوظة في السحابة فور تشغيل الواجهة
    CashawyStore.instance.fetchStoreStateFromCloud();

    // 2. تفعيل الاستماع لرادار العمليات لعرض الإشعار المنبثق الفوري
    CashawyStore.instance.liveTransactionAlert.addListener(_handleLiveAlert);

    NativeSmsListener.startListening(
      onCashSmsReceived: (_) {},
      onSecureCashSmsReceived: (sender, parsedSms) {
        if (!mounted) return;
        _showAutoConfirmModal(sender, parsedSms);
      },
    );

    // 3. بدء المزامنة السحابية الحية
    _initCloudSync();

    // 4. تصفير الليميت اليومي/الشهري تلقائياً حتى لو البرنامج فاضل مفتوح.
    _limitRefreshTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      CashawyStore.instance.refreshWalletLimits();
    });
  }

  void _initCloudSync() {
    const storeId = 'supermarket_main_branch';
    bool isInitialLoad = true;

    // 1. الاستماع لعمليات السحابة
    _cloudTxSubscription = FirebaseFirestore.instance
        .collection('stores')
        .doc(storeId)
        .collection('live_transactions')
        .orderBy('timestamp', descending: true)
        .limit(25)
        .snapshots()
        .listen(
          (snapshot) {
            if (isInitialLoad) {
              // عند فتح الشاشة أو الهوت ريستارت: تنزيل العمليات القديمة بهدوء وبالترتيب الصحيح (الأحدث بالأعلى)
              for (final doc in snapshot.docs.reversed) {
                final data = doc.data();
                CashawyStore.instance.addCloudParsedTransaction(
                  cloudId: doc.id,
                  amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
                  typeStr: (data['type'] as String?) ?? 'receive',
                  walletPhone:
                      (data['walletPhone'] as String?) ?? 'فودافون كاش',
                  clientPhone: (data['clientPhone'] as String?) ?? '',
                  notes: (data['notes'] as String?) ?? '',
                  triggerAlert: false, // كتم الإشعار للعمليات القديمة
                );
              }
              isInitialLoad = false;
              return;
            }

            // بعد اكتمال التحميل: أي معاملة جديدة تصل الآن فقط تظهر في الأعلى وتطلق التنبيه
            for (final change in snapshot.docChanges) {
              if (change.type == DocumentChangeType.added) {
                final data = change.doc.data();
                if (data != null) {
                  CashawyStore.instance.addCloudParsedTransaction(
                    cloudId: change.doc.id,
                    amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
                    typeStr: (data['type'] as String?) ?? 'receive',
                    walletPhone:
                        (data['walletPhone'] as String?) ?? 'فودافون كاش',
                    clientPhone: (data['clientPhone'] as String?) ?? '',
                    notes: (data['notes'] as String?) ?? '',
                    triggerAlert: true, // إطلاق الإشعار للعملية اللحظية الجديدة
                  );
                }
              }
            }
          },
          onError: (e) {
            debugPrint('Cloud transactions sync error: $e');
          },
        );

    // 2. تحديث رصيد المحفظة ودرج الكاشير الفعلي من السحابة لحظياً
    _cloudStoreSubscription = FirebaseFirestore.instance
        .collection('stores')
        .doc(storeId)
        .snapshots()
        .listen(
          (snapshot) {
            if (snapshot.exists && snapshot.data() != null) {
              final data = snapshot.data()!;

              // تحديث درج الكاشير تلقائياً إذا عُدّل من الموبايل أو السحابة
              if (data.containsKey('cashInDrawer')) {
                final cloudCash = (data['cashInDrawer'] as num?)?.toDouble();
                if (cloudCash != null) {
                  CashawyStore.instance.applyCloudCashInDrawer(cloudCash);
                }
              }

              // تحديث رصيد المحفظة عند التقاط رسالة SMS
              if (data.containsKey('lastSmsSync')) {
                final syncData = data['lastSmsSync'] as Map<String, dynamic>?;
                if (syncData != null) {
                  final updatedBalance =
                      (syncData['updatedBalance'] as num?)?.toDouble() ?? 0.0;
                  final provider = (syncData['provider'] as String?) ?? '';

                  CashawyStore.instance.updateWalletBalanceFromCloud(
                    providerName: provider,
                    newBalance: updatedBalance,
                  );
                }
              }
            }
          },
          onError: (e) {
            debugPrint('Cloud store balance sync error: $e');
          },
        );
  }

  void _handleLiveAlert() {
    final tx = CashawyStore.instance.liveTransactionAlert.value;
    if (tx != null && mounted) {
      LiveTransactionToast.show(context, tx);
    }
  }

  @override
  void dispose() {
    _cloudTxSubscription?.cancel();
    _cloudStoreSubscription?.cancel();
    _limitRefreshTimer?.cancel();
    CashawyStore.instance.liveTransactionAlert.removeListener(_handleLiveAlert);
    super.dispose();
  }

  void _showAutoConfirmModal(String sender, ParsedCashSms parsedSms) {
    final currentBalance = CashawyStore.instance.selectedWallet.balance;
    final securityCheck = CashawySecurityShield.inspectSms(
      sender: sender,
      parsedSms: parsedSms,
      currentWalletBalance: currentBalance,
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _LiveAutoCaptureDialog(
        sender: sender,
        parsedSms: parsedSms,
        securityCheck: securityCheck,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shield_rounded, color: AppColors.primary),
            SizedBox(width: 8),
            Text('نظام كشاوي المحمي - نقطة البيع والتحويلات'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'إعدادات الشرائح والرادار (USSD & SMS)',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const Directionality(
                    textDirection: TextDirection.rtl,
                    child: SmsParserTestScreen(),
                  ),
                ),
              );
            },
            icon: const Icon(Icons.settings_cell),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktopLayout = constraints.maxWidth >= 900;

          if (isDesktopLayout) {
            return const SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 7, child: DashboardOverviewPanel()),
                  SizedBox(width: 16),
                  Expanded(flex: 4, child: TransactionFormPanel()),
                ],
              ),
            );
          }

          return const SingleChildScrollView(
            padding: EdgeInsets.all(12),
            child: Column(
              children: [
                DashboardOverviewPanel(),
                SizedBox(height: 16),
                TransactionFormPanel(),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// النافذة المنبثقة المزودة بدرع الحماية ضد الرسائل المزيفة
class _LiveAutoCaptureDialog extends StatefulWidget {
  final String sender;
  final ParsedCashSms parsedSms;
  final SecurityCheckResult securityCheck;

  const _LiveAutoCaptureDialog({
    required this.sender,
    required this.parsedSms,
    required this.securityCheck,
  });

  @override
  State<_LiveAutoCaptureDialog> createState() => _LiveAutoCaptureDialogState();
}

class _LiveAutoCaptureDialogState extends State<_LiveAutoCaptureDialog> {
  int _secondsLeft = 7;
  Timer? _timer;
  final TextEditingController _commissionController = TextEditingController();
  bool _isDebt = false;

  @override
  void initState() {
    super.initState();
    if (widget.securityCheck.isSafeForAutoSave) {
      _startCountdown();
    }
  }

  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft > 1) {
        setState(() => _secondsLeft--);
      } else {
        timer.cancel();
        _saveToStoreAndClose();
      }
    });
  }

  void _saveToStoreAndClose() {
    CashawySecurityShield.markFingerprintAsProcessed(
      widget.securityCheck.fingerprint,
    );

    final commission =
        double.tryParse(_commissionController.text.trim()) ?? 0.0;
    final result = CashawyStore.instance.recordTransaction(
      type: widget.parsedSms.type,
      amount: widget.parsedSms.amount,
      clientPhone: widget.parsedSms.partyPhone,
      clientName: widget.parsedSms.partyName,
      commission: commission,
      status: _isDebt ? TransactionStatus.debt : TransactionStatus.completed,
      customRef: widget.parsedSms.transactionRef,
      exactBalanceFromSms: widget.parsedSms.balanceAfter,
      wallet: CashawyStore.instance.walletForProvider(
        widget.parsedSms.provider,
      ),
      // الرسالة حقيقية ووصلت من الشبكة، فلا يصح رفض تسجيلها بسبب
      // ليميت محلي؛ سيتم احتسابها وسيظهر التجاوز للمالك.
      enforceLimits: false,
    );

    if (!result.success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.error ?? 'تعذر تسجيل العملية'),
            backgroundColor: AppColors.alertRed,
          ),
        );
      }
      return;
    }

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '✅ تم اعتماد العملية وتحديث أرصدة المحفظة والخزنة بأمان!',
          ),
          backgroundColor: AppColors.receiveGreen,
        ),
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _commissionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSafe = widget.securityCheck.isSafeForAutoSave;
    final isReceive = widget.parsedSms.type == TransactionType.receive;

    final Color headerColor = !isSafe
        ? const Color(0xFF7C3AED)
        : (isReceive ? const Color(0xFF00A86B) : const Color(0xFF1D4ED8));

    final String titleText = !isSafe
        ? 'عملية معلقة للمراجعة الأمنية 🛡️'
        : (isReceive ? 'استلام أموال' : 'تحويل أموال');

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: 18,
                    horizontal: 20,
                  ),
                  color: headerColor,
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close, color: Colors.white),
                          ),
                          Expanded(
                            child: Text(
                              titleText,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 40),
                        ],
                      ),
                      Text(
                        'المرسل: ${widget.sender}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${widget.parsedSms.amount.toInt()} ج.م',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          isSafe
                              ? '✅ فحص الرصيد سليم - تسجيل تلقائي'
                              : '⛔ تم إيقاف التسجيل التلقائي لحمايتك!',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isSafe
                              ? const Color(0xFFECFDF5)
                              : const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSafe
                                ? AppColors.receiveGreen
                                : AppColors.alertRed,
                          ),
                        ),
                        child: Text(
                          widget.securityCheck.securityMessage,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isSafe
                                ? const Color(0xFF065F46)
                                : AppColors.alertRed,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      _infoBox(
                        label: isReceive ? 'الراسل' : 'المستلم',
                        value: widget.parsedSms.partyPhone,
                        sub: widget.parsedSms.partyName != null
                            ? 'على ${widget.parsedSms.partyName}'
                            : null,
                      ),
                      const SizedBox(height: 8),

                      Row(
                        children: [
                          Expanded(
                            child: _infoBox(
                              label: 'الرصيد بالرسالة',
                              value: widget.parsedSms.balanceAfter != null
                                  ? '${widget.parsedSms.balanceAfter!.toStringAsFixed(2)} ج.م'
                                  : 'غير مذكور',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _infoBox(
                              label: 'الرصيد المتوقع حسابياً',
                              value:
                                  widget.securityCheck.expectedBalance != null
                                  ? '${widget.securityCheck.expectedBalance!.toStringAsFixed(2)} ج.م'
                                  : '-',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      _infoBox(
                        label: 'البصمة الرقمية للعملية (Fingerprint)',
                        value:
                            '${widget.securityCheck.fingerprint} | ${widget.parsedSms.transactionRef}',
                      ),
                      const SizedBox(height: 12),

                      if (isSafe) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: headerColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: headerColor,
                                  minimumSize: Size.zero,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                ),
                                onPressed: () => _timer?.cancel(),
                                child: const Text(
                                  'تثبيت لتعديل العمولة',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                              Text(
                                'تسجيل تلقائي خلال $_secondsLeft ثانية',
                                style: TextStyle(
                                  color: headerColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      if (isReceive) ...[
                        TextField(
                          controller: _commissionController,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          onTap: () => _timer?.cancel(),
                          decoration: const InputDecoration(
                            hintText: 'عمولة السحب (يدوي)',
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],

                      Row(
                        children: [
                          if (!isSafe) ...[
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.alertRed,
                                  side: const BorderSide(
                                    color: AppColors.alertRed,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                ),
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        '🗑️ تم تجاهل الرسالة المشبوهة وحماية الخزنة!',
                                      ),
                                      backgroundColor: AppColors.alertRed,
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.block, size: 18),
                                label: const Text('تجاهل (رسالة مزيفة)'),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: headerColor,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                              ),
                              onPressed: () {
                                _timer?.cancel();
                                _saveToStoreAndClose();
                              },
                              icon: Icon(
                                isSafe ? Icons.check_circle : Icons.verified,
                                size: 18,
                              ),
                              label: Text(
                                isSafe
                                    ? 'تسجيل العملية'
                                    : 'تأكدت من المحفظة (اعتماد)',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoBox({required String label, required String value, String? sub}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
          if (sub != null)
            Text(
              sub,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
        ],
      ),
    );
  }
}
