import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../core/theme/app_theme.dart';
import '../../core/database/cashawy_store.dart';
import '../../models/transaction_model.dart';
import '../widgets/invoice_reprint_dialog.dart';

class InvoicesArchiveScreen extends StatefulWidget {
  const InvoicesArchiveScreen({super.key});

  @override
  State<InvoicesArchiveScreen> createState() => _InvoicesArchiveScreenState();
}

class _InvoicesArchiveScreenState extends State<InvoicesArchiveScreen> {
  final CashawyStore _store = CashawyStore.instance;
  final NumberFormat _numFormat = NumberFormat('#,##0.00');

  String _filter = 'اليوم'; // 'اليوم', 'الآجل (الشكك)', 'الكل'
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history_edu_rounded, color: Colors.white),
            SizedBox(width: 8),
            Text('أرشيف وسجل الفواتير - البحث وإعادة الطباعة'),
          ],
        ),
      ),
      body: ListenableBuilder(
        listenable: _store,
        builder: (context, _) {
          // فلترة الفواتير الخاصة بالسوبر ماركت فقط
          final invoices = _store.transactions.where((tx) {
            if (tx.status == TransactionStatus.trash) return false;
            final isInvoice = tx.id.startsWith('INV-') || tx.walletPhone == 'كاشير السوبر ماركت';
            if (!isInvoice) return false;

            if (_filter == 'اليوم') {
              final isToday = tx.createdAt.year == now.year &&
                  tx.createdAt.month == now.month &&
                  tx.createdAt.day == now.day;
              if (!isToday) return false;
            } else if (_filter == 'الآجل (الشكك)') {
              if (tx.status != TransactionStatus.debt) return false;
            }

            if (_searchQuery.isNotEmpty) {
              final q = _searchQuery.trim().toLowerCase();
              final matchId = tx.id.toLowerCase().contains(q);
              final matchPhone = tx.clientPhone.toLowerCase().contains(q);
              final matchName = (tx.clientName ?? '').toLowerCase().contains(q);
              final matchNotes = (tx.notes ?? '').toLowerCase().contains(q);
              return matchId || matchPhone || matchName || matchNotes;
            }

            return true;
          }).toList();

          final totalSum = invoices.fold(0.0, (sum, item) => sum + item.amount);

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // كارت ملخص الفواتير
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.receipt_long, color: AppColors.primary, size: 30),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('عدد الفواتير المعروضة', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryDark)),
                                Text('${invoices.length} فاتورة', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.primaryDark)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.payments_outlined, color: AppColors.secondary, size: 30),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('إجمالي قيمة الفواتير المعروضة', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.secondary)),
                                Text('${_numFormat.format(totalSum)} ج.م', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.secondary)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // شريط البحث والفلترة
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        onChanged: (val) => setState(() => _searchQuery = val),
                        decoration: const InputDecoration(
                          hintText: 'ابحث برقم الفاتورة (INV-...)، رقم الهاتف، أو اسم المنتج...',
                          prefixIcon: Icon(Icons.search),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ...['اليوم', 'الآجل (الشكك)', 'الكل'].map((f) {
                      final isSel = _filter == f;
                      return Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: ChoiceChip(
                          label: Text(f),
                          selected: isSel,
                          selectedColor: AppColors.primary,
                          labelStyle: TextStyle(color: isSel ? Colors.white : Colors.black87, fontWeight: FontWeight.bold),
                          onSelected: (_) => setState(() => _filter = f),
                        ),
                      );
                    }),
                  ],
                ),
                const SizedBox(height: 14),

                // جدول قائمة الفواتير
                Expanded(
                  child: Card(
                    child: invoices.isEmpty
                        ? const Center(child: Text('لا توجد فواتير مطابقة لخيارات البحث'))
                        : ListView.separated(
                            itemCount: invoices.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final tx = invoices[index];
                              final isDebt = tx.status == TransactionStatus.debt;
                              final timeStr = DateFormat('yyyy/MM/dd hh:mm a').format(tx.createdAt);

                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: isDebt
                                      ? AppColors.alertRed.withValues(alpha: 0.1)
                                      : AppColors.primary.withValues(alpha: 0.1),
                                  child: Icon(
                                    isDebt ? Icons.receipt : Icons.shopping_basket_rounded,
                                    color: isDebt ? AppColors.alertRed : AppColors.primary,
                                  ),
                                ),
                                title: Row(
                                  children: [
                                    Text(tx.id, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'monospace')),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isDebt ? AppColors.alertRed : AppColors.receiveGreen,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        isDebt ? 'شكك / آجل' : 'مدفوعة',
                                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Text(tx.notes ?? (tx.clientName ?? tx.clientPhone), style: const TextStyle(fontSize: 12, color: Colors.black87)),
                                    Text(timeStr, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '${_numFormat.format(tx.amount)} ج.م',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w900,
                                        color: isDebt ? AppColors.alertRed : AppColors.primaryDark,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.secondary,
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      ),
                                      onPressed: () {
                                        showDialog(
                                          context: context,
                                          builder: (_) => InvoiceReprintDialog(transaction: tx),
                                        );
                                      },
                                      icon: const Icon(Icons.print, size: 16),
                                      label: const Text('معاينة وطباعة'),
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