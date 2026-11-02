import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../core/theme/app_theme.dart';
import '../../core/database/cashawy_store.dart';
import '../../models/product_model.dart';

class ReceiptDialog extends StatelessWidget {
  final String invoiceNumber;
  final List<CartItemModel> items;
  final double totalAmount;
  final double discount;
  final String paymentMethod;
  final String? customerName;
  final String? customerPhone;

  const ReceiptDialog({
    super.key,
    required this.invoiceNumber,
    required this.items,
    required this.totalAmount,
    this.discount = 0.0,
    required this.paymentMethod,
    this.customerName,
    this.customerPhone,
  });

  @override
  Widget build(BuildContext context) {
    final store = CashawyStore.instance;
    final numFormat = NumberFormat('#,##0.00');
    final nowStr = DateFormat('yyyy/MM/dd hh:mm a').format(DateTime.now());

    String paymentLabel = 'نقدي (كاش)';
    if (paymentMethod == 'wallet') paymentLabel = 'محفظة إلكترونية';
    if (paymentMethod == 'debt') paymentLabel = 'آجل (شكك)';

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
                        Text('معاينة بون الكاشير', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                      if (store.taxAndCommercialReg.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(store.taxAndCommercialReg, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, color: Colors.black54)),
                      ],
                      const SizedBox(height: 8),
                      const Text('------------------------------------------', style: TextStyle(color: Colors.black45)),
                      
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('فاتورة: $invoiceNumber', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black)),
                          Text('الكاشير: ${store.activeCashier}', style: const TextStyle(fontSize: 11, color: Colors.black)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(nowStr, style: const TextStyle(fontSize: 10, color: Colors.black54)),
                          Text('الدفع: $paymentLabel', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black)),
                        ],
                      ),
                      if (customerPhone != null && customerPhone!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text('العميل: ${customerName ?? ''} ($customerPhone)', style: const TextStyle(fontSize: 11, color: Colors.black87)),
                        ),
                      ],
                      const Text('------------------------------------------', style: TextStyle(color: Colors.black45)),

                      // جدول الأصناف
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: const [
                          Expanded(flex: 5, child: Text('الصنف', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black))),
                          Expanded(flex: 2, child: Text('الكمية', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black))),
                          Expanded(flex: 3, child: Text('الإجمالي', textAlign: TextAlign.left, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black))),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ...items.map((item) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Row(
                              children: [
                                Expanded(flex: 5, child: Text(item.product.name, style: const TextStyle(fontSize: 11, color: Colors.black87))),
                                Expanded(flex: 2, child: Text('${item.quantity}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: Colors.black87))),
                                Expanded(flex: 3, child: Text('${numFormat.format(item.subtotal)} ج', textAlign: TextAlign.left, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black))),
                              ],
                            ),
                          )),

                      const Text('------------------------------------------', style: TextStyle(color: Colors.black45)),

                      if (discount > 0) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('قيمة الخصم:', style: TextStyle(fontSize: 11, color: Colors.black87)),
                            Text('- ${numFormat.format(discount)} ج.م', style: const TextStyle(fontSize: 11, color: AppColors.alertRed)),
                          ],
                        ),
                        const SizedBox(height: 4),
                      ],

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('الإجمالي المطلوب:', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Colors.black)),
                          Text(
                            '${numFormat.format(totalAmount)} ج.م',
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.black),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // رسالة التذييل وسياسة الاسترجاع المخصصة
                      Text(
                        store.receiptFooterMessage,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        store.returnPolicyNote,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 9, color: Colors.black54),
                      ),
                      const SizedBox(height: 6),
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
                        child: const Text('إغلاق البون'),
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
                              content: Text('🖨️ جاري إرسال البون إلى طابعة الفواتير الحرارية...'),
                              backgroundColor: AppColors.receiveGreen,
                            ),
                          );
                        },
                        icon: const Icon(Icons.print),
                        label: const Text('طباعة البون'),
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