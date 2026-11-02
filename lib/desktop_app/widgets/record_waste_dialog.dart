import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/database/cashawy_store.dart';
import '../../models/product_model.dart';

class RecordWasteDialog extends StatefulWidget {
  final ProductModel? initialProduct;

  const RecordWasteDialog({super.key, this.initialProduct});

  @override
  State<RecordWasteDialog> createState() => _RecordWasteDialogState();
}

class _RecordWasteDialogState extends State<RecordWasteDialog> {
  final CashawyStore _store = CashawyStore.instance;
  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _qtyCtrl = TextEditingController(text: '1');
  
  ProductModel? _selectedProduct;
  String _selectedReason = 'كسر / تلف أثناء النقل والترتيب';

  final List<String> _wasteReasons = [
    'كسر / تلف أثناء النقل والترتيب',
    'انتهاء تاريخ الصلاحية',
    'عيب تصنيع / عبوة منتفخة أو مفتوحة',
    'تلف سوء تخزين / تبريد',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialProduct != null) {
      _selectedProduct = widget.initialProduct;
      _searchCtrl.text = widget.initialProduct!.name;
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _qtyCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    final clean = query.trim().toLowerCase();
    if (clean.isEmpty) {
      setState(() => _selectedProduct = null);
      return;
    }

    final index = _store.products.indexWhere(
      (p) => p.barcode == clean || p.id == clean || p.name.toLowerCase().contains(clean),
    );

    if (index != -1) {
      setState(() => _selectedProduct = _store.products[index]);
    } else {
      setState(() => _selectedProduct = null);
    }
  }

  void _submitWaste() {
    if (_selectedProduct == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ يرجى اختيار الصنف المراد إتلافه'), backgroundColor: AppColors.alertRed),
      );
      return;
    }

    final qty = double.tryParse(_qtyCtrl.text.trim()) ?? 0.0;
    if (qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ يرجى إدخال كمية صحيحة أكبر من صفر'), backgroundColor: AppColors.alertRed),
      );
      return;
    }

    if (qty > _selectedProduct!.stockQuantity) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⚠️ الكمية بالمخزن (${_selectedProduct!.stockQuantity}) أقل من الكمية المراد إتلافها!'),
          backgroundColor: AppColors.alertRed,
        ),
      );
      return;
    }

    final success = _store.recordDamagedProduct(
      barcodeOrId: _selectedProduct!.barcode,
      quantity: qty,
      reason: _selectedReason,
    );

    if (success) {
      Navigator.pop(context);
      final totalLoss = (qty * _selectedProduct!.buyPrice).toStringAsFixed(1);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🗑️ تم تسجيل التالف وخصم $qty من المخزن واحتساب خسارة تكلفة ($totalLoss ج.م)'),
          backgroundColor: Colors.amber.shade900,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final qty = double.tryParse(_qtyCtrl.text.trim()) ?? 1.0;
    final totalLoss = _selectedProduct != null ? (qty * _selectedProduct!.buyPrice) : 0.0;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.delete_sweep, color: AppColors.alertRed),
            SizedBox(width: 8),
            Text('تسجيل بضاعة تالفة / هالك مخزن'),
          ],
        ),
        content: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'سيتم خصم الكمية من المخزن واحتساب التكلفة كخسائر محاسبية بدون التأثير على درج الكاشير.',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 12),

                if (widget.initialProduct == null) ...[
                  TextField(
                    controller: _searchCtrl,
                    autofocus: true,
                    onChanged: _onSearchChanged,
                    decoration: const InputDecoration(
                      labelText: 'ابحث بالاسم أو الباركود...',
                      prefixIcon: Icon(Icons.qr_code_scanner),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                if (_selectedProduct != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.alertRed.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_selectedProduct!.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('الرصيد الحالي: ${_selectedProduct!.stockQuantity}', style: const TextStyle(fontSize: 12, color: Colors.black87)),
                            Text('سعر التكلفة: ${_selectedProduct!.buyPrice} ج.م', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.alertRed)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                TextField(
                  controller: _qtyCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: _selectedProduct?.isWeighted == true ? 'الوزن التالف بالكيلوجرام' : 'الكمية التالفة (قطع/علب)',
                    prefixIcon: const Icon(Icons.pin_outlined),
                  ),
                ),
                const SizedBox(height: 12),

                DropdownButtonFormField<String>(
                  value: _selectedReason,
                  decoration: const InputDecoration(
                    labelText: 'سبب الإتلاف / الهالك',
                    prefixIcon: Icon(Icons.report_problem_outlined),
                  ),
                  items: _wasteReasons.map((r) => DropdownMenuItem(value: r, child: Text(r, style: const TextStyle(fontSize: 13)))).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedReason = val);
                  },
                ),
                const SizedBox(height: 14),

                if (_selectedProduct != null)
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.shade300),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('إجمالي قيمة خسارة التكلفة:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        Text('${totalLoss.toStringAsFixed(1)} ج.م', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.amber.shade900)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.alertRed),
            onPressed: _submitWaste,
            icon: const Icon(Icons.delete_outline),
            label: const Text('تأكيد خصم التالف'),
          ),
        ],
      ),
    );
  }
}