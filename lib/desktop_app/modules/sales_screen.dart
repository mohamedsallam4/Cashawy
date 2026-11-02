import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../core/theme/app_theme.dart';
import '../../core/database/cashawy_store.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  final CashawyStore _store = CashawyStore.instance;
  final NumberFormat _numFormat = NumberFormat('#,##0');

  // متحكمات المبيعات
  final TextEditingController _itemNameController = TextEditingController();
  final TextEditingController _itemPriceController = TextEditingController();

  // متحكمات الماكينات
  bool _isFawrySelected = true;
  bool _isCashIn = true; // true = إيداع، false = سحب كاش
  final TextEditingController _machineAmountController = TextEditingController();
  final TextEditingController _machineCommissionController = TextEditingController(text: '0');

  @override
  void dispose() {
    _itemNameController.dispose();
    _itemPriceController.dispose();
    _machineAmountController.dispose();
    _machineCommissionController.dispose();
    super.dispose();
  }

  void _submitSale() {
    final price = double.tryParse(_itemPriceController.text) ?? 0;
    final name = _itemNameController.text.trim();
    if (price > 0) {
      _store.processSale(name, price);
      _itemPriceController.clear();
      _itemNameController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ تم تسجيل المبيعات وإضافتها للخزنة'), backgroundColor: AppColors.receiveGreen),
      );
    }
  }

  void _submitMachineTransaction() {
    final amount = double.tryParse(_machineAmountController.text) ?? 0;
    final commission = double.tryParse(_machineCommissionController.text) ?? 0;
    if (amount > 0) {
      _store.processMachineTransaction(
        isFawry: _isFawrySelected,
        isCashIn: _isCashIn,
        amount: amount,
        commission: commission,
      );
      _machineAmountController.clear();
      _machineCommissionController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ تم تسجيل عملية ${_isFawrySelected ? 'فوري' : 'أمان'} بنجاح وتحديث أرصدة الماكينة والخزنة'),
          backgroundColor: AppColors.transferBlue,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.point_of_sale, color: Colors.white),
            SizedBox(width: 8),
            Text('نقطة البيع - المبيعات وماكينات الدفع'),
          ],
        ),
      ),
      body: ListenableBuilder(
        listenable: _store,
        builder: (context, _) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ================= النصف الأول: مبيعات المحل السريعة =================
                Expanded(
                  flex: 1,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            '🛒 مبيعات المحل السريعة',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                          ),
                          const SizedBox(height: 8),
                          const Text('سجل مبيعات كروت الشحن والاكسسوارات لإضافتها فوراً لدرج الكاشير', style: TextStyle(color: Colors.grey, fontSize: 12)),
                          const Divider(height: 30),
                          TextField(
                            controller: _itemNameController,
                            decoration: const InputDecoration(
                              labelText: 'اسم الصنف (مثال: كارت فكة 10، جراب)',
                              prefixIcon: Icon(Icons.shopping_bag_outlined),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _itemPriceController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'السعر (ج.م)',
                              prefixIcon: Icon(Icons.payments_outlined),
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.receiveGreen, padding: const EdgeInsets.symmetric(vertical: 16)),
                            onPressed: _submitSale,
                            icon: const Icon(Icons.add_shopping_cart),
                            label: const Text('تسجيل البيع وإضافة النقدية للخزنة'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // ================= النصف الثاني: ماكينات فوري وأمان =================
                Expanded(
                  flex: 1,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            '🏧 إدارة ماكينات الدفع',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.transferBlue),
                          ),
                          const SizedBox(height: 12),
                          
                          // عرض أرصدة الماكينات
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(color: const Color(0xFFFEF9C3), borderRadius: BorderRadius.circular(8)),
                                  child: Column(
                                    children: [
                                      const Text('رصيد فوري', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF854D0E))),
                                      Text('${_numFormat.format(_store.fawryBalance)} ج.م', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF854D0E))),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(color: const Color(0xFFE0E7FF), borderRadius: BorderRadius.circular(8)),
                                  child: Column(
                                    children: [
                                      const Text('رصيد أمان', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF3730A3))),
                                      Text('${_numFormat.format(_store.amanBalance)} ج.م', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF3730A3))),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 30),

                          // اختيار الماكينة ونوع العملية
                          Row(
                            children: [
                              Expanded(
                                child: ChoiceChip(
                                  label: const Center(child: Text('ماكينة فوري')),
                                  selected: _isFawrySelected,
                                  onSelected: (_) => setState(() => _isFawrySelected = true),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ChoiceChip(
                                  label: const Center(child: Text('ماكينة أمان')),
                                  selected: !_isFawrySelected,
                                  onSelected: (_) => setState(() => _isFawrySelected = false),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: ChoiceChip(
                                  label: const Center(child: Text('إيداع (شحن للعميل)')),
                                  selected: _isCashIn,
                                  selectedColor: AppColors.transferBlue.withValues(alpha: 0.2),
                                  onSelected: (_) => setState(() => _isCashIn = true),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ChoiceChip(
                                  label: const Center(child: Text('سحب كاش من العميل')),
                                  selected: !_isCashIn,
                                  selectedColor: AppColors.alertRed.withValues(alpha: 0.1),
                                  onSelected: (_) => setState(() => _isCashIn = false),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          TextField(
                            controller: _machineAmountController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: _isCashIn ? 'المبلغ المراد شحنه (ج.م)' : 'مبلغ سحب الكاش (ج.م)',
                              prefixIcon: const Icon(Icons.confirmation_number_outlined),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _machineCommissionController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'عمولة المحل الإضافية (ج.م)',
                              prefixIcon: Icon(Icons.monetization_on_outlined),
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isCashIn ? AppColors.transferBlue : AppColors.alertRed,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            onPressed: _submitMachineTransaction,
                            icon: const Icon(Icons.save_alt),
                            label: Text(_isCashIn ? 'تسجيل إيداع وتوريد النقدية' : 'تسجيل سحب كاش وصرف نقدية'),
                          ),
                        ],
                      ),
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