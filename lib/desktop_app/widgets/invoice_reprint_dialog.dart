import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../core/theme/app_theme.dart';
import '../../core/database/cashawy_store.dart';
import '../../models/transaction_model.dart';

class InvoiceReprintDialog extends StatelessWidget {
  final TransactionModel transaction;

  const InvoiceReprintDialog({super.key, required this.transaction});

  @override
  Widget build(BuildContext context) {
    final store = CashawyStore.instance;
    final numFormat = NumberFormat('#,##0.00');
    final timeStr = DateFormat('yyyy/MM/dd hh:mm a').format(transaction.createdAt);

    // تحديد طريقة الدفع
    String paymentLabel = 'نقدي (كاش)';
    if (transaction.status == TransactionStatus.debt) {
      paymentLabel = 'آجل (شكك)';
    } else if (transaction.walletPhone.startsWith('01')) {
      paymentLabel = 'محفظة إلكترونية';
    }

    // تفكيك بنود الفاتورة من الملاحظات
    final List<String> rawItems = (transaction.notes ?? '').split('، ');

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
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
                        Icon(Icons.print, color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Text('إعادة طباعة فاتورة (نسخة ثانية)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                      Text('هاتف: ${store.marketPhone}', style: const TextStyle(fontSize: 11, color: Colors.black54)),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('*** نسخة إعادة طباعة ***', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black87)),
                      ),
                      const SizedBox(height: 6),
                      const Text('------------------------------------------', style: TextStyle(color: Colors.black45)),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('فاتورة: ${transaction.id}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black)),
                          Text('الكاشير: ${store.activeCashier}', style: const TextStyle(fontSize: 11, color: Colors.black)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(timeStr, style: const TextStyle(fontSize: 10, color: Colors.black54)),
                          Text('الدفع: $paymentLabel', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black)),
                        ],
                      ),
                      if (transaction.clientPhone.isNotEmpty && transaction.clientPhone != 'عميل نقدي') ...[
                        const SizedBox(height: 4),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text('العميل: ${transaction.clientName ?? ''} (${transaction.clientPhone})', style: const TextStyle(fontSize: 11, color: Colors.black87)),
                        ),
                      ],
                      const Text('------------------------------------------', style: TextStyle(color: Colors.black45)),

                      // قائمة الأصناف المسجلة
                      Align(
                        alignment: Alignment.centerRight,
                        child: const Text('الأصناف المباعة:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black)),
                      ),
                      const SizedBox(height: 6),
                      if (rawItems.isEmpty || (rawItems.length == 1 && rawItems.first.isEmpty))
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(transaction.clientName ?? 'فاتورة مبيعات عامة', style: const TextStyle(fontSize: 12, color: Colors.black87)),
                        )
                      else
                        ...rawItems.map((itemStr) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(child: Text(itemStr, style: const TextStyle(fontSize: 11, color: Colors.black87))),
                                ],
                              ),
                            )),

                      const Text('------------------------------------------', style: TextStyle(color: Colors.black45)),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('إجمالي الفاتورة:', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Colors.black)),
                          Text(
                            '${numFormat.format(transaction.amount)} ج.م',
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.black),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text('شكراً لزيارتكم! نتشرف بخدمتكم دائماً 🙏', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87)),
                      Text('كود الترخيص: ${store.licenseKey}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 8, color: Colors.black38)),
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
                              content: Text('🖨️ جاري إرسال نسخة الفاتورة إلى طابعة البونات الحرارية...'),
                              backgroundColor: AppColors.receiveGreen,
                            ),
                          );
                        },
                        icon: const Icon(Icons.print),
                        label: const Text('طباعة البون الآن'),
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