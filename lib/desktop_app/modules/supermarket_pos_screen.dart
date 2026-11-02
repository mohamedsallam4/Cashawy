import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../core/theme/app_theme.dart';
import '../../core/database/cashawy_store.dart';
import '../../models/product_model.dart';
import '../widgets/receipt_dialog.dart';

class SupermarketPosScreen extends StatefulWidget {
  const SupermarketPosScreen({super.key});

  @override
  State<SupermarketPosScreen> createState() => _SupermarketPosScreenState();
}

class _SupermarketPosScreenState extends State<SupermarketPosScreen> {
  final CashawyStore _store = CashawyStore.instance;
  final NumberFormat _numFormat = NumberFormat('#,##0.00');

  final TextEditingController _barcodeInputController = TextEditingController();
  final FocusNode _barcodeFocusNode = FocusNode();
  final FocusNode _keyboardListenerFocusNode = FocusNode();

  String _selectedCategory = 'الكل';
  String _productSearchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _barcodeFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _barcodeInputController.dispose();
    _barcodeFocusNode.dispose();
    _keyboardListenerFocusNode.dispose();
    super.dispose();
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.f1) {
        _barcodeFocusNode.requestFocus();
      } else if (event.logicalKey == LogicalKeyboardKey.f2) {
        _showCheckoutDialog();
      } else if (event.logicalKey == LogicalKeyboardKey.f4) {
        if (_store.activeCart.isNotEmpty) {
          _confirmClearCart();
        }
      }
    }
  }

  void _confirmClearCart() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد مسح الفاتورة (F4)'),
        content: const Text('هل تريد تفريغ كل المنتجات من السلة الحالية؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('تراجع'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.alertRed,
            ),
            onPressed: () {
              _store.clearCart();
              Navigator.pop(ctx);
              _barcodeFocusNode.requestFocus();
            },
            child: const Text('مسح السلة'),
          ),
        ],
      ),
    );
  }

  void _showWeightInputDialog(ProductModel product) {
    final weightCtrl = TextEditingController(text: '0.250');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('وزن الصنف: ${product.name} ⚖️'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'سعر الكيلو: ${product.sellPrice} ج.م',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.primaryDark,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: weightCtrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'الوزن بالكيلوجرام (مثال: 0.350 = 350 جرام)',
                prefixIcon: Icon(Icons.scale),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () {
              final w = double.tryParse(weightCtrl.text.trim()) ?? 0.0;
              if (w > 0) {
                _store.addProductToCartByBarcodeOrId(
                  product.id,
                  customWeight: w,
                );
                Navigator.pop(ctx);
                _barcodeFocusNode.requestFocus();
              }
            },
            child: const Text('إضافة للسلة'),
          ),
        ],
      ),
    );
  }

  void _onBarcodeSubmitted(String barcode) {
    if (barcode.trim().isEmpty) return;

    final success = _store.addProductToCartByBarcodeOrId(barcode.trim());
    if (success) {
      _barcodeInputController.clear();
      _barcodeFocusNode.requestFocus();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '⚠️ لم يتم العثور على صنف بالباركود: $barcode أو الكمية غير كافية!',
          ),
          backgroundColor: AppColors.alertRed,
          duration: const Duration(seconds: 2),
        ),
      );
      _barcodeInputController.clear();
      _barcodeFocusNode.requestFocus();
    }
  }

  void _showCheckoutDialog() {
    if (_store.activeCart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('السلة فارغة! أضف أصنافاً أولاً.')),
      );
      return;
    }

    String paymentMethod = 'cash';
    final clientPhoneCtrl = TextEditingController();
    final clientNameCtrl = TextEditingController();
    final discountCtrl = TextEditingController(text: '0');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final discount = double.tryParse(discountCtrl.text) ?? 0.0;
          final totalAfterDiscount = (_store.cartTotal - discount).clamp(
            0.0,
            double.infinity,
          );

          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.receipt_long, color: AppColors.primary),
                const SizedBox(width: 8),
                Text('إتمام الفاتورة (${_store.activeCart.length} بند)'),
              ],
            ),
            content: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'المبلغ المطلوب سداده',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_numFormat.format(totalAfterDiscount)} ج.م',
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: AppColors.primaryDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    const Text(
                      'طريقة الدفع:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text('نقدي 💵')),
                            selected: paymentMethod == 'cash',
                            selectedColor: AppColors.primary.withValues(
                              alpha: 0.2,
                            ),
                            onSelected: (_) =>
                                setDialogState(() => paymentMethod = 'cash'),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text('كاش 📱')),
                            selected: paymentMethod == 'wallet',
                            selectedColor: AppColors.transferBlue.withValues(
                              alpha: 0.2,
                            ),
                            onSelected: (_) =>
                                setDialogState(() => paymentMethod = 'wallet'),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text('آجل / شكك 📒')),
                            selected: paymentMethod == 'debt',
                            selectedColor: AppColors.alertRed.withValues(
                              alpha: 0.2,
                            ),
                            onSelected: (_) =>
                                setDialogState(() => paymentMethod = 'debt'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    if (paymentMethod == 'debt' ||
                        paymentMethod == 'wallet') ...[
                      TextField(
                        controller: clientPhoneCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: paymentMethod == 'debt'
                              ? 'رقم هاتف العميل (إجباري للشكك)'
                              : 'رقم محفظة العميل',
                          prefixIcon: const Icon(Icons.phone),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: clientNameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'اسم العميل (اختياري)',
                          prefixIcon: Icon(Icons.person),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],

                    TextField(
                      controller: discountCtrl,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setDialogState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'خصم خاص على الفاتورة (ج.م)',
                        prefixIcon: Icon(Icons.discount_outlined),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('رجوع (Esc)'),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                ),
                onPressed: () {
                  if (paymentMethod == 'debt' &&
                      clientPhoneCtrl.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'يجب إدخال رقم هاتف العميل لتسجيل الآجل في الدفتر!',
                        ),
                        backgroundColor: AppColors.alertRed,
                      ),
                    );
                    return;
                  }

                  final invoiceItems = List<CartItemModel>.from(
                    _store.activeCart,
                  );
                  final invNumber =
                      'INV-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

                  final result = _store.checkoutSupermarketCart(
                    paymentMethod: paymentMethod,
                    customerPhone: clientPhoneCtrl.text.trim(),
                    customerName: clientNameCtrl.text.trim().isNotEmpty
                        ? clientNameCtrl.text.trim()
                        : null,
                    discount: discount,
                  );

                  if (!result.success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(result.error ?? 'تعذر إتمام الفاتورة'),
                        backgroundColor: AppColors.alertRed,
                      ),
                    );
                    return;
                  }

                  Navigator.pop(ctx);
                  _barcodeFocusNode.requestFocus();

                  showDialog(
                    context: context,
                    builder: (_) => ReceiptDialog(
                      invoiceNumber: invNumber,
                      items: invoiceItems,
                      totalAmount: totalAfterDiscount,
                      discount: discount,
                      paymentMethod: paymentMethod,
                      customerName: clientNameCtrl.text.trim().isNotEmpty
                          ? clientNameCtrl.text.trim()
                          : null,
                      customerPhone: clientPhoneCtrl.text.trim().isNotEmpty
                          ? clientPhoneCtrl.text.trim()
                          : null,
                    ),
                  );
                },
                icon: const Icon(Icons.check_circle),
                label: const Text('تأكيد وحفظ الفاتورة'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: _keyboardListenerFocusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.point_of_sale, color: Colors.white),
              const SizedBox(width: 8),
              Text(_store.marketName),
            ],
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Row(
                children: [
                  _buildShortcutBadge('F1', 'الباركود'),
                  const SizedBox(width: 6),
                  _buildShortcutBadge('F2', 'دفع'),
                  const SizedBox(width: 6),
                  _buildShortcutBadge('F4', 'مسح'),
                ],
              ),
            ),
            IconButton(
              tooltip: 'مسح السلة بالكامل (F4)',
              onPressed: _store.activeCart.isEmpty ? null : _confirmClearCart,
              icon: const Icon(Icons.delete_sweep_outlined),
            ),
          ],
        ),
        body: ListenableBuilder(
          listenable: _store,
          builder: (context, _) {
            final allCategories = [
              'الكل',
              ..._store.products.map((p) => p.category).toSet(),
            ];

            final visibleProducts = _store.products.where((p) {
              if (_selectedCategory != 'الكل' &&
                  p.category != _selectedCategory)
                return false;
              if (_productSearchQuery.isNotEmpty) {
                return p.name.contains(_productSearchQuery) ||
                    p.barcode.contains(_productSearchQuery);
              }
              return true;
            }).toList();

            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // اليمين: شبكة الأصناف
                Expanded(
                  flex: 6,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      children: [
                        TextField(
                          onChanged: (val) =>
                              setState(() => _productSearchQuery = val),
                          decoration: const InputDecoration(
                            hintText: 'ابحث عن صنف بالاسم أو الباركود...',
                            prefixIcon: Icon(Icons.search),
                          ),
                        ),
                        const SizedBox(height: 10),

                        SizedBox(
                          height: 38,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: allCategories.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 8),
                            itemBuilder: (context, idx) {
                              final cat = allCategories[idx];
                              final isSel = _selectedCategory == cat;
                              return ChoiceChip(
                                label: Text(cat),
                                selected: isSel,
                                selectedColor: AppColors.primary,
                                labelStyle: TextStyle(
                                  color: isSel ? Colors.white : Colors.black87,
                                  fontWeight: FontWeight.bold,
                                ),
                                onSelected: (_) =>
                                    setState(() => _selectedCategory = cat),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 12),

                        Expanded(
                          child: visibleProducts.isEmpty
                              ? const Center(
                                  child: Text('لا توجد أصناف مطابقة'),
                                )
                              : GridView.builder(
                                  gridDelegate:
                                      const SliverGridDelegateWithMaxCrossAxisExtent(
                                        maxCrossAxisExtent: 180,
                                        mainAxisSpacing: 10,
                                        crossAxisSpacing: 10,
                                        childAspectRatio: 0.95,
                                      ),
                                  itemCount: visibleProducts.length,
                                  itemBuilder: (context, idx) {
                                    final product = visibleProducts[idx];
                                    final isOutOfStock =
                                        product.stockQuantity <= 0;

                                    return InkWell(
                                      onTap: isOutOfStock
                                          ? null
                                          : () {
                                              if (product.isWeighted) {
                                                _showWeightInputDialog(product);
                                              } else {
                                                _store
                                                    .addProductToCartByBarcodeOrId(
                                                      product.id,
                                                    );
                                                _barcodeFocusNode
                                                    .requestFocus();
                                              }
                                            },
                                      borderRadius: BorderRadius.circular(12),
                                      child: Card(
                                        color: isOutOfStock
                                            ? Colors.grey.shade100
                                            : Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          side: BorderSide(
                                            color: product.isLowStock
                                                ? AppColors.alertRed.withValues(
                                                    alpha: 0.5,
                                                  )
                                                : Colors.grey.shade200,
                                          ),
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.all(10),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceBetween,
                                                    children: [
                                                      Expanded(
                                                        child: Text(
                                                          product.name,
                                                          maxLines: 2,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          style: TextStyle(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 13,
                                                            color: isOutOfStock
                                                                ? Colors.grey
                                                                : Colors
                                                                      .black87,
                                                          ),
                                                        ),
                                                      ),
                                                      if (product.isWeighted)
                                                        const Icon(
                                                          Icons.scale,
                                                          size: 16,
                                                          color:
                                                              AppColors.primary,
                                                        ),
                                                      if (product.hasCarton)
                                                        Container(
                                                          padding:
                                                              const EdgeInsets.symmetric(
                                                                horizontal: 4,
                                                                vertical: 1,
                                                              ),
                                                          decoration: BoxDecoration(
                                                            color: AppColors
                                                                .purpleAccent
                                                                .withValues(
                                                                  alpha: 0.15,
                                                                ),
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  4,
                                                                ),
                                                          ),
                                                          child: const Text(
                                                            'كرتونة',
                                                            style: TextStyle(
                                                              fontSize: 9,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              color: AppColors
                                                                  .purpleAccent,
                                                            ),
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    product.category,
                                                    style: const TextStyle(
                                                      fontSize: 10,
                                                      color: Colors.grey,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Text(
                                                    '${product.sellPrice.toInt()} ج${product.isWeighted ? "/ك" : ""}',
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w900,
                                                      fontSize: 15,
                                                      color:
                                                          AppColors.primaryDark,
                                                    ),
                                                  ),
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 6,
                                                          vertical: 2,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: isOutOfStock
                                                          ? AppColors.alertRed
                                                          : (product.isLowStock
                                                                ? Colors
                                                                      .orange
                                                                      .shade100
                                                                : Colors
                                                                      .grey
                                                                      .shade100),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            6,
                                                          ),
                                                    ),
                                                    child: Text(
                                                      isOutOfStock
                                                          ? 'نفد'
                                                          : (product.isWeighted
                                                                ? '${product.stockQuantity.toStringAsFixed(1)} ك'
                                                                : 'متبقي ${product.stockQuantity.toInt()}'),
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: isOutOfStock
                                                            ? Colors.white
                                                            : Colors.black87,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),

                // الشمال: الفاتورة السريعة
                Expanded(
                  flex: 4,
                  child: Card(
                    margin: const EdgeInsets.all(12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: _barcodeInputController,
                            focusNode: _barcodeFocusNode,
                            onSubmitted: _onBarcodeSubmitted,
                            decoration: InputDecoration(
                              labelText: 'اضرب باركود القطعة أو الكرتونة أو الميزان [F1]...',
                              prefixIcon: const Icon(
                                Icons.qr_code_scanner,
                                color: AppColors.primary,
                              ),
                              suffixIcon: IconButton(
                                icon: const Icon(
                                  Icons.add_circle,
                                  color: AppColors.primary,
                                ),
                                onPressed: () => _onBarcodeSubmitted(
                                  _barcodeInputController.text,
                                ),
                              ),
                            ),
                          ),
                          const Divider(height: 24),

                          Expanded(
                            child: _store.activeCart.isEmpty
                                ? const Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.shopping_cart_outlined,
                                          size: 48,
                                          color: Colors.grey,
                                        ),
                                        SizedBox(height: 8),
                                        Text(
                                          'الفاتورة فارغة حالياً\nامسح الباركود أو اضغط على الصنف',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(color: Colors.grey),
                                        ),
                                      ],
                                    ),
                                  )
                                : ListView.separated(
                                    itemCount: _store.activeCart.length,
                                    separatorBuilder: (_, __) =>
                                        const Divider(height: 1),
                                    itemBuilder: (context, idx) {
                                      final item = _store.activeCart[idx];
                                      return ListTile(
                                        dense: true,
                                        contentPadding: EdgeInsets.zero,
                                        title: Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                item.product.name,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ),
                                            if (item.product.hasCarton) ...[
                                              InkWell(
                                                onTap: () => _store
                                                    .toggleCartItemCartonMode(
                                                      item.product.id,
                                                    ),
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 2,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: item.isCarton
                                                        ? AppColors.purpleAccent
                                                        : Colors.grey.shade200,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          6,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    item.isCarton
                                                        ? 'كرتونة'
                                                        : 'قطعة',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: item.isCarton
                                                          ? Colors.white
                                                          : Colors.black87,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        subtitle: Text(
                                          '${item.unitPrice} ج.م × ${item.formattedQuantity}',
                                        ),
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: const Icon(
                                                Icons.remove_circle_outline,
                                                size: 18,
                                                color: AppColors.alertRed,
                                              ),
                                              onPressed: () =>
                                                  _store.changeCartItemQuantity(
                                                    item.product.id,
                                                    item.product.isWeighted
                                                        ? -0.1
                                                        : -1.0,
                                                  ),
                                            ),
                                            Text(
                                              item.product.isWeighted
                                                  ? item.quantity
                                                        .toStringAsFixed(3)
                                                  : '${item.quantity.toInt()}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                              ),
                                            ),
                                            IconButton(
                                              icon: const Icon(
                                                Icons.add_circle_outline,
                                                size: 18,
                                                color: AppColors.primary,
                                              ),
                                              onPressed: () =>
                                                  _store.changeCartItemQuantity(
                                                    item.product.id,
                                                    item.product.isWeighted
                                                        ? 0.1
                                                        : 1.0,
                                                  ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              '${item.subtotal.toStringAsFixed(1)} ج',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                          ),
                          const Divider(height: 20),

                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'البنود: ${_store.activeCart.length}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey,
                                  ),
                                ),
                                Text(
                                  'الإجمالي: ${_numFormat.format(_store.cartTotal)} ج.م',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.primaryDark,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),

                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                              ),
                              onPressed: _showCheckoutDialog,
                              icon: const Icon(Icons.payments_outlined),
                              label: const Text(
                                'دفع وإنهاء الفاتورة [F2]',
                                style: TextStyle(fontSize: 16),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildShortcutBadge(String keyText, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              keyText,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
