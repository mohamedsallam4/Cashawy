import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../core/theme/app_theme.dart';
import '../../core/database/cashawy_store.dart';
import '../../models/product_model.dart';

class SuppliersScreen extends StatefulWidget {
  const SuppliersScreen({super.key});

  @override
  State<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends State<SuppliersScreen> {
  final CashawyStore _store = CashawyStore.instance;
  final NumberFormat _numFormat = NumberFormat('#,##0.00');

  void _showAddSupplierDialog() {
    final companyCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final debtCtrl = TextEditingController(text: '0');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إضافة شركة توريد / مندوب جديد 🚚'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: companyCtrl,
              decoration: const InputDecoration(labelText: 'اسم الشركة أو المندوب (مثال: جهينة)'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'رقم هاتف المندوب'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: debtCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'رصيد آجل سابق علينا (ج.م)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              if (companyCtrl.text.trim().isNotEmpty) {
                _store.addSupplier(
                  companyCtrl.text.trim(),
                  phoneCtrl.text.trim(),
                  double.tryParse(debtCtrl.text) ?? 0.0,
                );
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('✅ تم تسجيل المورد بنجاح'), backgroundColor: AppColors.primary),
                );
              }
            },
            child: const Text('حفظ المورد'),
          ),
        ],
      ),
    );
  }

  void _showPaySupplierDialog(SupplierModel supplier) {
    final amountCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('سداد دفعة للمورد: ${supplier.companyName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('المبلغ المستحق للمورد حالياً: ${_numFormat.format(supplier.balanceOwed)} ج.م',
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.alertRed)),
            const SizedBox(height: 12),
            TextField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'المبلغ المدفوع كاش الآن من الدرج (ج.م)',
                prefixIcon: Icon(Icons.payments),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.receiveGreen),
            onPressed: () {
              final paid = double.tryParse(amountCtrl.text) ?? 0.0;
              if (paid > 0) {
                if (paid > _store.cashInDrawer) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('⚠️ النقدية في الدرج لا تكفي لدفع هذا المبلغ!'), backgroundColor: AppColors.alertRed),
                  );
                  return;
                }
                _store.paySupplier(supplier.id, paid);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('✅ تم سداد المبلغ وخصمه من درج الكاشير بنجاح'), backgroundColor: AppColors.receiveGreen),
                );
              }
            },
            child: const Text('تأكيد السداد والصرف'),
          ),
        ],
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
            Icon(Icons.local_shipping, color: Colors.white),
            SizedBox(width: 8),
            Text('الشركات والموردين - حسابات مناديب الجملة'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'إضافة مورد جديد',
            onPressed: _showAddSupplierDialog,
            icon: const Icon(Icons.person_add_alt_1),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: _store,
        builder: (context, _) {
          final totalDebtsToSuppliers = _store.suppliers.fold(0.0, (sum, s) => sum + s.balanceOwed);

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // كارت إجمالي حسابات الموردين
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.capitalGold.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.account_balance_wallet, color: AppColors.capitalGold, size: 36),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('إجمالي الديون المستحقة لشركات التوريد', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF92400E))),
                          Text('${_numFormat.format(totalDebtsToSuppliers)} ج.م',
                              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Color(0xFF92400E))),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // قائمة الموردين
                Expanded(
                  child: Card(
                    child: _store.suppliers.isEmpty
                        ? const Center(child: Text('لا يوجد موردين مسجلين حالياً'))
                        : ListView.separated(
                            itemCount: _store.suppliers.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, idx) {
                              final supplier = _store.suppliers[idx];
                              return ListTile(
                                leading: const CircleAvatar(
                                  backgroundColor: Color(0xFFEDE9FE),
                                  child: Icon(Icons.storefront, color: AppColors.purpleAccent),
                                ),
                                title: Text(supplier.companyName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                subtitle: Text('هاتف: ${supplier.phone.isNotEmpty ? supplier.phone : 'غير مسجل'}'),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        const Text('المتبقي له', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                        Text(
                                          '${_numFormat.format(supplier.balanceOwed)} ج.م',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            color: supplier.balanceOwed > 0 ? AppColors.alertRed : AppColors.receiveGreen,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(width: 12),
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                      ),
                                      onPressed: () => _showPaySupplierDialog(supplier),
                                      icon: const Icon(Icons.payment, size: 16),
                                      label: const Text('سداد دفعة'),
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