import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/database/cashawy_store.dart';
import '../../models/product_model.dart';

class ReturnItemDialog extends StatefulWidget {
  const ReturnItemDialog({super.key});

  @override
  State<ReturnItemDialog> createState() => _ReturnItemDialogState();
}

class _ReturnItemDialogState extends State<ReturnItemDialog> {
  final CashawyStore _store = CashawyStore.instance;
  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _qtyCtrl = TextEditingController(text: '1');
  final TextEditingController _refundCtrl = TextEditingController();
  final TextEditingController _reasonCtrl = TextEditingController(text: 'استرجاع من العميل');

  ProductModel? _matchedProduct;

  void _onSearchChanged(String query) {
    final clean = query.trim();
    if (clean.isEmpty) {
      setState(() => _matchedProduct = null);
      return;
    }
    final index = _store.products.indexWhere((p) => p.barcode == clean || p.id == clean || p.name.contains(clean));
    if (index != -1) {
      setState(() {
        _matchedProduct = _store.products[index];
        _updateTotalRefund();
      });
    } else {
      setState(() => _matchedProduct = null);
    }
  }

  void _updateTotalRefund() {
    if (_matchedProduct != null) {
      final qty = double.tryParse(_qtyCtrl.text.trim()) ?? 1.0;
      _refundCtrl.text = (_matchedProduct!.sellPrice * qty).toStringAsFixed(2);
    }
  }

  void _submitReturn() {
    if (_matchedProduct == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ يرجى تحديد الصنف المراد إرجاعه أولاً'), backgroundColor: AppColors.alertRed),
      );
      return;
    }

    final qty = double.tryParse(_qtyCtrl.text.trim()) ?? 1.0;
    final refund = double.tryParse(_refundCtrl.text.trim()) ?? 0.0;

    if (refund > _store.cashInDrawer) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ النقدية في الدرج لا تكفي لرد هذا المبلغ للعميل!'), backgroundColor: AppColors.alertRed),
      );
      return;
    }

    final success = _store.processReturn(
      barcodeOrId: _matchedProduct!.barcode,
      returnQuantity: qty,
      refundAmount: refund,
      reason: _reasonCtrl.text.trim(),
    );

    if (success) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ تم استرجاع الصنف للمخزن ورد المبلغ للعميل بنجاح'), backgroundColor: AppColors.receiveGreen),
      );
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _qtyCtrl.dispose();
    _refundCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.assignment_return, color: AppColors.alertRed),
          SizedBox(width: 8),
          Text('مرتجع مبيعات (رد بضاعة للدرج)'),
        ],
      ),
      content: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _searchCtrl,
                autofocus: true,
                onChanged: _onSearchChanged,
                decoration: const InputDecoration(
                  labelText: 'امسح باركود الصنف أو اكتب اسمه',
                  prefixIcon: Icon(Icons.qr_code_scanner),
                ),
              ),
              const SizedBox(height: 12),

              if (_matchedProduct != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_matchedProduct!.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          Text('سعر البيع: ${_matchedProduct!.sellPrice} ج.م', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                      Text(
                        _matchedProduct!.isWeighted ? 'المخزن: ${_matchedProduct!.stockQuantity.toStringAsFixed(2)} كجم' : 'المخزن: ${_matchedProduct!.stockQuantity.toInt()} ق',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _qtyCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => _updateTotalRefund(),
                      decoration: InputDecoration(
                        labelText: _matchedProduct?.isWeighted == true ? 'الوزن المرتجع (كجم)' : 'الكمية المرتجعة',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _refundCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'المبلغ المسترد للعميل (ج.م)'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              TextField(
                controller: _reasonCtrl,
                decoration: const InputDecoration(labelText: 'سبب الإرجاع (تالف / استبدال)'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.alertRed),
          onPressed: _submitReturn,
          icon: const Icon(Icons.check),
          label: const Text('تأكيد المرتجع ورد النقدية'),
        ),
      ],
    );
  }
}