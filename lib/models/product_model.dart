class ProductModel {
  final String id;
  final String barcode;        // باركود القطعة / المفرد
  String name;                 // اسم الصنف
  String category;             // القسم
  double buyPrice;             // سعر شراء الوحدة الصغرى (تكلفة)
  double sellPrice;            // سعر بيع الوحدة الصغرى (قطاعي)
  double stockQuantity;        // الرصيد الإجمالي المتوفر
  double minStockAlert;        // حد النواقص
  bool isWeighted;             // هل يباع بالوزن والميزان؟

  // نوع وحدة البيع الصغرى
  String unitName;             // قطعة، علبة، كيس، إزازة، برطمان، كجم

  // نظام العبوة الكبرى / الجملة (الشكارة / الباليتة / الكرتونة)
  bool hasCarton;              // متاح للبيع كعبوة كبرى
  String bulkUnitName;         // شكارة، باليتة، كرتونة، باكت، صندوق
  String? cartonBarcode;       // باركود العبوة الكبرى
  int cartonUnitsCount;        // عدد الوحدات بداخلها
  double cartonSellPrice;      // سعر بيع الشكارة أو الباليتة للزبون

  ProductModel({
    required this.id,
    required this.barcode,
    required this.name,
    required this.category,
    required this.buyPrice,
    required this.sellPrice,
    required this.stockQuantity,
    this.minStockAlert = 5.0,
    this.isWeighted = false,
    this.unitName = 'قطعة',
    this.hasCarton = false,
    this.bulkUnitName = 'كرتونة',
    this.cartonBarcode,
    this.cartonUnitsCount = 1,
    this.cartonSellPrice = 0.0,
  });

  bool get isLowStock => stockQuantity <= minStockAlert;

  double get unitProfit => (sellPrice - buyPrice).clamp(0.0, double.infinity);

  double get cartonProfit =>
      (cartonSellPrice - (buyPrice * cartonUnitsCount)).clamp(0.0, double.infinity);

  Map<String, dynamic> toJson() => {
        'id': id,
        'barcode': barcode,
        'name': name,
        'category': category,
        'buyPrice': buyPrice,
        'sellPrice': sellPrice,
        'stockQuantity': stockQuantity,
        'minStockAlert': minStockAlert,
        'isWeighted': isWeighted,
        'unitName': unitName,
        'hasCarton': hasCarton,
        'bulkUnitName': bulkUnitName,
        'cartonBarcode': cartonBarcode,
        'cartonUnitsCount': cartonUnitsCount,
        'cartonSellPrice': cartonSellPrice,
      };

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: json['id'] ?? '',
      barcode: json['barcode'] ?? '',
      name: json['name'] ?? '',
      category: json['category'] ?? 'عام',
      buyPrice: (json['buyPrice'] ?? 0.0).toDouble(),
      sellPrice: (json['sellPrice'] ?? 0.0).toDouble(),
      stockQuantity: (json['stockQuantity'] ?? 0.0).toDouble(),
      minStockAlert: (json['minStockAlert'] ?? 5.0).toDouble(),
      isWeighted: json['isWeighted'] ?? false,
      unitName: json['unitName'] ?? (json['isWeighted'] == true ? 'كجم' : 'قطعة'),
      hasCarton: json['hasCarton'] ?? false,
      bulkUnitName: json['bulkUnitName'] ?? 'كرتونة',
      cartonBarcode: json['cartonBarcode'],
      cartonUnitsCount: (json['cartonUnitsCount'] ?? 1).toInt(),
      cartonSellPrice: (json['cartonSellPrice'] ?? 0.0).toDouble(),
    );
  }
}

class CartItemModel {
  final ProductModel product;
  double quantity;
  bool isCarton;

  CartItemModel({
    required this.product,
    this.quantity = 1.0,
    this.isCarton = false,
  });

  double get unitPrice => isCarton ? product.cartonSellPrice : product.sellPrice;
  double get subtotal => unitPrice * quantity;
  double get totalProfit =>
      (isCarton ? product.cartonProfit : product.unitProfit) * quantity;

  double get totalDeductedPieces =>
      isCarton ? (quantity * product.cartonUnitsCount) : quantity;

  String get formattedQuantity {
    if (isCarton) {
      return '${quantity.toInt()} ${product.bulkUnitName} (${product.cartonUnitsCount} ${product.unitName})';
    }
    return product.isWeighted
        ? '${quantity.toStringAsFixed(3)} كجم'
        : '${quantity.toInt()} ${product.unitName}';
  }
}

class SupplierModel {
  final String id;
  final String companyName;
  final String phone;
  double balanceOwed;

  SupplierModel({
    required this.id,
    required this.companyName,
    required this.phone,
    this.balanceOwed = 0.0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'companyName': companyName,
        'phone': phone,
        'balanceOwed': balanceOwed,
      };

  factory SupplierModel.fromJson(Map<String, dynamic> json) {
    return SupplierModel(
      id: json['id'] ?? '',
      companyName: json['companyName'] ?? '',
      phone: json['phone'] ?? '',
      balanceOwed: (json['balanceOwed'] ?? 0.0).toDouble(),
    );
  }
}