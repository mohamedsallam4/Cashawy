import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../core/theme/app_theme.dart';
import '../../core/database/cashawy_store.dart';
import '../../models/product_model.dart';
import '../widgets/barcode_label_dialog.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final CashawyStore _store = CashawyStore.instance;
  final NumberFormat _numFormat = NumberFormat('#,##0');
  String _filter = 'الكل';
  String _searchQuery = '';

  void _showRestockDialog(ProductModel product) {
    final qtyCtrl = TextEditingController(text: product.isWeighted ? '5.0' : '10');
    final buyCtrl = TextEditingController(text: product.buyPrice.toString());
    final sellCtrl = TextEditingController(text: product.sellPrice.toString());
    bool payCash = true;
    String? selectedSupId = _store.suppliers.isNotEmpty ? _store.suppliers.first.id : null;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('📦 توريد واستلام بضاعة: ${product.name}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: qtyCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'الكمية المستلمة (${product.unitName})',
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: buyCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(labelText: 'سعر شراء (${product.unitName})'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: sellCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(labelText: 'سعر بيع (${product.unitName})'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_store.suppliers.isNotEmpty) ...[
                  DropdownButtonFormField<String>(
                    value: selectedSupId,
                    decoration: const InputDecoration(labelText: 'شركة التوريد / المندوب'),
                    items: _store.suppliers
                        .map((s) => DropdownMenuItem(value: s.id, child: Text(s.companyName)))
                        .toList(),
                    onChanged: (val) => setDialogState(() => selectedSupId = val),
                  ),
                  const SizedBox(height: 10),
                ],
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('دفع قيمة التوريد كاش فوراً من درج الكاشير'),
                  subtitle: Text(payCash
                      ? 'سيتم خصم المبلغ من الدرج'
                      : 'سيتم تسجيل المبلغ دين على المحل للمورد'),
                  value: payCash,
                  activeColor: AppColors.primary,
                  onChanged: (v) => setDialogState(() => payCash = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: () {
                final qty = double.tryParse(qtyCtrl.text.trim()) ?? 0.0;
                final buy = double.tryParse(buyCtrl.text.trim()) ?? product.buyPrice;
                final sell = double.tryParse(sellCtrl.text.trim()) ?? product.sellPrice;
                if (qty > 0) {
                  _store.restockProduct(
                    productId: product.id,
                    addedQuantity: qty,
                    newBuyPrice: buy,
                    newSellPrice: sell,
                    supplierId: selectedSupId,
                    isPaidFromDrawer: payCash,
                  );
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ تم توريد البضاعة وتحديث رصيد المخزن بنجاح'),
                      backgroundColor: AppColors.receiveGreen,
                    ),
                  );
                }
              },
              child: const Text('تأكيد الاستلام والتوريد'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddProductDialog([ProductModel? existing]) {
    final barcodeCtrl = TextEditingController(text: existing?.barcode ?? '');
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final catCtrl = TextEditingController(text: existing?.category ?? 'ألبان وجبن');
    final buyCtrl = TextEditingController(text: existing?.buyPrice.toString() ?? '');
    final sellCtrl = TextEditingController(text: existing?.sellPrice.toString() ?? '');
    final stockCtrl = TextEditingController(text: existing?.stockQuantity.toString() ?? '');
    final minStockCtrl = TextEditingController(text: existing?.minStockAlert.toString() ?? '5');

    String unitName = existing?.unitName ?? 'قطعة';
    final List<String> unitOptions = ['قطعة', 'علبة', 'كيس', 'إزازة', 'برطمان', 'كجم'];

    bool hasBulk = existing?.hasCarton ?? false;
    String bulkUnitName = existing?.bulkUnitName ?? 'شكارة';
    final List<String> bulkUnitOptions = ['شكارة', 'باليتة', 'كرتونة', 'باكت', 'دستة', 'صندوق'];
    final bulkUnitsCountCtrl = TextEditingController(text: existing != null && existing.hasCarton ? existing.cartonUnitsCount.toString() : '24');
    final bulkSellPriceCtrl = TextEditingController(text: existing != null && existing.hasCarton ? existing.cartonSellPrice.toString() : '');
    final bulkBarcodeCtrl = TextEditingController(text: existing?.cartonBarcode ?? '');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final isWeighted = unitName == 'كجم';

          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Icon(existing == null ? Icons.add_box_rounded : Icons.edit_note, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(existing == null ? 'إضافة صنف وبضاعة جديدة' : 'تعديل بيانات الصنف'),
                ],
              ),
              content: SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: barcodeCtrl,
                              decoration: const InputDecoration(labelText: 'باركود الصنف (القطعة/العلبة)'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            tooltip: 'توليد كود تلقائي',
                            icon: const Icon(Icons.auto_fix_high, color: AppColors.primary),
                            onPressed: () {
                              final generated = '200${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}';
                              barcodeCtrl.text = generated;
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'اسم المنتج التجاري بالكامل')),
                      const SizedBox(height: 10),

                      Row(
                        children: [
                          Expanded(
                            flex: 5,
                            child: TextField(controller: catCtrl, decoration: const InputDecoration(labelText: 'القسم / التصنيف')),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 4,
                            child: DropdownButtonFormField<String>(
                              value: unitName,
                              decoration: const InputDecoration(labelText: 'نوع الوحدة'),
                              items: unitOptions.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                              onChanged: (val) {
                                if (val != null) setDialogState(() => unitName = val);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: buyCtrl,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(labelText: 'سعر الشراء / تكلفة الـ ($unitName)'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: sellCtrl,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(labelText: 'سعر البيع قطاعي للـ ($unitName)'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: stockCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(labelText: 'الرصيد الفعلي بالمخزن ($unitName)'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: minStockCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'حد تنبيه النواقص'),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),

                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('متاح بيع جملة بعبوة كبرى (شكارة / باليتة / كرتونة)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        value: hasBulk,
                        activeColor: AppColors.purpleAccent,
                        onChanged: (v) => setDialogState(() => hasBulk = v),
                      ),

                      if (hasBulk) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.purpleAccent.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.purpleAccent.withValues(alpha: 0.2)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    flex: 4,
                                    child: DropdownButtonFormField<String>(
                                      value: bulkUnitName,
                                      decoration: const InputDecoration(labelText: 'نوع العبوة الكبرى'),
                                      items: bulkUnitOptions.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
                                      onChanged: (val) {
                                        if (val != null) setDialogState(() => bulkUnitName = val);
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    flex: 5,
                                    child: TextField(
                                      controller: bulkUnitsCountCtrl,
                                      keyboardType: TextInputType.number,
                                      decoration: InputDecoration(labelText: 'المحتوى (كم $unitName بالـ $bulkUnitName؟)'),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: bulkSellPriceCtrl,
                                      keyboardType: TextInputType.number,
                                      decoration: InputDecoration(labelText: 'سعر بيع الـ $bulkUnitName للزبون'),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextField(
                                      controller: bulkBarcodeCtrl,
                                      decoration: InputDecoration(labelText: 'باركود الـ $bulkUnitName (اختياري)'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                  onPressed: () {
                    if (nameCtrl.text.isNotEmpty) {
                      final product = ProductModel(
                        id: existing?.id ?? 'p_${DateTime.now().millisecondsSinceEpoch}',
                        barcode: barcodeCtrl.text.trim().isEmpty
                            ? '200${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}'
                            : barcodeCtrl.text.trim(),
                        name: nameCtrl.text.trim(),
                        category: catCtrl.text.trim(),
                        buyPrice: double.tryParse(buyCtrl.text.trim()) ?? 0.0,
                        sellPrice: double.tryParse(sellCtrl.text.trim()) ?? 0.0,
                        stockQuantity: double.tryParse(stockCtrl.text.trim()) ?? 0.0,
                        minStockAlert: double.tryParse(minStockCtrl.text.trim()) ?? 5.0,
                        isWeighted: isWeighted,
                        unitName: unitName,
                        hasCarton: hasBulk,
                        bulkUnitName: bulkUnitName,
                        cartonUnitsCount: int.tryParse(bulkUnitsCountCtrl.text.trim()) ?? 1,
                        cartonSellPrice: double.tryParse(bulkSellPriceCtrl.text.trim()) ?? 0.0,
                        cartonBarcode: bulkBarcodeCtrl.text.trim().isNotEmpty ? bulkBarcodeCtrl.text.trim() : null,
                      );
                      _store.addOrUpdateProduct(product);
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('✅ تم حفظ الصنف (${product.name}) بنجاح'),
                          backgroundColor: AppColors.receiveGreen,
                        ),
                      );
                    }
                  },
                  child: const Text('حفظ الصنف'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('مخازن السوبر ماركت - جرد البضاعة والباركود'),
        actions: [
          IconButton(
            tooltip: 'تصدير كشف الجرد لملف Excel',
            onPressed: () async {
              final result = await _store.exportInventoryToCsv();
              if (context.mounted && result != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('📦 تم تصدير كشف جرد المخزن بنجاح إلى:\n$result'),
                    backgroundColor: AppColors.receiveGreen,
                  ),
                );
              }
            },
            icon: const Icon(Icons.download_for_offline_outlined),
          ),
          IconButton(
            tooltip: 'إضافة صنف جديد',
            onPressed: () => _showAddProductDialog(),
            icon: const Icon(Icons.add_box_rounded),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: _store,
        builder: (context, _) {
          final filtered = _store.products.where((p) {
            if (_filter == 'النواقص' && !p.isLowStock) return false;
            if (_searchQuery.isNotEmpty) {
              return p.name.contains(_searchQuery) || p.barcode.contains(_searchQuery);
            }
            return true;
          }).toList();

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.alertRed.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: AppColors.alertRed, size: 30),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('نواقص المخزن (تحتاج طلب)', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.alertRed)),
                                Text('${_store.lowStockCount} صنف', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.alertRed)),
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
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.inventory_2_rounded, color: AppColors.primary, size: 30),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('قيمة البضاعة بسعر الشراء', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryDark)),
                                Text('${_numFormat.format(_store.inventoryValue.toInt())} ج.م', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.primaryDark)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        onChanged: (v) => setState(() => _searchQuery = v),
                        decoration: const InputDecoration(hintText: 'بحث بالاسم أو الباركود...', prefixIcon: Icon(Icons.search)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ...['الكل', 'النواقص'].map((f) {
                      final sel = _filter == f;
                      return Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: ChoiceChip(
                          label: Text(f),
                          selected: sel,
                          onSelected: (_) => setState(() => _filter = f),
                        ),
                      );
                    }),
                  ],
                ),
                const SizedBox(height: 14),

                Expanded(
                  child: Card(
                    child: filtered.isEmpty
                        ? const Center(child: Text('لا توجد أصناف في المخزن'))
                        : ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, idx) {
                              final p = filtered[idx];
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: p.isLowStock ? AppColors.alertRed.withValues(alpha: 0.1) : AppColors.primary.withValues(alpha: 0.1),
                                  child: Icon(Icons.fastfood_rounded, color: p.isLowStock ? AppColors.alertRed : AppColors.primary),
                                ),
                                title: Row(
                                  children: [
                                    Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(6)),
                                      child: Text(p.barcode, style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                                      child: Text(p.unitName, style: const TextStyle(color: AppColors.primaryDark, fontSize: 10, fontWeight: FontWeight.bold)),
                                    ),
                                    if (p.hasCarton) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(color: AppColors.purpleAccent.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                                        child: Text(p.bulkUnitName, style: const TextStyle(color: AppColors.purpleAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                    if (p.isLowStock) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(color: AppColors.alertRed, borderRadius: BorderRadius.circular(6)),
                                        child: const Text('ناقص', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                  ],
                                ),
                                subtitle: Text(
                                  'شراء: ${p.buyPrice} ج | بيع: ${p.sellPrice} ج/${p.unitName}'
                                  '${p.hasCarton ? " | بيع ${p.bulkUnitName}: ${p.cartonSellPrice} ج" : ""}',
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        const Text('الرصيد', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                        Text(
                                          p.isWeighted ? '${p.stockQuantity.toStringAsFixed(2)} كجم' : '${p.stockQuantity.toInt()} ${p.unitName}',
                                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: p.isLowStock ? AppColors.alertRed : Colors.black87),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      tooltip: 'توريد واستلام بضاعة جديدة',
                                      icon: const Icon(Icons.add_shopping_cart, color: AppColors.transferBlue),
                                      onPressed: () => _showRestockDialog(p),
                                    ),
                                    IconButton(
                                      tooltip: 'طباعة باركود',
                                      icon: const Icon(Icons.qr_code, color: AppColors.primary),
                                      onPressed: () => showDialog(context: context, builder: (_) => BarcodeLabelDialog(product: p)),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, size: 20),
                                      onPressed: () => _showAddProductDialog(p),
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