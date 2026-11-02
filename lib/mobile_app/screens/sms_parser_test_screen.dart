import 'dart:async';
import 'package:cashawy_pro/core/theme/parsers/cash_sms_parser.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/native_sms_listener.dart';
import '../../core/services/native_ussd_service.dart';

class SmsParserTestScreen extends StatefulWidget {
  const SmsParserTestScreen({super.key});

  @override
  State<SmsParserTestScreen> createState() => _SmsParserTestScreenState();
}

class _SmsParserTestScreenState extends State<SmsParserTestScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // متغيرات الصلاحيات والرادار
  bool _hasSmsPermission = false;
  bool _hasAccessibility = false;
  String _lastRawSmsLog = 'في انتظار وصول أي رسالة SMS حقيقية على الهاتف...';

  // متغيرات التحويل بضغطة واحدة (USSD)
  int _selectedSimSlot = 0; // 0 = SIM 1, 1 = SIM 2
  WalletProvider _selectedProvider = WalletProvider.vodafone;
  final TextEditingController _phoneController = TextEditingController(text: '01012345678');
  final TextEditingController _amountController = TextEditingController(text: '5');
  final TextEditingController _pinController = TextEditingController();

  // متغيرات المحاكاة
  final TextEditingController _smsController = TextEditingController();
  final String _sampleReceiveSms =
      'تم استلام مبلغ 10 جنيه من رقم 01117086300 Mohamed A Abdelhamid؛ رصيدك الحالي 813.00 جنيه. رقم العملية 1063597136';
  final String _sampleTransferSms =
      'تم تحويل 5 جنيه لرقم 01117086300 Mohamed A Abdelhamid؛ مصاريف الخدمة 1 ج.م. رصيد حسابك الحالي 803.00 جنيه. رقم العملية 1091271474';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _smsController.text = _sampleReceiveSms;
    _initServices();
  }

  Future<void> _initServices() async {
    final smsGranted = await NativeSmsListener.checkPermissions();
    final accEnabled = await NativeUssdService.isAccessibilityEnabled();
    if (mounted) {
      setState(() {
        _hasSmsPermission = smsGranted;
        _hasAccessibility = accEnabled;
      });
    }

    NativeSmsListener.startListening(
      onAnySmsReceived: (sender, rawBody) {
        if (!mounted) return;
        setState(() {
          _lastRawSmsLog = '📩 وصلت رسالة حقيقية من ($sender):\n$rawBody';
        });
      },
      onCashSmsReceived: (parsedSms) {
        if (!mounted) return;
        _showAutoDialog(parsedSms);
      },
    );
  }

  Future<void> _refreshStatus() async {
    final smsGranted = await NativeSmsListener.checkPermissions();
    final accEnabled = await NativeUssdService.isAccessibilityEnabled();
    setState(() {
      _hasSmsPermission = smsGranted;
      _hasAccessibility = accEnabled;
    });
  }

  Future<void> _executeOneClickTransfer() async {
    final phone = _phoneController.text.trim();
    final amount = int.tryParse(_amountController.text.trim()) ?? 0;
    final pin = _pinController.text.trim();

    if (phone.length != 11 || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تأكد من كتابة رقم هاتف صحيح (11 رقم) ومبلغ أكبر من صفر'),
          backgroundColor: AppColors.alertRed,
        ),
      );
      return;
    }

    final ussdCode = NativeUssdService.buildTransferUssdCode(
      provider: _selectedProvider,
      targetPhone: phone,
      amount: amount,
    );

    await NativeUssdService.executeUssd(
      ussdCode: ussdCode,
      pinCode: pin,
      simSlot: _selectedSimSlot,
    );
  }

  Future<void> _testBalanceInquiry() async {
    // كود استعلام رصيد فودافون كاش *9*13# لتجربة إدخال الرقم السري مجاناً بدون تحويل فعلي
    final pin = _pinController.text.trim();
    await NativeUssdService.executeUssd(
      ussdCode: '*9*13#',
      pinCode: pin,
      simSlot: _selectedSimSlot,
    );
  }

  void _showAutoDialog(ParsedCashSms parsed) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _AutoTransactionDialog(parsedSms: parsed),
    );
  }

  @override
  void dispose() {
    NativeSmsListener.stopListening();
    _tabController.dispose();
    _phoneController.dispose();
    _amountController.dispose();
    _pinController.dispose();
    _smsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('كشاوي Cashawy - محرك البوابة الذكية'),
        actions: [
          IconButton(
            onPressed: _refreshStatus,
            tooltip: 'تحديث حالة الصلاحيات',
            icon: const Icon(Icons.refresh),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(icon: Icon(Icons.bolt), text: 'التحويل بضغطة واحدة (USSD)'),
            Tab(icon: Icon(Icons.radar), text: 'رادار الاستلام والمحاكاة'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildUssdTransferTab(),
          _buildSmsRadarTab(),
        ],
      ),
    );
  }

  /// التبويب الأول: محرك التحويل المباشر بضغطة واحدة
  Widget _buildUssdTransferTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 650),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // كارت تفعيل خدمة الكاتب التلقائي للرقم السري (Accessibility)
              Card(
                color: _hasAccessibility ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _hasAccessibility ? Icons.check_circle : Icons.auto_fix_high,
                            color: _hasAccessibility ? AppColors.receiveGreen : AppColors.capitalGold,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _hasAccessibility
                                      ? 'الكاتب التلقائي للرقم السري مُفعّل ✅'
                                      : 'تفعيل الكاتب التلقائي للرقم السري (اختياري ولكن يوصى به)',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                                Text(
                                  _hasAccessibility
                                      ? 'سيقوم Cashawy بكتابة الرقم السري للمحفظة والضغط على إرسال تلقائياً!'
                                      : 'فعّل خدمة Cashawy من إعدادات إمكانية الوصول ليكتب الرقم السري نيابة عنك',
                                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (!_hasAccessibility) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(backgroundColor: AppColors.capitalGold),
                                onPressed: () async {
                                  await NativeUssdService.openAccessibilitySettings();
                                },
                                icon: const Icon(Icons.settings_accessibility),
                                label: const Text('فتح الإعدادات لتفعيل Cashawy'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton(
                              onPressed: _refreshStatus,
                              child: const Text('فعلتها؟ تحديث'),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // كارت تنفيذ التحويل السريع
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'إعدادات الشريحة والمحفظة:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 12),

                      // اختيار الشريحة SIM 1 أو SIM 2
                      Row(
                        children: [
                          Expanded(
                            child: ChoiceChip(
                              label: const Center(child: Text('الشريحة الأولى (SIM 1)')),
                              selected: _selectedSimSlot == 0,
                              selectedColor: AppColors.primary.withValues(alpha: 0.2),
                              onSelected: (_) => setState(() => _selectedSimSlot = 0),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ChoiceChip(
                              label: const Center(child: Text('الشريحة الثانية (SIM 2)')),
                              selected: _selectedSimSlot == 1,
                              selectedColor: AppColors.primary.withValues(alpha: 0.2),
                              onSelected: (_) => setState(() => _selectedSimSlot = 1),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // رقم هاتف المستلم
                      TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'رقم هاتف المستلم (العميل)',
                          prefixIcon: Icon(Icons.phone_android),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // المبلغ والرقم السري
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _amountController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'المبلغ (جنيه)',
                                prefixIcon: Icon(Icons.payments_outlined),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _pinController,
                              keyboardType: TextInputType.number,
                              obscureText: true,
                              decoration: const InputDecoration(
                                labelText: 'الرقم السري للمحفظة (للإدخال التلقائي)',
                                prefixIcon: Icon(Icons.lock_outline),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // زر التحويل المباشر
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.transferBlue,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          onPressed: _executeOneClickTransfer,
                          icon: const Icon(Icons.send_to_mobile),
                          label: const Text('تنفيذ التحويل الآن بضغطة واحدة 🚀'),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // زر استعلام الرصيد للتجربة المجانية بدون خصم رصيد
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _testBalanceInquiry,
                          icon: const Icon(Icons.account_balance_wallet_outlined),
                          label: const Text('تجربة مجانية: استعلام رصيد فودافون كاش (*9*13#)'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// التبويب الثاني: رادار الرسائل والمحاكاة
  Widget _buildSmsRadarTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 650),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                color: _hasSmsPermission ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _hasSmsPermission ? Icons.radar : Icons.warning_amber_rounded,
                            color: _hasSmsPermission ? AppColors.receiveGreen : AppColors.alertRed,
                            size: 30,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _hasSmsPermission
                                  ? 'الرادار الحقيقي متصل ومُفعّل بنجاح 📡'
                                  : 'الرادار يحتاج لصلاحيات الرسائل والاتصال ⚠️',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ),
                        ],
                      ),
                      if (!_hasSmsPermission) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.alertRed),
                            onPressed: () async {
                              await NativeSmsListener.requestPermissions();
                              await Future.delayed(const Duration(seconds: 1));
                              _refreshStatus();
                            },
                            child: const Text('تفعيل صلاحيات الرادار والاتصال'),
                          ),
                        ),
                      ],
                      const Divider(height: 24),
                      Text(_lastRawSmsLog, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'محاكاة سريعة للرسائل:',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => setState(() => _smsController.text = _sampleReceiveSms),
                            icon: const Icon(Icons.call_received, color: AppColors.receiveGreen),
                            label: const Text('رسالة استلام (10 ج.م)'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => setState(() => _smsController.text = _sampleTransferSms),
                            icon: const Icon(Icons.call_made, color: AppColors.transferBlue),
                            label: const Text('رسالة تحويل (5 ج.م)'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(controller: _smsController, maxLines: 3),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            final parsed = CashSmsParser.parse(
                              sender: 'VF-Cash',
                              messageBody: _smsController.text,
                            );
                            if (parsed != null) _showAutoDialog(parsed);
                          },
                          icon: const Icon(Icons.bolt),
                          label: const Text('محاكاة وصول الرسالة الآن 🚀'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AutoTransactionDialog extends StatefulWidget {
  final ParsedCashSms parsedSms;

  const _AutoTransactionDialog({required this.parsedSms});

  @override
  State<_AutoTransactionDialog> createState() => _AutoTransactionDialogState();
}

class _AutoTransactionDialogState extends State<_AutoTransactionDialog> {
  int _secondsLeft = 7;
  Timer? _timer;
  final TextEditingController _commissionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft > 1) {
        setState(() => _secondsLeft--);
      } else {
        timer.cancel();
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ تم تسجيل العملية تلقائياً في الخلفية وتحديث الأرصدة!'),
              backgroundColor: AppColors.receiveGreen,
            ),
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _commissionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isReceive = widget.parsedSms.type == TransactionType.receive;
    final headerColor = isReceive ? const Color(0xFF00A86B) : const Color(0xFF1D4ED8);
    final titleText = isReceive ? 'استلام أموال' : 'تحويل أموال';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [headerColor, headerColor.withValues(alpha: 0.85)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close, color: Colors.white),
                          ),
                          Text(
                            titleText,
                            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 40),
                        ],
                      ),
                      const Text('Vodafone Cash', style: TextStyle(color: Colors.white70, fontSize: 14)),
                      const SizedBox(height: 8),
                      Text(
                        '${widget.parsedSms.amount.toInt()} ج.م',
                        style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                ),
                Container(
                  color: const Color(0xFFF8FAFC),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildInfoTile(
                        label: isReceive ? 'الراسل' : 'المستلم',
                        value: widget.parsedSms.partyPhone,
                        subValue: widget.parsedSms.partyName != null ? 'على ${widget.parsedSms.partyName}' : null,
                        icon: Icons.phone_in_talk,
                      ),
                      const SizedBox(height: 8),
                      if (widget.parsedSms.balanceAfter != null) ...[
                        _buildInfoTile(
                          label: 'الرصيد بعد العملية',
                          value: '${widget.parsedSms.balanceAfter!.toStringAsFixed(2)} ج.م',
                          icon: Icons.account_balance_wallet,
                          valueColor: AppColors.transferBlue,
                        ),
                        const SizedBox(height: 8),
                      ],
                      _buildInfoTile(
                        label: 'رقم العملية',
                        value: widget.parsedSms.transactionRef,
                        icon: Icons.tag,
                        isSmallText: true,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'تسجيل تلقائي خلال $_secondsLeft ثانية',
                        style: TextStyle(color: headerColor, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: headerColor),
                          onPressed: () {
                            _timer?.cancel();
                            Navigator.of(context).pop();
                          },
                          child: Text(isReceive ? 'تسجيل العملية' : 'حفظ وإغلاق'),
                        ),
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

  Widget _buildInfoTile({
    required String label,
    required String value,
    String? subValue,
    required IconData icon,
    Color? valueColor,
    bool isSmallText = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: isSmallText ? 12 : 16,
                    fontWeight: FontWeight.bold,
                    color: valueColor ?? AppColors.secondary,
                  ),
                ),
                if (subValue != null)
                  Text(
                    subValue,
                    style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.background,
            child: Icon(icon, size: 18, color: AppColors.secondary),
          ),
        ],
      ),
    );
  }
}