import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../core/theme/app_theme.dart';
import '../../core/database/cashawy_store.dart';
import '../../models/transaction_model.dart';
import '../widgets/debt_statement_dialog.dart';

class DebtsScreen extends StatefulWidget {
  const DebtsScreen({super.key});

  @override
  State<DebtsScreen> createState() => _DebtsScreenState();
}

class _DebtsScreenState extends State<DebtsScreen> {
  final CashawyStore _store = CashawyStore.instance;
  final NumberFormat _numFormat = NumberFormat('#,##0.00');
  String _searchQuery = '';

  void _showPayDebtDialog(TransactionModel tx) {
    final amountCtrl = TextEditingController(text: tx.amount.toStringAsFixed(2));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.payments_outlined, color: AppColors.receiveGreen),
            const SizedBox(width: 8),
            Text('سداد دين: ${tx.clientName ?? tx.clientPhone}'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.alertRed.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('إجمالي الدين المسجل:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  Text(
                    '${_numFormat.format(tx.amount)} ج.م',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.alertRed),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: amountCtrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'المبلغ المستلم كاش الآن من العميل (ج.م)',
                prefixIcon: Icon(Icons.monetization_on_outlined),
                helperText: 'اكتب المبلغ المدفوع جزئياً أو اتركه كما هو للسداد الكامل',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.receiveGreen),
            onPressed: () {
              final paid = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
              if (paid > 0) {
                _store.payDebtAmount(transactionId: tx.id, paidAmount: paid);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('✅ تم تسجيل استلام مبلغ ${_numFormat.format(paid)} ج وإضافته لدرج الكاشير'),
                    backgroundColor: AppColors.receiveGreen,
                  ),
                );
              }
            },
            child: const Text('تأكيد الاستلام والسداد'),
          ),
        ],
      ),
    );
  }

  void _openStatement(String phone, String? name) {
    showDialog(
      context: context,
      builder: (_) => DebtStatementDialog(clientPhone: phone, clientName: name),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.menu_book, color: Colors.white),
            SizedBox(width: 8),
            Text('الدفتر الإلكتروني - إدارة الديون والشكك'),
          ],
        ),
      ),
      body: ListenableBuilder(
        listenable: _store,
        builder: (context, _) {
          final allDebts = _store.transactions.where((t) => t.status == TransactionStatus.debt).toList();

          final filteredDebts = allDebts.where((tx) {
            if (_searchQuery.isEmpty) return true;
            final q = _searchQuery.trim().toLowerCase();
            return tx.clientPhone.toLowerCase().contains(q) ||
                (tx.clientName ?? '').toLowerCase().contains(q) ||
                tx.id.toLowerCase().contains(q);
          }).toList();

          final totalDebtsMoney = allDebts.fold(0.0, (sum, tx) => sum + tx.amount);

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // كارت الإحصائيات العامة
                Card(
                  color: const Color(0xFFFEF2F2),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: AppColors.alertRed, size: 40),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'إجمالي المبالغ الآجلة المطلوبة من الزبائن (شكك في السوق)',
                                style: TextStyle(color: AppColors.alertRed, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                '${_numFormat.format(totalDebtsMoney)} ج.م',
                                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.alertRed),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.alertRed.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            '${allDebts.length} فاتورة آجلة',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.alertRed),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // شريط البحث
                TextField(
                  onChanged: (v) => setState(() => _searchQuery = v),
                  decoration: const InputDecoration(
                    hintText: 'ابحث برقم هاتف العميل، الاسم، أو كود الفاتورة...',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
                const SizedBox(height: 14),

                // جدول الديون وقائمة العملاء
                Expanded(
                  child: Card(
                    child: filteredDebts.isEmpty
                        ? const Center(
                            child: Text(
                              '🎉 لا توجد ديون مسجلة مطابقة! الدفتر نظيف.',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.receiveGreen),
                            ),
                          )
                        : ListView.separated(
                            itemCount: filteredDebts.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final tx = filteredDebts[index];
                              final timeStr = DateFormat('yyyy/MM/dd hh:mm a').format(tx.createdAt);

                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                leading: CircleAvatar(
                                  backgroundColor: AppColors.alertRed.withValues(alpha: 0.1),
                                  child: const Icon(Icons.receipt_long, color: AppColors.alertRed),
                                ),
                                title: Row(
                                  children: [
                                    Text(
                                      tx.clientName ?? tx.clientPhone,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                    ),
                                    if (tx.clientName != null) ...[
                                      const SizedBox(width: 8),
                                      Text('(${tx.clientPhone})', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                    ],
                                  ],
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Text('الفاتورة: ${tx.id} | التاريخ: $timeStr', style: const TextStyle(fontSize: 11, color: Colors.black54)),
                                    if (tx.notes != null && tx.notes!.isNotEmpty)
                                      Text(tx.notes!, style: const TextStyle(fontSize: 11, color: Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        const Text('المتبقي عليه', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                        Text(
                                          '${_numFormat.format(tx.amount)} ج.م',
                                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppColors.alertRed),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(width: 12),
                                    OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      ),
                                      onPressed: () => _openStatement(tx.clientPhone, tx.clientName),
                                      icon: const Icon(Icons.print, size: 16),
                                      label: const Text('كشف حساب'),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.receiveGreen,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      ),
                                      onPressed: () => _showPayDebtDialog(tx),
                                      icon: const Icon(Icons.payments, size: 16),
                                      label: const Text('سداد / دفعة'),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}