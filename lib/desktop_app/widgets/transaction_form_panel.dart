import 'package:cashawy_pro/core/theme/parsers/cash_sms_parser.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'dart:math' as math;

import '../../core/theme/app_theme.dart';
import '../../core/database/cashawy_store.dart';
import '../../core/services/native_ussd_service.dart';
import '../../models/wallet_model.dart';
import '../../models/transaction_model.dart';
import 'manage_wallets_dialog.dart';

class TransactionFormPanel extends StatefulWidget {
  const TransactionFormPanel({super.key});

  @override
  State<TransactionFormPanel> createState() => _TransactionFormPanelState();
}

class _TransactionFormPanelState extends State<TransactionFormPanel> {
  final CashawyStore _store = CashawyStore.instance;
  final NumberFormat _numFormat = NumberFormat('#,##0');

  bool _isTransferMode = false; // false = استلام، true = تحويل
  bool _deductCommission = true;
  bool _isDebt = false; // آجل (دين)
  bool _isPending = false; // مؤجل (بانتظار الاعتماد)

  final TextEditingController _clientPhoneController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _commissionController = TextEditingController();
  final TextEditingController _networkFeeController = TextEditingController(
    text: '0',
  );
  final TextEditingController _notesController = TextEditingController();

  @override
  void dispose() {
    _clientPhoneController.dispose();
    _amountController.dispose();
    _commissionController.dispose();
    _networkFeeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.alertRed,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _submitTransaction() async {
    final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    final commission =
        double.tryParse(_commissionController.text.trim()) ?? 0.0;
    final networkFee =
        double.tryParse(_networkFeeController.text.trim()) ?? 0.0;
    final clientPhone = _clientPhoneController.text.trim().isEmpty
        ? _store.selectedWallet.phoneNumber
        : _clientPhoneController.text.trim();

    if (amount <= 0) {
      _showError('يرجى إدخال مبلغ صحيح أكبر من صفر');
      return;
    }

    final txType = _isTransferMode
        ? TransactionType.transfer
        : TransactionType.receive;
    final txStatus = _isPending
        ? TransactionStatus.pending
        : (_isDebt ? TransactionStatus.debt : TransactionStatus.completed);

    // 1) فحص الليميت والرصيد قبل أي تنفيذ فعلي على الشريحة أو تسجيل محاسبي.
    final limitCheck = _store.checkWalletLimit(
      type: txType,
      amount: amount,
      networkFee: _isTransferMode ? networkFee : 0.0,
      status: txStatus,
      checkBalance: _isTransferMode,
    );

    if (!limitCheck.allowed) {
      _showError(limitCheck.message ?? 'تم تجاوز حدود المحفظة');
      return;
    }

    // 2) لو الوضع "تحويل" وشغالين من الموبايل ومش حساب إنستاباي، ننفذ كود الـ USSD.
    // العمليات المؤجلة لا تُنفذ على الشبكة الآن، بل عند اعتمادها.
    if (_isTransferMode &&
        !_isPending &&
        !_store.selectedWallet.isInstaPay &&
        !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android &&
        clientPhone.length == 11) {
      final ussdCode = NativeUssdService.buildTransferUssdCode(
        provider: _store.selectedWallet.provider,
        targetPhone: clientPhone,
        amount: amount.toInt(),
      );
      await NativeUssdService.executeUssd(
        ussdCode: ussdCode,
        pinCode: _store.selectedWallet.pinCode,
        simSlot: _store.selectedWallet.simSlot,
      );
    }

    // 3) تسجيل العملية في العقل المحاسبي وتحديث الأرصدة والليميت.
    final result = _store.recordTransaction(
      type: txType,
      amount: amount,
      clientPhone: clientPhone,
      commission: commission,
      networkFee: _isTransferMode ? networkFee : 0.0,
      deductCommission: _deductCommission,
      status: txStatus,
      notes: _notesController.text.trim(),
    );

    if (!result.success) {
      _showError(result.error ?? 'تعذر تسجيل العملية');
      return;
    }

    final wasPending = _isPending;

    // تفريغ الخانات لمعاملة جديدة
    _amountController.clear();
    _commissionController.clear();
    _notesController.clear();
    setState(() {
      _isDebt = false;
      _isPending = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            wasPending
                ? '🕒 تم حفظ العملية كمؤجلة، وستُطبّق على الرصيد عند اعتمادها من لوحة التحكم.'
                : _isTransferMode
                ? '✅ تم تنفيذ وتسجيل عملية التحويل وتحديث الليميت!'
                : '✅ تم تأكيد السحب (الاستلام) وتحديث الخزنة والليميت!',
          ),
          backgroundColor: wasPending
              ? AppColors.capitalGold
              : AppColors.receiveGreen,
        ),
      );
    }
  }

  void _openManageWalletsDialog() {
    showDialog(context: context, builder: (_) => const ManageWalletsDialog());
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _store,
      builder: (context, _) {
        final wallet = _store.selectedWallet;
        final isInsta = wallet.isInstaPay;

        final typedAmount =
            double.tryParse(_amountController.text.trim()) ?? 0.0;
        final typedFee =
            double.tryParse(_networkFeeController.text.trim()) ?? 0.0;
        final dailyRemaining = _isTransferMode
            ? wallet.dailyTransferRemaining
            : wallet.dailyReceiveRemaining;
        final monthlyRemaining = _isTransferMode
            ? wallet.monthlyTransferRemaining
            : wallet.monthlyReceiveRemaining;
        final quotaRemaining = math.min(dailyRemaining, monthlyRemaining);
        final balanceRemaining = _isTransferMode
            ? math.max(0.0, wallet.balance - typedFee)
            : double.infinity;
        final maxAllowedNow = math.min(quotaRemaining, balanceRemaining);
        final isDeferredReceive = !_isTransferMode && _isDebt;
        final willExceed =
            typedAmount > 0 &&
            !isDeferredReceive &&
            !_isPending &&
            typedAmount > maxAllowedNow + 0.01;

        return Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. عنوان القسم + النقطة الخضراء
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: AppColors.receiveGreen,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'إجراء معاملة جديدة',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 2. تبويب (تحويل / استلام)
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() => _isTransferMode = true),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: _isTransferMode
                                  ? AppColors.transferBlue.withValues(
                                      alpha: 0.12,
                                    )
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              border: _isTransferMode
                                  ? Border.all(
                                      color: AppColors.transferBlue,
                                      width: 1.5,
                                    )
                                  : null,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (_isTransferMode)
                                  const Icon(
                                    Icons.check,
                                    size: 18,
                                    color: AppColors.transferBlue,
                                  ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.swap_vert,
                                  size: 18,
                                  color: AppColors.transferBlue,
                                ),
                                const SizedBox(width: 6),
                                const Text(
                                  'تحويل',
                                  style: TextStyle(
                                    color: AppColors.transferBlue,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() => _isTransferMode = false),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: !_isTransferMode
                                  ? AppColors.alertRed.withValues(alpha: 0.1)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              border: !_isTransferMode
                                  ? Border.all(
                                      color: AppColors.alertRed,
                                      width: 1.5,
                                    )
                                  : null,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (!_isTransferMode)
                                  const Icon(
                                    Icons.check,
                                    size: 18,
                                    color: AppColors.alertRed,
                                  ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.south_west,
                                  size: 18,
                                  color: AppColors.alertRed,
                                ),
                                const SizedBox(width: 6),
                                const Text(
                                  'استلام',
                                  style: TextStyle(
                                    color: AppColors.alertRed,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // 3. شريط أزرار المحافظ وإنستاباي
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.account_balance_wallet_outlined,
                          size: 16,
                          color: Colors.black54,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'اختيار المحفظة / إنستاباي',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Wrap(
                      spacing: 6,
                      children: [
                        _buildSmallActionChip(
                          label: 'المحافظ (${_store.wallets.length})',
                          icon: Icons.credit_card,
                          color: AppColors.transferBlue,
                          onTap: _openManageWalletsDialog,
                        ),
                        _buildSmallActionChip(
                          label: 'طباعة',
                          icon: Icons.print_outlined,
                          color: AppColors.capitalGold,
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  '🖨️ جاري تجهيز إيصال آخر معاملة للطباعة...',
                                ),
                              ),
                            );
                          },
                        ),
                        _buildSmallActionChip(
                          label: 'إضافة محفظة / إنستاباي +',
                          icon: Icons.add,
                          color: AppColors.receiveGreen,
                          onTap: _openManageWalletsDialog,
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // 4. القائمة المنسدلة لاختيار المحفظة أو حساب إنستاباي النشط
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<WalletModel>(
                      value: wallet,
                      isExpanded: true,
                      items: _store.wallets.map((w) {
                        final isItemInsta = w.isInstaPay;
                        Color badgeColor = AppColors.vodafoneRed;
                        IconData badgeIcon = Icons.bolt;

                        if (isItemInsta) {
                          badgeColor = const Color(0xFF6B21A8);
                          badgeIcon = Icons.account_balance;
                        } else if (w.provider == WalletProvider.orange) {
                          badgeColor = Colors.deepOrange;
                          badgeIcon = Icons.wifi_tethering;
                        } else if (w.provider == WalletProvider.etisalat) {
                          badgeColor = const Color(0xFF15803D);
                          badgeIcon = Icons.phone_android;
                        }

                        return DropdownMenuItem<WalletModel>(
                          value: w,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                w.phoneNumber,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              Row(
                                children: [
                                  Text(
                                    w.title,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  CircleAvatar(
                                    radius: 10,
                                    backgroundColor: badgeColor,
                                    child: Icon(
                                      badgeIcon,
                                      size: 12,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (newWallet) {
                        if (newWallet != null) _store.selectWallet(newWallet);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // 5. شرائط مراقبة الليميت الأربعة
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.background.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildLimitItem(
                              title: 'استلام شهري',
                              used: wallet.usedMonthlyReceive,
                              limit: wallet.monthlyReceiveLimit,
                              percent: wallet.monthlyReceivePercent,
                              color: AppColors.alertRed,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildLimitItem(
                              title: 'تحويل شهري',
                              used: wallet.usedMonthlyTransfer,
                              limit: wallet.monthlyTransferLimit,
                              percent: wallet.monthlyTransferPercent,
                              color: AppColors.receiveGreen,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: _buildLimitItem(
                              title: 'استلام يومي',
                              used: wallet.usedDailyReceive,
                              limit: wallet.dailyReceiveLimit,
                              percent: wallet.dailyReceivePercent,
                              color: AppColors.alertRed,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildLimitItem(
                              title: 'تحويل يومي',
                              used: wallet.usedDailyTransfer,
                              limit: wallet.dailyTransferLimit,
                              percent: wallet.dailyTransferPercent,
                              color: AppColors.receiveGreen,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // 6. حقول الإدخال الديناميكية حسب نوع العملية
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isInsta
                                ? Icons.account_balance
                                : Icons.phone_iphone,
                            size: 18,
                            color: Colors.black54,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            wallet.phoneNumber,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'الرصيد: ${_numFormat.format(wallet.balance)} ج.م',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                if (_isTransferMode) ...[
                  TextField(
                    controller: _clientPhoneController,
                    keyboardType: isInsta
                        ? TextInputType.text
                        : TextInputType.phone,
                    decoration: InputDecoration(
                      hintText: isInsta
                          ? 'رقم المستقبل أو عنوان الدفع (IPA)'
                          : 'رقم المستقبل',
                      prefixIcon: Icon(
                        isInsta ? Icons.alternate_email : Icons.person_outline,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],

                TextField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: _isTransferMode
                        ? 'المبلغ (جنيه)'
                        : 'مبلغ الاستلام (جنيه)',
                    prefixIcon: const Icon(Icons.payments_outlined),
                  ),
                ),
                const SizedBox(height: 10),

                TextField(
                  controller: _commissionController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: _isTransferMode
                        ? 'عمولة التحويل (جنيه)'
                        : 'عمولة الاستلام (جنيه)',
                    prefixIcon: const Icon(Icons.monetization_on_outlined),
                  ),
                ),
                const SizedBox(height: 10),

                TextField(
                  controller: _isTransferMode
                      ? _networkFeeController
                      : _notesController,
                  keyboardType: _isTransferMode
                      ? TextInputType.number
                      : TextInputType.text,
                  onChanged: _isTransferMode ? (_) => setState(() {}) : null,
                  decoration: InputDecoration(
                    hintText: _isTransferMode
                        ? 'رسوم التحويل (جنيه)'
                        : 'ملاحظة السحب (اختياري)',
                    prefixIcon: Icon(
                      _isTransferMode ? Icons.receipt_long : Icons.notes,
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // 7. أزرار (خصم العمولة / آجل)
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _deductCommission
                            ? AppColors.transferBlue
                            : Colors.grey.shade300,
                        foregroundColor: _deductCommission
                            ? Colors.white
                            : Colors.black87,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                      onPressed: () => setState(
                        () => _deductCommission = !_deductCommission,
                      ),
                      child: Text(
                        _isTransferMode ? 'خصم للعميل' : 'خصم العمولة',
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isDebt
                            ? AppColors.capitalGold
                            : const Color(0xFFFEF3C7),
                        foregroundColor: _isDebt
                            ? Colors.white
                            : AppColors.capitalGold,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                      onPressed: () => setState(() {
                        _isDebt = !_isDebt;
                        if (_isDebt) _isPending = false;
                      }),
                      child: const Text('آجل'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isPending
                            ? const Color(0xFF6B21A8)
                            : const Color(0xFFF3E8FF),
                        foregroundColor: _isPending
                            ? Colors.white
                            : const Color(0xFF6B21A8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                      onPressed: () => setState(() {
                        _isPending = !_isPending;
                        if (_isPending) _isDebt = false;
                      }),
                      child: const Text('مؤجل'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // 7.5 شريط المتاح الآن / تحذير تجاوز الليميت
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color:
                        (_isPending
                                ? const Color(0xFF6B21A8)
                                : (willExceed
                                      ? AppColors.alertRed
                                      : AppColors.receiveGreen))
                            .withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color:
                          (_isPending
                                  ? const Color(0xFF6B21A8)
                                  : (willExceed
                                        ? AppColors.alertRed
                                        : AppColors.receiveGreen))
                              .withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isPending
                            ? Icons.schedule
                            : (willExceed
                                  ? Icons.error_outline
                                  : Icons.info_outline),
                        size: 18,
                        color: _isPending
                            ? const Color(0xFF6B21A8)
                            : (willExceed
                                  ? AppColors.alertRed
                                  : AppColors.receiveGreen),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _isPending
                              ? 'عملية مؤجلة: لن تُخصم من حدود المحفظة أو رصيدها الآن، وستُطبّق بالكامل عند اعتمادها.'
                              : isDeferredReceive
                              ? 'استلام آجل: لن يستهلك ليميت الاستلام الآن، وسيُسجل كدين على العميل.'
                              : willExceed
                              ? 'المبلغ يتجاوز المتاح. أقصى مبلغ يمكن تنفيذه الآن: ${_numFormat.format(maxAllowedNow.toInt())} ج.م'
                              : 'المتاح الآن: ${_numFormat.format(maxAllowedNow.toInt())} ج.م '
                                    '(يومي ${_numFormat.format(dailyRemaining.toInt())} / '
                                    'شهري ${_numFormat.format(monthlyRemaining.toInt())})',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: willExceed
                                ? AppColors.alertRed
                                : Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // 8. زر التأكيد النهائي
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E6F5E),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: _submitTransaction,
                    icon: const Icon(Icons.check),
                    label: Text(
                      _isPending
                          ? 'حفظ كعملية مؤجلة'
                          : (_isTransferMode ? 'تأكيد التحويل' : 'تأكيد السحب'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSmallActionChip({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLimitItem({
    required String title,
    required double used,
    required double limit,
    required double percent,
    required Color color,
  }) {
    final remaining = (limit - used).clamp(0.0, double.infinity);
    final exceeded = used > limit + 0.01;
    final barColor = exceeded ? AppColors.alertRed : color;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percent,
            minHeight: 5,
            backgroundColor: Colors.grey.shade300,
            valueColor: AlwaysStoppedAnimation<Color>(barColor),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'المستخدم: ${_numFormat.format(used.toInt())}',
              style: TextStyle(
                fontSize: 10,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              'الحد: ${_numFormat.format(limit.toInt())}',
              style: const TextStyle(fontSize: 10, color: Colors.black54),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          exceeded
              ? '⚠️ تجاوزت الحد بـ ${_numFormat.format((used - limit).toInt())} ج.م'
              : 'المتبقي: ${_numFormat.format(remaining.toInt())} ج.م',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: exceeded ? AppColors.alertRed : color,
          ),
        ),
      ],
    );
  }
}
