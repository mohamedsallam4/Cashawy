import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../core/theme/app_theme.dart';
import '../../core/database/cashawy_store.dart';
import '../../models/transaction_model.dart';

class DebtStatementDialog extends StatelessWidget {
  final String clientPhone;
  final String? clientName;

  const DebtStatementDialog({
    super.key,
    required this.clientPhone,
    this.clientName,
  });

  @override
  Widget build(BuildContext context) {
    final store = CashawyStore.instance;
    final numFormat = NumberFormat('#,##0.00');
    final customerDebts = store.getCustomerActiveDebts(clientPhone);
    final totalDue = store.getCustomerTotalDebt(clientPhone);
    final nowStr = DateFormat('yyyy/MM/dd hh:mm a').format(DateTime.now());

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // هيدر المعاينة
              Container(
                color: AppColors.secondary,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.receipt_long, color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Text('كشف حساب آجل (شكك)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // جسم الفاتورة الورقية
              SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey.shade300),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        store.marketName,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.black),
                      ),
                      const SizedBox(height: 2),
                      Text(store.marketAddress, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: Colors.black54)),
                      Text('هاتف الماركت: ${store.marketPhone}', style: const TextStyle(fontSize: 11, color: Colors.black54)),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.alertRed.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('*** كشف حساب ديون متبقية ***', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.alertRed)),
                      ),
                      const SizedBox(height: 8),
                      const Text('------------------------------------------', style: TextStyle(color: Colors.black45)),

                      Align(
                        alignment: Alignment.centerRight,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('اسم العميل: ${clientName ?? "عميل آجل"}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black)),
                            Text('رقم الهاتف: $clientPhone', style: const TextStyle(fontSize: 12, color: Colors.black87)),
                            Text('تاريخ الكشف: $nowStr', style: const TextStyle(fontSize: 10, color: Colors.black54)),
                          ],
                        ),
                      ),
                      const Text('------------------------------------------', style: TextStyle(color: Colors.black45)),

                      // قائمة الفواتير الآجلة غير المسددة
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: const [
                          Expanded(flex: 5, child: Text('الفاتورة / التاريخ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black))),
                          Expanded(flex: 3, child: Text('المتبقي', textAlign: TextAlign.left, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black))),
                        ],
                      ),
                      const SizedBox(height: 6),

                      if (customerDebts.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(12),
                          child: Text('🎉 الحساب خالص بالكامل (لا توجد مديونيات)', style: TextStyle(color: AppColors.receiveGreen, fontWeight: FontWeight.bold, fontSize: 12)),
                        )
                      else
                        ...customerDebts.map((tx) {
                          final datePart = DateFormat('yyyy/MM/dd').format(tx.createdAt);
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      flex: 5,
                                      child: Text(
                                        '${tx.id} ($datePart)',
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 3,
                                      child: Text(
                                        '${numFormat.format(tx.amount)} ج',
                                        textAlign: TextAlign.left,
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.alertRed),
                                      ),
                                    ),
                                  ],
                                ),
                                if (tx.notes != null && tx.notes!.isNotEmpty)
                                  Text(
                                    tx.notes!,
                                    style: const TextStyle(fontSize: 10, color: Colors.black54),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                const Divider(height: 8, color: Colors.black12),
                              ],
                            ),
                          );
                        }),

                      const Text('------------------------------------------', style: TextStyle(color: Colors.black45)),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('إجمالي الدين المستحق:', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Colors.black)),
                          Text(
                            '${numFormat.format(totalDue)} ج.م',
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: AppColors.alertRed),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text('برجاء المراجعة وسداد المستحق مع الشكر 🙏', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87)),
                      Text('مسؤول الوردية: ${store.activeCashier}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 9, color: Colors.black45)),
                    ],
                  ),
                ),
              ),

              // أزرار التحكم
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('إغلاق'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                        onPressed: () {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('🖨️ جاري إرسال كشف الحساب لطابعة البونات الحرارية...'),
                              backgroundColor: AppColors.receiveGreen,
                            ),
                          );
                        },
                        icon: const Icon(Icons.print),
                        label: const Text('طباعة الكشف'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}