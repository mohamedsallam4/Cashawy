import 'package:cashawy_pro/core/theme/parsers/cash_sms_parser.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../core/theme/app_theme.dart';
import '../../core/database/cashawy_store.dart';
import '../../models/transaction_model.dart';
import '../modules/debts_screen.dart';
import '../modules/sales_screen.dart';
import '../modules/inventory_screen.dart';
import '../modules/supermarket_pos_screen.dart';
import '../modules/suppliers_screen.dart';
import '../modules/market_settings_screen.dart';
import '../modules/shift_closing_screen.dart';
import '../modules/backup_screen.dart';
import '../modules/reports_screen.dart';
import '../modules/invoices_archive_screen.dart';
import '../modules/income_statement_screen.dart';
import 'return_item_dialog.dart';
import 'record_waste_dialog.dart';

class DashboardOverviewPanel extends StatefulWidget {
  const DashboardOverviewPanel({super.key});

  @override
  State<DashboardOverviewPanel> createState() => _DashboardOverviewPanelState();
}

class _DashboardOverviewPanelState extends State<DashboardOverviewPanel> {
  final CashawyStore _store = CashawyStore.instance;
  final NumberFormat _numFormat = NumberFormat('#,##0');

  bool _showTodayProfit = false;
  bool _showMonthProfit = false;
  String _selectedFilter = 'الكل';
  String _searchQuery = '';

  List<TransactionModel> _getFilteredTransactions() {
    return _store.transactions.where((tx) {
      if (tx.status == TransactionStatus.trash) return false;

      if (_selectedFilter == 'التحويل' && tx.type != TransactionType.transfer) {
        return false;
      }
      if (_selectedFilter == 'السحب' && tx.type != TransactionType.receive) {
        return false;
      }
      if (_selectedFilter == 'مؤجل' && tx.status != TransactionStatus.pending) {
        return false;
      }
      if (_selectedFilter == 'معاملات المحفظة' &&
          tx.walletPhone != _store.selectedWallet.phoneNumber) {
        return false;
      }

      if (_searchQuery.isNotEmpty) {
        return tx.clientPhone.contains(_searchQuery) ||
            tx.walletPhone.contains(_searchQuery) ||
            tx.amount.toString().contains(_searchQuery);
      }
      return true;
    }).toList();
  }

  void _promptAdminPin(VoidCallback onAuthorized) {
    if (!_store.isCashierLocked) {
      onAuthorized();
      return;
    }

    final pinCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.lock_outline, color: AppColors.alertRed),
            SizedBox(width: 8),
            Text('مطلوب رقم الأدمن السري 🔒'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'هذا القسم محمي في وضع الكاشير الآمن. أدخل الـ PIN للمتابعة:',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: pinCtrl,
              autofocus: true,
              obscureText: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'رقم الأدمن (الافتراضي: 1234)',
                prefixIcon: Icon(Icons.password),
              ),
              onSubmitted: (_) {
                if (_store.verifyAdminPin(pinCtrl.text)) {
                  Navigator.pop(ctx);
                  onAuthorized();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('❌ الرقم السري غير صحيح!'),
                      backgroundColor: AppColors.alertRed,
                    ),
                  );
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () {
              if (_store.verifyAdminPin(pinCtrl.text)) {
                Navigator.pop(ctx);
                onAuthorized();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('❌ الرقم السري غير صحيح!'),
                    backgroundColor: AppColors.alertRed,
                  ),
                );
              }
            },
            child: const Text('تأكيد الدخول'),
          ),
        ],
      ),
    );
  }

  void _toggleCashierLock() {
    if (_store.isCashierLocked) {
      _promptAdminPin(() {
        _store.setCashierLock(false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🔓 تم فتح وضع الأدمن الكامل بنجاح'),
            backgroundColor: AppColors.receiveGreen,
          ),
        );
      });
    } else {
      _store.setCashierLock(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🔒 تم قفل شاشات الإدارة وتفعيل وضع الكاشير الآمن'),
          backgroundColor: AppColors.alertRed,
        ),
      );
    }
  }

  void _showReturnDialog() {
    showDialog(
      context: context,
      builder: (_) => const Directionality(
        textDirection: TextDirection.rtl,
        child: ReturnItemDialog(),
      ),
    );
  }

  void _showAddExpenseDialog() {
    final titleCtrl = TextEditingController();
    final amountCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تسجيل مصروفات / نثريات 💸'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(
                labelText: 'بيان المصروف (مثال: كهرباء، أكياس، فطار)',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'المبلغ المدفوع من الدرج (جنيه)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.alertRed,
            ),
            onPressed: () {
              final amt = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
              if (titleCtrl.text.isNotEmpty && amt > 0) {
                _store.recordExpense(title: titleCtrl.text.trim(), amount: amt);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      '✅ تم خصم المصروف من درج الكاشير وتسجيله بنجاح',
                    ),
                    backgroundColor: AppColors.alertRed,
                  ),
                );
              }
            },
            child: const Text('خصم وتسجيل المصروف'),
          ),
        ],
      ),
    );
  }

  void _showResetWizardDialog() {
    _promptAdminPin(() {
      final cashCtrl = TextEditingController(text: '1000');
      final fawryCtrl = TextEditingController(text: '0');
      final amanCtrl = TextEditingController(text: '0');
      final walletPhoneCtrl = TextEditingController(text: '01012345678');
      final walletBalCtrl = TextEditingController(text: '0');
      bool clearProducts = false;

      showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: const Text('🚀 إعداد وبدء تشغيل السوبر ماركت الفعلي'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'سيقوم هذا المعالج بتصفير العمليات التجريبية والبدء بأرصدتك الحقيقية في الدرج والمحافظ:',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  const Divider(height: 20),
                  TextField(
                    controller: cashCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'النقدية الحقيقية الموجودة بالدرج الآن (ج.م)',
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: fawryCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'رصيد فوري الفعلي',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: amanCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'رصيد أمان الفعلي',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: walletPhoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'رقم محفظة الكاش الفعلية للمحل',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: walletBalCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'الرصيد الفعلي الحالي في المحفظة',
                    ),
                  ),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'مسح الأصناف التجريبية والبدء بمخزن فارغ تماماً',
                      style: TextStyle(fontSize: 13),
                    ),
                    value: clearProducts,
                    onChanged: (v) =>
                        setDialogState(() => clearProducts = v ?? false),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                ),
                onPressed: () {
                  _store.resetToRealStore(
                    initialCash: double.tryParse(cashCtrl.text) ?? 0.0,
                    initialFawry: double.tryParse(fawryCtrl.text) ?? 0.0,
                    initialAman: double.tryParse(amanCtrl.text) ?? 0.0,
                    walletPhone: walletPhoneCtrl.text.trim(),
                    walletBalance: double.tryParse(walletBalCtrl.text) ?? 0.0,
                    clearProducts: clearProducts,
                  );
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        '🎉 تم تصفير الداتا التجريبية والبدء بأرصدتك الحقيقية!',
                      ),
                      backgroundColor: AppColors.receiveGreen,
                    ),
                  );
                },
                child: const Text('اعتماد وبدء التشغيل الفعلي'),
              ),
            ],
          ),
        ),
      );
    });
  }

  void _showEditDrawerCashDialog() {
    _promptAdminPin(() {
      final ctrl = TextEditingController(
        text: _store.cashInDrawer.toInt().toString(),
      );
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('تعديل فلوس الدرج الحقيقية'),
          content: TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'النقدية الفعلية بالدرج الآن',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () {
                final val = double.tryParse(ctrl.text);
                if (val != null) _store.updateCashInDrawer(val);
                Navigator.pop(ctx);
              },
              child: const Text('تحديث'),
            ),
          ],
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _store,
      builder: (context, _) {
        final filteredTx = _getFilteredTransactions();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // شريط الإجراءات السريعة للكاشير
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const Directionality(
                          textDirection: TextDirection.rtl,
                          child: SupermarketPosScreen(),
                        ),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primaryDark, AppColors.primary],
                        begin: Alignment.centerRight,
                        end: Alignment.centerLeft,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.point_of_sale,
                          color: Colors.white,
                          size: 22,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'نقطة البيع (POS) [F1]',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const Directionality(
                          textDirection: TextDirection.rtl,
                          child: InvoicesArchiveScreen(),
                        ),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.indigo.shade200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.history_edu_rounded,
                          color: Colors.indigo.shade700,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'أرشيف الفواتير',
                          style: TextStyle(
                            color: Colors.indigo.shade800,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                InkWell(
                  onTap: _showReturnDialog,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.alertRed.withValues(alpha: 0.3),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.assignment_return,
                          color: AppColors.alertRed,
                          size: 18,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'مرتجع مبيعات',
                          style: TextStyle(
                            color: AppColors.alertRed,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                InkWell(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (_) => const RecordWasteDialog(),
                    );
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.alertRed.withValues(alpha: 0.3),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.delete_sweep,
                          color: AppColors.alertRed,
                          size: 18,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'تسجيل هالك / تالف',
                          style: TextStyle(
                            color: AppColors.alertRed,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                InkWell(
                  onTap: _showAddExpenseDialog,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.capitalGold.withValues(alpha: 0.3),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.receipt_long,
                          color: AppColors.capitalGold,
                          size: 18,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'تسجيل مصروف',
                          style: TextStyle(
                            color: Color(0xFF92400E),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const Directionality(
                          textDirection: TextDirection.rtl,
                          child: ShiftClosingScreen(),
                        ),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.lock_clock,
                          color: AppColors.primary,
                          size: 18,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'تقفيل الوردية',
                          style: TextStyle(
                            color: AppColors.primaryDark,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                InkWell(
                  onTap: _toggleCashierLock,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: _store.isCashierLocked
                          ? Colors.red.shade900
                          : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _store.isCashierLocked ? Icons.lock : Icons.lock_open,
                          color: _store.isCashierLocked
                              ? Colors.white
                              : Colors.black87,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _store.isCashierLocked
                              ? 'وضع الكاشير (مغلق)'
                              : 'وضع الأدمن (مفتوح)',
                          style: TextStyle(
                            color: _store.isCashierLocked
                                ? Colors.white
                                : Colors.black87,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // 1. كروت تقارير اليوم والشهر الحقيقية
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 600;
                final todayCard = _buildReportCard(
                  title: 'تقارير اليوم الحالية',
                  totalAmount: _store.todayTotalVolume,
                  txCount: _store.todayTransactions.length,
                  sentAmount: _store.todaySent,
                  receivedAmount: _store.todayReceived,
                  profitAmount: _store.todayProfits,
                  isProfitVisible: _showTodayProfit,
                  onToggleProfit: () {
                    if (!_store.isCashierLocked) {
                      setState(() => _showTodayProfit = !_showTodayProfit);
                    } else {
                      _promptAdminPin(() {
                        setState(() => _showTodayProfit = !_showTodayProfit);
                      });
                    }
                  },
                );
                final monthCard = _buildReportCard(
                  title: 'تقارير الشهر الفعلية',
                  totalAmount: _store.monthTotalVolume,
                  txCount: _store.monthTransactions.length,
                  sentAmount: _store.monthSent,
                  receivedAmount: _store.monthReceived,
                  profitAmount: _store.monthProfits,
                  isProfitVisible: _showMonthProfit,
                  onToggleProfit: () {
                    if (!_store.isCashierLocked) {
                      setState(() => _showMonthProfit = !_showMonthProfit);
                    } else {
                      _promptAdminPin(() {
                        setState(() => _showMonthProfit = !_showMonthProfit);
                      });
                    }
                  },
                );

                if (isWide) {
                  return Row(
                    children: [
                      Expanded(child: monthCard),
                      const SizedBox(width: 12),
                      Expanded(child: todayCard),
                    ],
                  );
                }
                return Column(
                  children: [todayCard, const SizedBox(height: 12), monthCard],
                );
              },
            ),
            const SizedBox(height: 12),

            // 2. بطاقات الأرصدة الفعلية الأربعة
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _buildBalanceCard(
                  title: 'درج الكاشير الفعلي',
                  amount: _store.cashInDrawer,
                  bgColor: const Color(0xFFD1FAE5),
                  textColor: const Color(0xFF065F46),
                  icon: Icons.payments,
                  onAddTap: _showEditDrawerCashDialog,
                ),
                _buildBalanceCard(
                  title: 'أرصدة المحافظ',
                  amount: _store.totalWalletsBalance,
                  bgColor: const Color(0xFFDBEAFE),
                  textColor: const Color(0xFF1E40AF),
                  icon: Icons.account_balance_wallet,
                ),
                _buildBalanceCard(
                  title: 'بضاعة المخزن (شراء)',
                  amount: _store.inventoryValue,
                  bgColor: const Color(0xFFEDE9FE),
                  textColor: const Color(0xFF5B21B6),
                  icon: Icons.inventory_2_outlined,
                  onAddTap: () => _promptAdminPin(() {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const Directionality(
                          textDirection: TextDirection.rtl,
                          child: InventoryScreen(),
                        ),
                      ),
                    );
                  }),
                ),
                _buildBalanceCard(
                  title: 'رأس المال الشامل',
                  amount: _store.totalCapital,
                  bgColor: const Color(0xFFFEF3C7),
                  textColor: const Color(0xFF92400E),
                  icon: Icons.account_balance,
                ),
              ],
            ),
            const SizedBox(height: 14),

            // 3. شريط أيقونات الـ ERP الكامل المتجاوب بدون Overflow
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'سجل العمليات والفواتير',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: _showResetWizardDialog,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade800,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(
                                      Icons.restart_alt,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'تجهيز وبدء تشغيل حقيقي',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),

                        // شريط الموديولات متجاوب بـ Wrap لمنع تجاوز حدود الشاشة
                        Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _buildErpModuleIcon(
                              label: 'قائمة الدخل (P&L)',
                              icon: Icons.request_quote_rounded,
                              iconColor: const Color(0xFF047857),
                              onTap: () => _promptAdminPin(() {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const Directionality(
                                      textDirection: TextDirection.rtl,
                                      child: IncomeStatementScreen(),
                                    ),
                                  ),
                                );
                              }),
                            ),
                            _buildErpModuleIcon(
                              label: 'أرشيف الفواتير',
                              icon: Icons.history_edu_rounded,
                              iconColor: Colors.indigo.shade700,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const Directionality(
                                    textDirection: TextDirection.rtl,
                                    child: InvoicesArchiveScreen(),
                                  ),
                                ),
                              ),
                            ),
                            _buildErpModuleIcon(
                              label: 'التقارير والأرباح',
                              icon: Icons.analytics_outlined,
                              iconColor: AppColors.capitalGold,
                              onTap: () => _promptAdminPin(() {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const Directionality(
                                      textDirection: TextDirection.rtl,
                                      child: ReportsScreen(),
                                    ),
                                  ),
                                );
                              }),
                            ),
                            _buildErpModuleIcon(
                              label: 'المخزن والنواقص',
                              icon: Icons.inventory_2_rounded,
                              iconColor: AppColors.primary,
                              badgeCount: _store.lowStockCount,
                              onTap: () => _promptAdminPin(() {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const Directionality(
                                      textDirection: TextDirection.rtl,
                                      child: InventoryScreen(),
                                    ),
                                  ),
                                );
                              }),
                            ),
                            _buildErpModuleIcon(
                              label: 'الديون (الشكك)',
                              icon: Icons.receipt_long_rounded,
                              iconColor: AppColors.alertRed,
                              badgeCount: _store.openDebtsCount,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const Directionality(
                                    textDirection: TextDirection.rtl,
                                    child: DebtsScreen(),
                                  ),
                                ),
                              ),
                            ),
                            _buildErpModuleIcon(
                              label: 'الموردين والجملة',
                              icon: Icons.local_shipping_rounded,
                              iconColor: AppColors.purpleAccent,
                              onTap: () => _promptAdminPin(() {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const Directionality(
                                      textDirection: TextDirection.rtl,
                                      child: SuppliersScreen(),
                                    ),
                                  ),
                                );
                              }),
                            ),
                            _buildErpModuleIcon(
                              label: 'فوري وأمان',
                              icon: Icons.point_of_sale_rounded,
                              iconColor: AppColors.transferBlue,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const Directionality(
                                    textDirection: TextDirection.rtl,
                                    child: SalesScreen(),
                                  ),
                                ),
                              ),
                            ),
                            _buildErpModuleIcon(
                              label: 'النسخ الاحتياطي',
                              icon: Icons.security_rounded,
                              iconColor: Colors.teal.shade700,
                              onTap: () => _promptAdminPin(() {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const Directionality(
                                      textDirection: TextDirection.rtl,
                                      child: BackupScreen(),
                                    ),
                                  ),
                                );
                              }),
                            ),
                            _buildErpModuleIcon(
                              label: 'الترخيص والهوية',
                              icon: Icons.settings_suggest_rounded,
                              iconColor: Colors.grey.shade700,
                              onTap: () => _promptAdminPin(() {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const Directionality(
                                      textDirection: TextDirection.rtl,
                                      child: MarketSettingsScreen(),
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        SizedBox(
                          width: 200,
                          height: 38,
                          child: TextField(
                            onChanged: (val) =>
                                setState(() => _searchQuery = val),
                            decoration: InputDecoration(
                              hintText: 'بحث برقم هاتف أو مبلغ...',
                              prefixIcon: const Icon(Icons.search, size: 18),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                        ...['التحويل', 'السحب', 'مؤجل', 'الكل'].map((
                          filterName,
                        ) {
                          final isSelected = _selectedFilter == filterName;
                          return ChoiceChip(
                            label: Text(
                              filterName,
                              style: const TextStyle(fontSize: 12),
                            ),
                            selected: isSelected,
                            selectedColor: AppColors.primary,
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.bold,
                            ),
                            onSelected: (_) =>
                                setState(() => _selectedFilter = filterName),
                          );
                        }),
                      ],
                    ),
                    const SizedBox(height: 14),

                    if (filteredTx.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(
                          child: Text(
                            'لا توجد فواتير أو معاملات مسجلة حتى الآن',
                          ),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filteredTx.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          return _buildTransactionItem(filteredTx[index]);
                        },
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildReportCard({
    required String title,
    required double totalAmount,
    required int txCount,
    required double sentAmount,
    required double receivedAmount,
    required double profitAmount,
    required bool isProfitVisible,
    required VoidCallback onToggleProfit,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.assessment_outlined,
                      size: 18,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const Icon(
                  Icons.description_outlined,
                  size: 18,
                  color: Colors.grey,
                ),
              ],
            ),
            const Divider(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'الإجمالي: ${_numFormat.format(totalAmount.toInt())}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                Text(
                  'العمليات: $txCount',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'المنصرف/المرتجع: ${_numFormat.format(sentAmount.toInt())}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.transferBlue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'المبيعات/الوارد: ${_numFormat.format(receivedAmount.toInt())}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.receiveGreen,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            InkWell(
              onTap: onToggleProfit,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.trending_up,
                          size: 16,
                          color: AppColors.capitalGold,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isProfitVisible
                              ? 'صافي الأرباح: ${_numFormat.format(profitAmount.toInt())} ج.م'
                              : 'صافي الأرباح: ••••••',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF92400E),
                          ),
                        ),
                      ],
                    ),
                    Icon(
                      isProfitVisible
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 16,
                      color: const Color(0xFF92400E),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceCard({
    required String title,
    required double amount,
    required Color bgColor,
    required Color textColor,
    required IconData icon,
    VoidCallback? onAddTap,
  }) {
    return Container(
      width: 195,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, size: 16, color: textColor),
                  const SizedBox(width: 6),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ],
              ),
              if (onAddTap != null)
                InkWell(
                  onTap: onAddTap,
                  child: Icon(Icons.edit_outlined, size: 16, color: textColor),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${_numFormat.format(amount.toInt())} جنيه',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErpModuleIcon({
    required String label,
    required IconData icon,
    required Color iconColor,
    int? badgeCount,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Colors.black54),
          ),
          const SizedBox(height: 4),
          Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(icon, color: iconColor, size: 24),
              if (badgeCount != null && badgeCount > 0)
                Positioned(
                  top: -6,
                  left: -8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.alertRed,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$badgeCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _approvePending(TransactionModel tx) {
    _promptAdminPin(() {
      final result = _store.approvePendingTransaction(tx.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.success
                ? '✅ تم اعتماد العملية وتطبيقها على رصيد المحفظة والدرج.'
                : (result.error ?? 'تعذر اعتماد العملية'),
          ),
          backgroundColor: result.success
              ? AppColors.receiveGreen
              : AppColors.alertRed,
        ),
      );
    });
  }

  void _cancelPending(TransactionModel tx) {
    _promptAdminPin(() => _confirmCancelPending(tx));
  }

  Future<void> _confirmCancelPending(TransactionModel tx) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('إلغاء العملية المؤجلة'),
          content: Text(
            'هل تريد إلغاء عملية ${_numFormat.format(tx.amount.toInt())} ج.م؟ '
            'لن يتم أي خصم أو إضافة على الرصيد.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('رجوع'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.alertRed,
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('تأكيد الإلغاء'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    final result = _store.cancelPendingTransaction(tx.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.success
              ? 'تم إلغاء العملية المؤجلة.'
              : (result.error ?? 'تعذر الإلغاء'),
        ),
        backgroundColor: result.success
            ? AppColors.primary
            : AppColors.alertRed,
      ),
    );
  }

  Widget _buildTransactionItem(TransactionModel tx) {
    final isDebt = tx.status == TransactionStatus.debt;
    final isPending = tx.status == TransactionStatus.pending;
    final isTransfer = tx.type == TransactionType.transfer;
    final isExpense = tx.walletPhone == 'مصروفات ونثريات';
    final isReturn = tx.walletPhone == 'مرتجع مبيعات';
    final isWaste = tx.walletPhone == 'بضاعة تالفة وهالك';
    final timeStr = DateFormat('yyyy/MM/dd hh:mm a').format(tx.createdAt);

    Color tagColor = AppColors.primary;
    String statusLabel = 'مكتملة';
    IconData iconData = isTransfer
        ? Icons.call_made
        : Icons.shopping_basket_rounded;

    if (isDebt) {
      tagColor = AppColors.alertRed;
      statusLabel = 'آجل لم يسدد';
      iconData = Icons.receipt;
    } else if (isPending) {
      tagColor = const Color(0xFF6B21A8);
      statusLabel = 'مؤجلة بانتظار الاعتماد';
      iconData = Icons.schedule;
    } else if (isExpense) {
      tagColor = Colors.amber.shade800;
      statusLabel = 'مصروف';
      iconData = Icons.receipt_long;
    } else if (isReturn) {
      tagColor = AppColors.alertRed;
      statusLabel = 'مرتجع مبيعات';
      iconData = Icons.assignment_return;
    } else if (isWaste) {
      tagColor = Colors.deepOrange;
      statusLabel = 'هالك وتالف';
      iconData = Icons.delete_sweep;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isPending
            ? const Color(0xFFFAF5FF)
            : isDebt || isReturn || isWaste
            ? const Color(0xFFFEF2F2)
            : (isExpense ? const Color(0xFFFFFBEB) : const Color(0xFFF8FAFC)),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isPending
              ? const Color(0xFF6B21A8).withValues(alpha: 0.35)
              : isDebt || isReturn || isWaste
              ? AppColors.alertRed.withValues(alpha: 0.3)
              : (isExpense ? Colors.amber.shade200 : Colors.grey.shade200),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(iconData, color: tagColor),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tx.walletPhone,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: isDebt || isReturn || isWaste
                          ? AppColors.alertRed
                          : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    tx.clientName ?? tx.clientPhone,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    timeStr,
                    style: const TextStyle(fontSize: 11, color: Colors.black54),
                  ),
                ],
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${_numFormat.format(tx.amount.toInt())} ج.م',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: isExpense || isDebt || isReturn || isWaste
                      ? AppColors.alertRed
                      : AppColors.primaryDark,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                statusLabel,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: tagColor,
                ),
              ),
              if (isPending) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      height: 30,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.receiveGreen,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                        ),
                        onPressed: () => _approvePending(tx),
                        icon: const Icon(Icons.check, size: 15),
                        label: const Text(
                          'اعتماد',
                          style: TextStyle(fontSize: 11),
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 30,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.alertRed,
                          side: const BorderSide(color: AppColors.alertRed),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                        ),
                        onPressed: () => _cancelPending(tx),
                        child: const Text(
                          'إلغاء',
                          style: TextStyle(fontSize: 11),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
