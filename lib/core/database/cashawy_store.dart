import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/wallet_model.dart';
import '../../models/transaction_model.dart';
import '../../models/product_model.dart';
import '../theme/parsers/cash_sms_parser.dart';
import '../services/audio_feedback_service.dart';
import '../services/wallet_limit_service.dart';
import 'platform_storage.dart';
import '../services/cloud_sync_service.dart';
import 'database_helper.dart';

/// نتيجة محاولة تسجيل معاملة مالية.
class TransactionRecordResult {
  final bool success;
  final String? error;
  final TransactionModel? transaction;

  const TransactionRecordResult._({
    required this.success,
    this.error,
    this.transaction,
  });

  factory TransactionRecordResult.success(TransactionModel transaction) =>
      TransactionRecordResult._(success: true, transaction: transaction);

  factory TransactionRecordResult.failure(String error) =>
      TransactionRecordResult._(success: false, error: error);
}

class CashawyStore extends ChangeNotifier {
  static final CashawyStore instance = CashawyStore._internal();
  CashawyStore._internal() {
    _initDatabase();
  }

  // ==================== محرك ومعرف السحابة Firestore ====================
  static const String _cloudStoreId = 'supermarket_main_branch';
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ==================== 1. إعدادات الترخيص والهوية والأمان المشفر ====================
  String marketName = 'سوبر ماركت الأمانة';
  String marketPhone = '01000000000';
  String marketAddress = 'الفرع الرئيسي';
  String licenseKey = 'CSH-PRO-2026-LIVE';
  String activeCashier = 'كاشير 1';
  bool isDarkMode = false;

  // تشفير وتجزئة رقم الأدمن السري برمجياً (تجزئة "1234" الافتراضية)
  String adminPinHash = _hashPin('1234');
  bool isCashierLocked = false;
  String receiptFooterMessage = 'شكراً لزيارتكم! نتشرف بخدمتكم دائماً 🙏';
  String returnPolicyNote =
      'البضاعة المباعة ترد وتستبدل خلال 14 يوماً مع إحضار أصل الفاتورة';
  String taxAndCommercialReg = 'س.ت: 10492 | ب.ض: 582-901';

  // رادار إطلاق التنبيه المنبثق الفوري (HUD Toast)
  final ValueNotifier<TransactionModel?> liveTransactionAlert = ValueNotifier(
    null,
  );

  /// دالة تجزئة وتشفير الرقم السري لحمايته من الاستخراج
  static String _hashPin(String pin) {
    final salted = 'cashawy_pos_salt_#2026_${pin.trim()}';
    final bytes = utf8.encode(salted);
    return base64UrlEncode(bytes);
  }

  void toggleThemeMode() {
    isDarkMode = !isDarkMode;
    _saveToDisk();
    notifyListeners();
  }

  void setCashierLock(bool locked) {
    isCashierLocked = locked;
    notifyListeners();
  }

  bool verifyAdminPin(String inputPin) {
    return _hashPin(inputPin.trim()) == adminPinHash;
  }

  void updateMarketLicense({
    required String name,
    required String phone,
    required String address,
    required String license,
    required String cashier,
    required String newAdminPin,
    required String footerMessage,
    required String policyNote,
    required String taxInfo,
  }) {
    marketName = name;
    marketPhone = phone;
    marketAddress = address;
    licenseKey = license;
    activeCashier = cashier;
    if (newAdminPin.trim().length >= 4) {
      adminPinHash = _hashPin(newAdminPin.trim());
    }
    receiptFooterMessage = footerMessage;
    returnPolicyNote = policyNote;
    taxAndCommercialReg = taxInfo;
    _saveToDisk();
    notifyListeners();
  }

  // ==================== 2. الخزينة والأرصدة الفعلية ====================
  double cashInDrawer = 0.0;
  double fawryBalance = 0.0;
  double amanBalance = 0.0;
  double todayExpenses = 0.0;
  double todayDamages = 0.0;

  List<WalletModel> wallets = [];
  List<TransactionModel> transactions = [];
  List<ProductModel> products = [];
  List<SupplierModel> suppliers = [];
  List<CartItemModel> activeCart = [];
  late WalletModel selectedWallet;

  double get inventoryValue =>
      products.fold(0.0, (sum, p) => sum + (p.buyPrice * p.stockQuantity));

  double get totalWalletsBalance =>
      wallets.fold(0.0, (sum, w) => sum + w.balance);

  double get totalCapital =>
      cashInDrawer +
      totalWalletsBalance +
      fawryBalance +
      amanBalance +
      inventoryValue;

  int get lowStockCount => products.where((p) => p.isLowStock).length;
  int get openDebtsCount =>
      transactions.where((t) => t.status == TransactionStatus.debt).length;

  int? get pendingMaintenanceCount => null;

  // ==================== 3. التهيئة والبيانات الافتراضية ====================
  Future<void> _initDatabase() async {
    _seedDefaultData();
    await _loadFromDisk();
    refreshWalletLimits();
  }

  void _seedDefaultData() {
    wallets = [
      WalletModel(
        id: 'w1',
        phoneNumber: '01000000000',
        title: 'محفظة كاش 1',
        provider: WalletProvider.vodafone,
        simSlot: 0,
        balance: 0.0,
      ),
    ];
    selectedWallet = wallets.first;

    products = [
      ProductModel(
        id: 'p1',
        barcode: '6221001',
        name: 'حليب كامل الدسم 1 لتر',
        category: 'ألبان وجبن',
        buyPrice: 38.0,
        sellPrice: 44.0,
        stockQuantity: 20.0,
        minStockAlert: 5.0,
        isWeighted: false,
        unitName: 'علبة',
      ),
      ProductModel(
        id: 'p2',
        barcode: '6221002',
        name: 'مكرونة 400 جرام',
        category: 'بقالة جافة',
        buyPrice: 10.0,
        sellPrice: 13.0,
        stockQuantity: 30.0,
        minStockAlert: 10.0,
        isWeighted: false,
        unitName: 'كيس',
      ),
      ProductModel(
        id: 'p3',
        barcode: '6221003',
        name: 'زبادي طبيعي 105 جم',
        category: 'ألبان وجبن',
        buyPrice: 6.0,
        sellPrice: 8.0,
        stockQuantity: 15.0,
        minStockAlert: 5.0,
        isWeighted: false,
        unitName: 'علبة',
      ),
      ProductModel(
        id: 'p5',
        barcode: '6221005',
        name: 'بيبسي كانز 330 مل',
        category: 'مشروبات غازية',
        buyPrice: 12.0,
        sellPrice: 15.0,
        stockQuantity: 120.0,
        minStockAlert: 12.0,
        hasCarton: true,
        unitName: 'علبة',
        bulkUnitName: 'كرتونة',
        cartonBarcode: '622100599',
        cartonUnitsCount: 24,
        cartonSellPrice: 330.0,
      ),
      ProductModel(
        id: 'p_weight_1',
        barcode: '00105',
        name: 'جبن رومي مصري قديم',
        category: 'أجبان وميزان',
        buyPrice: 280.0,
        sellPrice: 340.0,
        stockQuantity: 15.5,
        minStockAlert: 3.0,
        isWeighted: true,
        unitName: 'كجم',
      ),
      ProductModel(
        id: 'p_weight_2',
        barcode: '00106',
        name: 'لانشون حلواني سادة',
        category: 'أجبان وميزان',
        buyPrice: 180.0,
        sellPrice: 220.0,
        stockQuantity: 10.0,
        minStockAlert: 2.0,
        isWeighted: true,
        unitName: 'كجم',
      ),
    ];

    suppliers = [
      SupplierModel(
        id: 's1',
        companyName: 'شركة التوزيع الغذائي',
        phone: '01100000000',
        balanceOwed: 0.0,
      ),
    ];
  }

  /// تصفير العمليات التجريبية ومسحها من السحابة وبدء الوردية بالأرصدة الحقيقية
  Future<void> resetToRealStore({
    required double initialCash,
    required double initialFawry,
    required double initialAman,
    required String walletPhone,
    required double walletBalance,
    required bool clearProducts,
  }) async {
    cashInDrawer = initialCash;
    fawryBalance = initialFawry;
    amanBalance = initialAman;

    final realWallet = WalletModel(
      id: 'w_main',
      phoneNumber: walletPhone,
      title: 'محفظة الكاش الرئيسية (فودافون كاش)',
      provider: WalletProvider.vodafone,
      simSlot: 0,
      balance: walletBalance,
      dailyTransferLimit: 60000.0,
      monthlyTransferLimit: 200000.0,
      dailyReceiveLimit: 100000.0,
      monthlyReceiveLimit: 200000.0,
    );

    wallets = [realWallet];
    selectedWallet = realWallet;
    transactions.clear();
    liveTransactionAlert.value = null;

    if (clearProducts) {
      products.clear();
    }

    _recalculateWalletUsage();
    _saveToDisk();
    notifyListeners();

    try {
      final txCollection = _firestore
          .collection('stores')
          .doc(_cloudStoreId)
          .collection('live_transactions');

      final oldDocs = await txCollection.get();
      final batch = _firestore.batch();
      for (final doc in oldDocs.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      await syncStoreStateToCloud();
      debugPrint(
        '🧹 [Store Reset] Purged cloud transactions & synced real balances.',
      );
    } catch (e) {
      debugPrint('⚠️ [Store Reset Error] $e');
    }
  }

  // ==================== 4. كاشير السوبر ماركت والباركود والعمليات ====================
  double get cartTotal =>
      activeCart.fold(0.0, (sum, item) => sum + item.subtotal);
  double get cartProfit =>
      activeCart.fold(0.0, (sum, item) => sum + item.totalProfit);
  int get cartItemsCount => activeCart.length;

  bool addProductToCartByBarcodeOrId(
    String query, {
    double customWeight = 0.0,
    bool forceCarton = false,
  }) {
    final clean = query.trim();
    if (clean.isEmpty) return false;

    ProductModel? targetProduct;
    double addQuantity = customWeight > 0 ? customWeight : 1.0;
    bool isCartonScanned = forceCarton;

    final isScaleBarcode =
        (clean.startsWith('20') || clean.startsWith('21')) &&
        clean.length == 13;

    if (isScaleBarcode) {
      final itemCode = clean.substring(2, 7);
      final weightRaw = double.tryParse(clean.substring(7, 12)) ?? 0.0;
      final parsedWeight = weightRaw / 1000.0;

      targetProduct = products.firstWhere(
        (p) => p.barcode == itemCode || p.barcode == clean || p.id == itemCode,
        orElse: () => products.firstWhere(
          (p) => p.name.contains(itemCode),
          orElse: () => ProductModel(
            id: '',
            barcode: '',
            name: '',
            category: '',
            buyPrice: 0,
            sellPrice: 0,
            stockQuantity: 0,
          ),
        ),
      );

      if (targetProduct.id.isNotEmpty && parsedWeight > 0) {
        addQuantity = parsedWeight;
      } else {
        targetProduct = null;
      }
    }

    if (targetProduct == null) {
      final cartonIndex = products.indexWhere((p) => p.cartonBarcode == clean);
      if (cartonIndex != -1) {
        targetProduct = products[cartonIndex];
        isCartonScanned = true;
      }
    }

    if (targetProduct == null) {
      final pIndex = products.indexWhere(
        (p) =>
            p.barcode == clean ||
            p.id == clean ||
            p.name.toLowerCase() == clean.toLowerCase(),
      );
      if (pIndex != -1) {
        targetProduct = products[pIndex];
      }
    }

    if (targetProduct == null || targetProduct.id.isEmpty) {
      AudioFeedbackService.playErrorBuzz();
      return false;
    }

    final requiredPieces = isCartonScanned
        ? (addQuantity * targetProduct.cartonUnitsCount)
        : addQuantity;
    if (targetProduct.stockQuantity < requiredPieces) {
      AudioFeedbackService.playErrorBuzz();
      return false;
    }

    final existingIndex = activeCart.indexWhere(
      (c) => c.product.id == targetProduct!.id && c.isCarton == isCartonScanned,
    );

    if (existingIndex != -1) {
      activeCart[existingIndex].quantity += addQuantity;
    } else {
      activeCart.add(
        CartItemModel(
          product: targetProduct,
          quantity: addQuantity,
          isCarton: isCartonScanned,
        ),
      );
    }

    AudioFeedbackService.playScanBeep();
    notifyListeners();
    return true;
  }

  void toggleCartItemCartonMode(String productId) {
    final index = activeCart.indexWhere((c) => c.product.id == productId);
    if (index == -1) return;

    final item = activeCart[index];
    if (!item.product.hasCarton) return;

    item.isCarton = !item.isCarton;
    AudioFeedbackService.playScanBeep();
    notifyListeners();
  }

  void changeCartItemQuantity(String productId, double delta) {
    final index = activeCart.indexWhere((c) => c.product.id == productId);
    if (index == -1) return;

    final newQty = activeCart[index].quantity + delta;
    if (newQty <= 0.01) {
      activeCart.removeAt(index);
    } else {
      activeCart[index].quantity = newQty;
    }
    notifyListeners();
  }

  void clearCart() {
    activeCart.clear();
    notifyListeners();
  }

  TransactionRecordResult checkoutSupermarketCart({
    required String paymentMethod,
    String? customerPhone,
    String? customerName,
    double discount = 0.0,
  }) {
    if (activeCart.isEmpty) {
      return TransactionRecordResult.failure('لا توجد أصناف في الفاتورة');
    }

    final finalTotal = (cartTotal - discount).clamp(0.0, double.infinity);
    final finalProfit = (cartProfit - discount).clamp(0.0, double.infinity);

    // الدفع من المحفظة يستهلك ليميت الاستلام، لذلك نفحصه قبل خصم المخزون
    // وقبل حفظ أي أثر للفاتورة حتى لا نسجل عملية مرفوضة.
    if (paymentMethod == 'wallet') {
      final limitCheck = checkWalletLimit(
        type: TransactionType.receive,
        amount: finalTotal,
        checkBalance: false,
      );
      if (!limitCheck.allowed) {
        return TransactionRecordResult.failure(
          limitCheck.message ?? 'تم تجاوز حدود استلام المحفظة',
        );
      }
    }

    for (final item in activeCart) {
      item.product.stockQuantity =
          (item.product.stockQuantity - item.totalDeductedPieces).clamp(
            0.0,
            999999.0,
          );
    }

    final itemsSummary = activeCart
        .map((e) => '${e.product.name} (x${e.formattedQuantity})')
        .join('، ');

    if (paymentMethod == 'cash') {
      cashInDrawer += finalTotal;
    } else if (paymentMethod == 'wallet') {
      selectedWallet.balance += finalTotal;
    }

    final tx = TransactionModel(
      id: 'INV-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
      walletPhone: paymentMethod == 'wallet'
          ? selectedWallet.phoneNumber
          : 'كاشير السوبر ماركت',
      clientPhone: customerPhone?.isNotEmpty == true
          ? customerPhone!
          : 'عميل نقدي',
      clientName: customerName ?? itemsSummary,
      type: TransactionType.receive,
      amount: finalTotal,
      commission: finalProfit,
      status: paymentMethod == 'debt'
          ? TransactionStatus.debt
          : TransactionStatus.completed,
      notes: itemsSummary,
      createdAt: DateTime.now(),
    );

    transactions.insert(0, tx);

    activeCart.clear();
    AudioFeedbackService.playCheckoutSuccess();

    liveTransactionAlert.value = tx;
    CloudSyncService.syncTransaction(tx);
    _recalculateWalletUsage();
    syncStoreStateToCloud();

    _saveToDisk();
    notifyListeners();

    return TransactionRecordResult.success(tx);
  }

  // ==================== 5. توريد البضاعة، المرتجعات، التوالف والمصروفات ====================
  void restockProduct({
    required String productId,
    required double addedQuantity,
    required double newBuyPrice,
    required double newSellPrice,
    String? supplierId,
    bool isPaidFromDrawer = true,
  }) {
    final index = products.indexWhere((p) => p.id == productId);
    if (index != -1 && addedQuantity > 0) {
      products[index].stockQuantity += addedQuantity;
      products[index].buyPrice = newBuyPrice;
      products[index].sellPrice = newSellPrice;

      final totalCost = addedQuantity * newBuyPrice;

      if (isPaidFromDrawer) {
        cashInDrawer -= totalCost;
      } else if (supplierId != null) {
        final supIndex = suppliers.indexWhere((s) => s.id == supplierId);
        if (supIndex != -1) {
          suppliers[supIndex].balanceOwed += totalCost;
        }
      }

      transactions.insert(
        0,
        TransactionModel(
          id: 'BUY-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
          walletPhone: 'شراء بضاعة للمخزن',
          clientPhone: products[index].name,
          clientName: 'توريد $addedQuantity ${products[index].unitName}',
          type: TransactionType.transfer,
          amount: totalCost,
          commission: 0,
          status: TransactionStatus.completed,
          notes: 'شراء بسعر $newBuyPrice ج للوحدة',
          createdAt: DateTime.now(),
        ),
      );

      _saveToDisk();
      syncStoreStateToCloud();
      notifyListeners();
    }
  }

  bool recordDamagedProduct({
    required String barcodeOrId,
    required double quantity,
    required String reason,
  }) {
    if (quantity <= 0) return false;
    final pIndex = products.indexWhere(
      (p) => p.barcode == barcodeOrId || p.id == barcodeOrId,
    );
    if (pIndex == -1) return false;

    final product = products[pIndex];
    if (product.stockQuantity < quantity) return false;

    product.stockQuantity -= quantity;

    final totalCostLoss = quantity * product.buyPrice;
    todayDamages += totalCostLoss;

    transactions.insert(
      0,
      TransactionModel(
        id: 'DMG-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
        walletPhone: 'بضاعة تالفة وهالك',
        clientPhone: product.name,
        clientName: 'إتلاف $quantity ${product.unitName}',
        type: TransactionType.transfer,
        amount: totalCostLoss,
        commission: -totalCostLoss,
        status: TransactionStatus.completed,
        notes: 'السبب: $reason (تكلفة الخسارة: $totalCostLoss ج.م)',
        createdAt: DateTime.now(),
      ),
    );

    _saveToDisk();
    syncStoreStateToCloud();
    notifyListeners();
    return true;
  }

  void recordExpense({required String title, required double amount}) {
    if (amount <= 0) return;
    cashInDrawer -= amount;
    todayExpenses += amount;

    final tx = TransactionModel(
      id: 'EXP-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
      walletPhone: 'مصروفات ونثريات',
      clientPhone: title,
      clientName: 'مصروف خارجي',
      type: TransactionType.transfer,
      amount: amount,
      commission: -amount,
      status: TransactionStatus.completed,
      notes: title,
      createdAt: DateTime.now(),
    );

    transactions.insert(0, tx);

    _firestore
        .collection('stores')
        .doc(_cloudStoreId)
        .collection('live_transactions')
        .doc(tx.id)
        .set({
          'id': tx.id,
          'amount': amount,
          'type': 'transfer',
          'walletPhone': 'مصروفات ونثريات',
          'clientPhone': 'مصروف درج',
          'notes': title,
          'status': 'completed',
          'timestamp': FieldValue.serverTimestamp(),
        });

    syncStoreStateToCloud();
    _saveToDisk();
    notifyListeners();
  }

  bool processReturn({
    required String barcodeOrId,
    required double returnQuantity,
    required double refundAmount,
    required String reason,
  }) {
    if (returnQuantity <= 0 || refundAmount <= 0) return false;

    final pIndex = products.indexWhere(
      (p) => p.barcode == barcodeOrId || p.id == barcodeOrId,
    );
    if (pIndex != -1) {
      products[pIndex].stockQuantity += returnQuantity;
    }

    cashInDrawer -= refundAmount;

    final productName = pIndex != -1 ? products[pIndex].name : 'صنف مرتجع';
    transactions.insert(
      0,
      TransactionModel(
        id: 'RET-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
        walletPhone: 'مرتجع مبيعات',
        clientPhone: barcodeOrId,
        clientName: '$productName (x$returnQuantity)',
        type: TransactionType.transfer,
        amount: refundAmount,
        commission: 0,
        status: TransactionStatus.completed,
        notes: 'سبب الإرجاع: $reason',
        createdAt: DateTime.now(),
      ),
    );

    _saveToDisk();
    syncStoreStateToCloud();
    notifyListeners();
    return true;
  }

  // ==================== 6. إدارة المنتجات والموردين ====================
  void addOrUpdateProduct(ProductModel product) {
    final index = products.indexWhere(
      (p) => p.id == product.id || p.barcode == product.barcode,
    );
    if (index != -1) {
      products[index] = product;
    } else {
      products.insert(0, product);
    }
    _saveToDisk();
    syncStoreStateToCloud();
    notifyListeners();
  }

  void deleteProduct(String productId) {
    products.removeWhere((p) => p.id == productId);
    _saveToDisk();
    syncStoreStateToCloud();
    notifyListeners();
  }

  void addSupplier(String companyName, String phone, double initialDebt) {
    suppliers.insert(
      0,
      SupplierModel(
        id: 'sup_${DateTime.now().millisecondsSinceEpoch}',
        companyName: companyName,
        phone: phone,
        balanceOwed: initialDebt,
      ),
    );
    _saveToDisk();
    notifyListeners();
  }

  void paySupplier(String supplierId, double paidAmount) {
    final index = suppliers.indexWhere((s) => s.id == supplierId);
    if (index != -1 && paidAmount > 0) {
      suppliers[index].balanceOwed = (suppliers[index].balanceOwed - paidAmount)
          .clamp(0.0, double.infinity);
      cashInDrawer -= paidAmount;
      _saveToDisk();
      syncStoreStateToCloud();
      notifyListeners();
    }
  }

  // ==================== 7. المحافظ وماكينات الدفع والديون ====================
  void selectWallet(WalletModel wallet) {
    selectedWallet = wallet;
    notifyListeners();
  }

  void addWallet(WalletModel wallet) {
    final duplicate = wallets.any(
      (w) =>
          w.id == wallet.id ||
          (w.phoneNumber.trim().isNotEmpty &&
              w.phoneNumber.trim() == wallet.phoneNumber.trim()),
    );
    if (duplicate) return;

    wallets.add(wallet);
    selectedWallet = wallet;
    _saveToDisk();
    syncStoreStateToCloud();
    notifyListeners();
  }

  void updateCashInDrawer(double newAmount) {
    cashInDrawer = newAmount;
    _saveToDisk();
    syncStoreStateToCloud();
    notifyListeners();
  }

  /// تحديث درج الكاشير من المزامنة السحابية بدون كسر تغليف ChangeNotifier.
  void applyCloudCashInDrawer(double newAmount) {
    if ((cashInDrawer - newAmount).abs() < 0.01) return;
    cashInDrawer = newAmount;
    _saveToDisk();
    notifyListeners();
  }

  /// فحص حدود المحفظة قبل تنفيذ أي عملية.
  WalletLimitCheck checkWalletLimit({
    required TransactionType type,
    required double amount,
    double networkFee = 0.0,
    TransactionStatus status = TransactionStatus.completed,
    WalletModel? wallet,
    bool checkBalance = true,
  }) {
    _recalculateWalletUsage();
    final target = wallet ?? selectedWallet;

    // العملية المعلقة أو الاستلام الآجل لم يُنفّذا على المحفظة بعد،
    // لذلك لا يستهلكان أي ليميت.
    if (status == TransactionStatus.pending ||
        (type == TransactionType.receive && status == TransactionStatus.debt)) {
      return WalletLimitCheck(
        allowed: true,
        maxAllowed: double.infinity,
        dailyRemaining: type == TransactionType.transfer
            ? target.dailyTransferRemaining
            : target.dailyReceiveRemaining,
        monthlyRemaining: type == TransactionType.transfer
            ? target.monthlyTransferRemaining
            : target.monthlyReceiveRemaining,
        balanceAvailable: target.balance,
      );
    }

    return WalletLimitService.check(
      wallet: target,
      usage: WalletUsageSnapshot(
        dailyTransfer: target.usedDailyTransfer,
        monthlyTransfer: target.usedMonthlyTransfer,
        dailyReceive: target.usedDailyReceive,
        monthlyReceive: target.usedMonthlyReceive,
      ),
      isTransfer: type == TransactionType.transfer,
      amount: amount,
      networkFee: networkFee,
      checkBalance: checkBalance,
    );
  }

  /// إعادة حساب المستهلك من الليميت من سجل المعاملات نفسه.
  ///
  /// هذا يجعل التصفير اليومي/الشهري تلقائياً، ويمنع انحراف العدّادات بعد
  /// تعديل أو حذف معاملة أو بعد المزامنة السحابية.
  bool _recalculateWalletUsage() {
    var changed = false;

    for (final wallet in wallets) {
      final usage = WalletLimitService.calculateUsage(
        wallet: wallet,
        transactions: transactions,
      );

      if ((wallet.usedDailyTransfer - usage.dailyTransfer).abs() > 0.001) {
        wallet.usedDailyTransfer = usage.dailyTransfer;
        changed = true;
      }
      if ((wallet.usedMonthlyTransfer - usage.monthlyTransfer).abs() > 0.001) {
        wallet.usedMonthlyTransfer = usage.monthlyTransfer;
        changed = true;
      }
      if ((wallet.usedDailyReceive - usage.dailyReceive).abs() > 0.001) {
        wallet.usedDailyReceive = usage.dailyReceive;
        changed = true;
      }
      if ((wallet.usedMonthlyReceive - usage.monthlyReceive).abs() > 0.001) {
        wallet.usedMonthlyReceive = usage.monthlyReceive;
        changed = true;
      }
    }

    return changed;
  }

  /// واجهة عامة تُستدعى دورياً لالتقاط تغيّر اليوم أو الشهر بدون إعادة تشغيل.
  void refreshWalletLimits() {
    final changed = _recalculateWalletUsage();
    if (changed) {
      _saveToDisk();
      notifyListeners();
    }
  }

  /// تعديل الحدود اليومية والشهرية لمحفظة.
  bool updateWalletLimits({
    required String walletId,
    required double dailyTransferLimit,
    required double monthlyTransferLimit,
    required double dailyReceiveLimit,
    required double monthlyReceiveLimit,
  }) {
    final index = wallets.indexWhere((w) => w.id == walletId);
    if (index == -1) return false;

    if (dailyTransferLimit <= 0 ||
        monthlyTransferLimit <= 0 ||
        dailyReceiveLimit <= 0 ||
        monthlyReceiveLimit <= 0) {
      return false;
    }

    wallets[index] = wallets[index].copyWith(
      dailyTransferLimit: dailyTransferLimit,
      monthlyTransferLimit: monthlyTransferLimit,
      dailyReceiveLimit: dailyReceiveLimit,
      monthlyReceiveLimit: monthlyReceiveLimit,
    );

    _saveToDisk();
    syncStoreStateToCloud();
    notifyListeners();
    return true;
  }

  TransactionRecordResult recordTransaction({
    required TransactionType type,
    required double amount,
    required String clientPhone,
    String? clientName,
    double commission = 0.0,
    double networkFee = 0.0,
    bool deductCommission = false,
    TransactionStatus status = TransactionStatus.completed,
    String? customRef,
    double? exactBalanceFromSms,
    String? notes,
    WalletModel? wallet,
    bool enforceLimits = true,
    bool checkWalletBalance = true,
  }) {
    if (amount <= 0) {
      return TransactionRecordResult.failure('المبلغ يجب أن يكون أكبر من صفر');
    }

    final targetWallet = wallet ?? selectedWallet;

    final txId =
        customRef ??
        'TX-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

    // منع احتساب نفس العملية مرتين (خصوصاً مع إعادة قراءة رسائل الـ SMS
    // أو وصول نفس المعاملة من السحابة). نتحقق من التكرار قبل فحص الحدود حتى
    // لا تفشل إعادة قراءة رسالة نُفّذت بالفعل بسبب حدود استُهلكت بعدها.
    final existingIndex = transactions.indexWhere((t) => t.id == txId);
    if (existingIndex != -1) {
      return TransactionRecordResult.success(transactions[existingIndex]);
    }

    if (enforceLimits) {
      final limitCheck = checkWalletLimit(
        type: type,
        amount: amount,
        networkFee: networkFee,
        status: status,
        wallet: targetWallet,
        // لو الرصيد جاء من رسالة SMS فالعملية نُفّذت بالفعل على الشبكة،
        // ولا يصح رفض تسجيلها بسبب رصيد محلي قديم.
        checkBalance: checkWalletBalance && exactBalanceFromSms == null,
      );

      if (!limitCheck.allowed) {
        return TransactionRecordResult.failure(
          limitCheck.message ?? 'تم تجاوز حدود المحفظة',
        );
      }
    }

    final tx = TransactionModel(
      id: txId,
      walletPhone: targetWallet.phoneNumber,
      clientPhone: clientPhone,
      clientName: clientName,
      type: type,
      amount: amount,
      commission: commission,
      networkFee: networkFee,
      deductCommission: deductCommission,
      status: status,
      notes: notes,
      createdAt: DateTime.now(),
    );

    transactions.insert(0, tx);

    if (status != TransactionStatus.pending) {
      if (type == TransactionType.transfer) {
        if (exactBalanceFromSms != null) {
          targetWallet.balance = exactBalanceFromSms;
        } else {
          targetWallet.balance -= (amount + networkFee);
        }

        if (status != TransactionStatus.debt) {
          cashInDrawer += (amount + commission);
        }
      } else if (type == TransactionType.receive) {
        if (status == TransactionStatus.debt) {
          // استلام آجل: المحل سلّم كاش للعميل ولم يصل تحويل بعد،
          // فلا تُضاف للمحفظة ولا تستهلك ليميت الاستلام.
          cashInDrawer -= (amount - commission);
        } else {
          if (exactBalanceFromSms != null) {
            targetWallet.balance = exactBalanceFromSms;
          } else {
            targetWallet.balance += amount;
          }
          cashInDrawer -= (amount - commission);
        }
      }
    }

    _recalculateWalletUsage();
    liveTransactionAlert.value = tx;
    CloudSyncService.syncTransaction(tx);
    syncStoreStateToCloud();
    _saveToDisk();
    notifyListeners();

    return TransactionRecordResult.success(tx);
  }

  /// اعتماد عملية مؤجلة (pending) وتطبيق أثرها المالي على المحفظة والدرج.
  ///
  /// العملية المؤجلة لا تُحسب عند تسجيلها، لذلك نعيد فحص الحدود والرصيد
  /// في لحظة الاعتماد، فقد تكون تغيّرت منذ إنشائها.
  TransactionRecordResult approvePendingTransaction(String transactionId) {
    final index = transactions.indexWhere((t) => t.id == transactionId);
    if (index == -1) {
      return TransactionRecordResult.failure('العملية غير موجودة');
    }

    final tx = transactions[index];
    if (tx.status != TransactionStatus.pending) {
      return TransactionRecordResult.failure('هذه العملية ليست مؤجلة');
    }

    final targetWallet = _firstWalletWhere(
      (w) => WalletLimitService.belongsToWallet(tx, w),
    );
    if (targetWallet == null) {
      return TransactionRecordResult.failure(
        'محفظة العملية (${tx.walletPhone}) غير موجودة أو تم حذفها',
      );
    }

    final limitCheck = checkWalletLimit(
      type: tx.type,
      amount: tx.amount,
      networkFee: tx.networkFee,
      status: TransactionStatus.completed,
      wallet: targetWallet,
      checkBalance: tx.type == TransactionType.transfer,
    );

    if (!limitCheck.allowed) {
      return TransactionRecordResult.failure(
        limitCheck.message ?? 'تعذر اعتماد العملية: تم تجاوز حدود المحفظة',
      );
    }

    final approved = tx.copyWith(
      status: TransactionStatus.completed,
      executedAt: DateTime.now(),
    );
    transactions[index] = approved;

    if (approved.type == TransactionType.transfer) {
      targetWallet.balance -= (approved.amount + approved.networkFee);
      cashInDrawer += (approved.amount + approved.commission);
    } else {
      targetWallet.balance += approved.amount;
      cashInDrawer -= (approved.amount - approved.commission);
    }

    _recalculateWalletUsage();
    liveTransactionAlert.value = approved;
    CloudSyncService.syncTransaction(approved);
    syncStoreStateToCloud();
    _saveToDisk();
    notifyListeners();

    return TransactionRecordResult.success(approved);
  }

  /// إلغاء عملية مؤجلة دون أي أثر مالي (تُنقل لسلة المحذوفات).
  TransactionRecordResult cancelPendingTransaction(String transactionId) {
    final index = transactions.indexWhere((t) => t.id == transactionId);
    if (index == -1) {
      return TransactionRecordResult.failure('العملية غير موجودة');
    }

    final tx = transactions[index];
    if (tx.status != TransactionStatus.pending) {
      return TransactionRecordResult.failure('هذه العملية ليست مؤجلة');
    }

    final cancelled = tx.copyWith(status: TransactionStatus.trash);
    transactions[index] = cancelled;

    CloudSyncService.deleteTransaction(cancelled.id);
    syncStoreStateToCloud();
    _saveToDisk();
    notifyListeners();

    return TransactionRecordResult.success(cancelled);
  }

  void payDebt(String transactionId) {
    payDebtAmount(transactionId: transactionId, paidAmount: double.infinity);
  }

  void payDebtAmount({
    required String transactionId,
    required double paidAmount,
  }) {
    final index = transactions.indexWhere((t) => t.id == transactionId);
    if (index == -1) return;

    final tx = transactions[index];
    if (tx.status != TransactionStatus.debt || paidAmount <= 0) return;

    final totalDue = tx.amount;
    final actualPaid = paidAmount >= totalDue ? totalDue : paidAmount;
    final remaining = (totalDue - actualPaid).clamp(0.0, double.infinity);

    if (remaining <= 0.01) {
      transactions[index] = TransactionModel(
        id: tx.id,
        walletPhone: tx.walletPhone,
        clientPhone: tx.clientPhone,
        clientName: tx.clientName,
        type: tx.type,
        amount: tx.amount,
        commission: tx.commission,
        networkFee: tx.networkFee,
        deductCommission: tx.deductCommission,
        status: TransactionStatus.completed,
        notes: '${tx.notes ?? ""} (تم السداد بالكامل)',
        createdAt: tx.createdAt,
      );
      cashInDrawer += actualPaid;
    } else {
      transactions[index] = TransactionModel(
        id: tx.id,
        walletPhone: tx.walletPhone,
        clientPhone: tx.clientPhone,
        clientName: tx.clientName,
        type: tx.type,
        amount: remaining,
        commission: tx.commission,
        networkFee: tx.networkFee,
        deductCommission: tx.deductCommission,
        status: TransactionStatus.debt,
        notes:
            '${tx.notes ?? ""} [سُدد منه ${actualPaid.toStringAsFixed(1)} ج]',
        createdAt: tx.createdAt,
      );

      cashInDrawer += actualPaid;

      transactions.insert(
        0,
        TransactionModel(
          id: 'DEBT-PAY-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
          walletPhone: 'سداد جزئي لدين',
          clientPhone: tx.clientPhone,
          clientName: '${tx.clientName ?? tx.clientPhone} (دفعة على الحساب)',
          type: TransactionType.receive,
          amount: actualPaid,
          commission: 0,
          status: TransactionStatus.completed,
          notes:
              'دفعة من فاتورة ${tx.id} - المتبقي ${remaining.toStringAsFixed(2)} ج.م',
          createdAt: DateTime.now(),
        ),
      );
    }

    _recalculateWalletUsage();
    _saveToDisk();
    syncStoreStateToCloud();
    notifyListeners();
  }

  List<TransactionModel> getCustomerActiveDebts(String clientPhone) {
    final clean = clientPhone.trim();
    return transactions
        .where(
          (t) =>
              t.status == TransactionStatus.debt &&
              t.clientPhone.trim() == clean,
        )
        .toList();
  }

  double getCustomerTotalDebt(String clientPhone) {
    return getCustomerActiveDebts(clientPhone)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  void processSale(String itemName, double price) {
    if (price > 0) {
      cashInDrawer += price;
      _saveToDisk();
      notifyListeners();
    }
    pushSaleToCloud(
      invoiceId: 'POS_${DateTime.now().millisecondsSinceEpoch}',
      amount: price,
      itemsSummary: itemName,
    );
  }

  void processMachineTransaction({
    required bool isFawry,
    required bool isCashIn,
    required double amount,
    required double commission,
  }) {
    if (isCashIn) {
      if (isFawry) {
        fawryBalance -= amount;
      } else {
        amanBalance -= amount;
      }
      cashInDrawer += (amount + commission);
    } else {
      if (isFawry) {
        fawryBalance += amount;
      } else {
        amanBalance += amount;
      }
      cashInDrawer -= (amount - commission);
    }
    _saveToDisk();
    syncStoreStateToCloud();
    notifyListeners();
  }

  // ==================== 8. الحسابات الحقيقية ====================

  /// كل المعاملات المنفَّذة فعلياً خلال فترة معينة.
  ///
  /// - تُستبعد المؤجلة (pending) لأنها لم تؤثر على الرصيد بعد.
  /// - التاريخ المستخدم هو [TransactionModel.executedAt] للعمليات التي
  ///   اعتُمدت لاحقاً، وإلا [TransactionModel.createdAt].
  List<TransactionModel> transactionsByPeriod(String period) {
    final now = DateTime.now();
    return transactions.where((t) {
      if (t.status == TransactionStatus.trash ||
          t.status == TransactionStatus.pending) {
        return false;
      }
      final date = t.executedAt ?? t.createdAt;
      if (period == 'today') {
        return date.year == now.year &&
            date.month == now.month &&
            date.day == now.day;
      } else if (period == 'week') {
        return now.difference(date).inDays <= 7;
      } else if (period == 'month') {
        return date.year == now.year && date.month == now.month;
      }
      return true;
    }).toList();
  }

  List<TransactionModel> get todayTransactions => transactionsByPeriod('today');

  double get todaySent => todayTransactions
      .where((t) => t.type == TransactionType.transfer)
      .fold(0.0, (s, t) => s + t.amount);

  double get todayReceived => todayTransactions
      .where((t) => t.type == TransactionType.receive)
      .fold(0.0, (s, t) => s + t.amount);

  double get todayTotalVolume => todaySent + todayReceived;
  double get todayProfits =>
      todayTransactions.fold(0.0, (s, t) => s + t.commission);

  double get supermarketTodaySales => todayReceived;
  double get supermarketTodayProfit => todayProfits;

  List<TransactionModel> get monthTransactions => transactionsByPeriod('month');

  double get monthSent => monthTransactions
      .where((t) => t.type == TransactionType.transfer)
      .fold(0.0, (s, t) => s + t.amount);

  double get monthReceived => monthTransactions
      .where((t) => t.type == TransactionType.receive)
      .fold(0.0, (s, t) => s + t.amount);

  double get monthTotalVolume => monthSent + monthReceived;
  double get monthProfits =>
      monthTransactions.fold(0.0, (s, t) => s + t.commission);

  // ==================== 9. محرك قائمة الدخل والأرباح الحقيقية (P&L Engine) ====================
  Map<String, double> getIncomeStatement(String period) {
    final txs = transactionsByPeriod(period);

    double grossSales = 0.0;
    double cogs = 0.0;
    double servicesProfit = 0.0;
    double operatingExpenses = 0.0;
    double wasteLosses = 0.0;
    double returnsTotal = 0.0;

    for (final tx in txs) {
      if (tx.walletPhone == 'مصروفات ونثريات') {
        operatingExpenses += tx.amount;
      } else if (tx.walletPhone == 'بضاعة تالفة وهالك') {
        wasteLosses += tx.amount;
      } else if (tx.walletPhone == 'مرتجع مبيعات') {
        returnsTotal += tx.amount;
      } else if (tx.id.startsWith('INV-') ||
          tx.walletPhone == 'كاشير السوبر ماركت') {
        grossSales += tx.amount;
        final profit = tx.commission;
        cogs += (tx.amount - profit).clamp(0.0, double.infinity);
      } else if (tx.walletPhone != 'تقفيل وردية' &&
          tx.walletPhone != 'شراء بضاعة للمخزن' &&
          !tx.id.startsWith('DEBT-PAY')) {
        servicesProfit += tx.commission;
      }
    }

    final netSales = (grossSales - returnsTotal).clamp(0.0, double.infinity);
    final grossMerchandiseProfit = (netSales - cogs).clamp(
      0.0,
      double.infinity,
    );
    final totalGrossIncome = grossMerchandiseProfit + servicesProfit;
    final netOperatingProfit =
        totalGrossIncome - operatingExpenses - wasteLosses;
    final netMargin = netSales > 0
        ? (netOperatingProfit / netSales) * 100
        : 0.0;

    return {
      'grossSales': grossSales,
      'returnsTotal': returnsTotal,
      'netSales': netSales,
      'cogs': cogs,
      'grossMerchandiseProfit': grossMerchandiseProfit,
      'servicesProfit': servicesProfit,
      'totalGrossIncome': totalGrossIncome,
      'operatingExpenses': operatingExpenses,
      'wasteLosses': wasteLosses,
      'netOperatingProfit': netOperatingProfit,
      'netMargin': netMargin,
    };
  }

  // ==================== 10. التخزين والحفظ الدائم الذري ====================
  static const String _storageKey = 'cashawy_master_database';

  Future<void> _loadFromDisk() async {
    try {
      final content = await CashawyStorage.read(_storageKey);
      if (content == null || content.isEmpty) return;

      final Map<String, dynamic> data = jsonDecode(content);

      marketName = data['marketName'] ?? marketName;
      marketPhone = data['marketPhone'] ?? marketPhone;
      marketAddress = data['marketAddress'] ?? marketAddress;
      licenseKey = data['licenseKey'] ?? licenseKey;
      activeCashier = data['activeCashier'] ?? activeCashier;
      isDarkMode = data['isDarkMode'] ?? isDarkMode;

      if (data['adminPinHash'] != null) {
        adminPinHash = data['adminPinHash'];
      } else if (data['adminPin'] != null) {
        adminPinHash = _hashPin(data['adminPin']);
      }

      receiptFooterMessage =
          data['receiptFooterMessage'] ?? receiptFooterMessage;
      returnPolicyNote = data['returnPolicyNote'] ?? returnPolicyNote;
      taxAndCommercialReg = data['taxAndCommercialReg'] ?? taxAndCommercialReg;

      cashInDrawer = (data['cashInDrawer'] ?? cashInDrawer).toDouble();
      fawryBalance = (data['fawryBalance'] ?? fawryBalance).toDouble();
      amanBalance = (data['amanBalance'] ?? amanBalance).toDouble();
      todayExpenses = (data['todayExpenses'] ?? todayExpenses).toDouble();
      todayDamages = (data['todayDamages'] ?? todayDamages).toDouble();

      if (data['wallets'] is List && (data['wallets'] as List).isNotEmpty) {
        final previousSelectedId = wallets.isNotEmpty
            ? selectedWallet.id
            : null;
        wallets = (data['wallets'] as List)
            .map((w) => WalletModel.fromJson(w))
            .toList();
        selectedWallet = wallets.firstWhere(
          (w) => w.id == previousSelectedId,
          orElse: () => wallets.first,
        );
      }
      if (data['products'] is List && (data['products'] as List).isNotEmpty) {
        products = (data['products'] as List)
            .map((p) => ProductModel.fromJson(p))
            .toList();
      }
      if (data['suppliers'] is List) {
        suppliers = (data['suppliers'] as List)
            .map((s) => SupplierModel.fromJson(s))
            .toList();
      }
      if (data['transactions'] is List) {
        transactions = (data['transactions'] as List)
            .map((t) => TransactionModel.fromJson(t))
            .toList();
      }
      _recalculateWalletUsage();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _saveToDisk() async {
    try {
      final data = {
        'marketName': marketName,
        'marketPhone': marketPhone,
        'marketAddress': marketAddress,
        'licenseKey': licenseKey,
        'activeCashier': activeCashier,
        'isDarkMode': isDarkMode,
        'adminPinHash': adminPinHash,
        'receiptFooterMessage': receiptFooterMessage,
        'returnPolicyNote': returnPolicyNote,
        'taxAndCommercialReg': taxAndCommercialReg,
        'cashInDrawer': cashInDrawer,
        'fawryBalance': fawryBalance,
        'amanBalance': amanBalance,
        'todayExpenses': todayExpenses,
        'todayDamages': todayDamages,
        'wallets': wallets.map((w) => w.toJson()).toList(),
        'products': products.map((p) => p.toJson()).toList(),
        'suppliers': suppliers.map((s) => s.toJson()).toList(),
        'transactions': transactions.map((t) => t.toJson()).toList(),
      };
      await CashawyStorage.write(_storageKey, jsonEncode(data));
    } catch (_) {}
  }

  // ==================== 11. إغلاق الوردية Z-Report ====================
  double shiftOpeningCash = 0.0;
  DateTime shiftStartTime = DateTime.now();

  Map<String, dynamic> closeCurrentShift({
    required double actualCashCounted,
    required String notes,
  }) {
    final expected = cashInDrawer;
    final difference = actualCashCounted - expected;
    final now = DateTime.now();

    final report = {
      'shiftId': 'SH-${now.millisecondsSinceEpoch.toString().substring(7)}',
      'cashierName': activeCashier,
      'marketName': marketName,
      'startTime': shiftStartTime,
      'endTime': now,
      'openingCash': shiftOpeningCash,
      'supermarketSales': todayReceived,
      'supermarketProfit': todayProfits,
      'expectedCash': expected,
      'actualCash': actualCashCounted,
      'difference': difference,
      'isShortage': difference < -0.01,
      'isSurplus': difference > 0.01,
      'notes': notes,
    };

    transactions.insert(
      0,
      TransactionModel(
        id: 'SHIFT-CLOSE-${now.millisecondsSinceEpoch.toString().substring(7)}',
        walletPhone: 'تقفيل وردية',
        clientPhone: activeCashier,
        clientName: difference < -0.01
            ? 'عجز وردية (${difference.abs().toStringAsFixed(2)} ج.م)'
            : (difference > 0.01
                  ? 'زيادة وردية (+${difference.toStringAsFixed(2)} ج.م)'
                  : 'وردية متطابقة تماماً'),
        type: TransactionType.receive,
        amount: actualCashCounted,
        commission: difference,
        status: TransactionStatus.completed,
        notes: notes,
        createdAt: now,
      ),
    );

    cashInDrawer = actualCashCounted;
    shiftOpeningCash = actualCashCounted;
    shiftStartTime = now;
    todayExpenses = 0.0;
    todayDamages = 0.0;

    _saveToDisk();
    syncStoreStateToCloud();
    notifyListeners();

    return report;
  }

  // ==================== 12. النسخ الاحتياطي وحفظ الملفات ====================
  String exportBackupJson() {
    final data = {
      'version': '1.0.0',
      'backupDate': DateTime.now().toIso8601String(),
      'marketName': marketName,
      'marketPhone': marketPhone,
      'marketAddress': marketAddress,
      'licenseKey': licenseKey,
      'activeCashier': activeCashier,
      'adminPinHash': adminPinHash,
      'receiptFooterMessage': receiptFooterMessage,
      'returnPolicyNote': returnPolicyNote,
      'taxAndCommercialReg': taxAndCommercialReg,
      'cashInDrawer': cashInDrawer,
      'fawryBalance': fawryBalance,
      'amanBalance': amanBalance,
      'todayExpenses': todayExpenses,
      'todayDamages': todayDamages,
      'wallets': wallets.map((w) => w.toJson()).toList(),
      'products': products.map((p) => p.toJson()).toList(),
      'suppliers': suppliers.map((s) => s.toJson()).toList(),
      'transactions': transactions.map((t) => t.toJson()).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  Future<String?> saveBackupToFile() async {
    if (kIsWeb) return null;
    try {
      final jsonStr = exportBackupJson();
      final now = DateTime.now();
      final dateSlug =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}_${now.hour}-${now.minute}';

      String dirPath = Directory.systemTemp.path;
      final userProfile = Platform.environment['USERPROFILE'];
      if (userProfile != null) {
        final downloads = Directory('$userProfile\\Downloads');
        if (downloads.existsSync()) {
          dirPath = downloads.path;
        }
      }

      final targetPath = '$dirPath\\Cashawy_Backup_$dateSlug.json';
      final file = File(targetPath);
      await file.writeAsString(jsonStr, encoding: utf8, flush: true);
      return targetPath;
    } catch (_) {
      return null;
    }
  }

  bool restoreFromJson(String rawJson) {
    try {
      final Map<String, dynamic> data = jsonDecode(rawJson);
      marketName = data['marketName'] ?? marketName;
      marketPhone = data['marketPhone'] ?? marketPhone;
      marketAddress = data['marketAddress'] ?? marketAddress;
      licenseKey = data['licenseKey'] ?? licenseKey;
      activeCashier = data['activeCashier'] ?? activeCashier;

      if (data['adminPinHash'] != null) {
        adminPinHash = data['adminPinHash'];
      } else if (data['adminPin'] != null) {
        adminPinHash = _hashPin(data['adminPin']);
      }

      receiptFooterMessage =
          data['receiptFooterMessage'] ?? receiptFooterMessage;
      returnPolicyNote = data['returnPolicyNote'] ?? returnPolicyNote;
      taxAndCommercialReg = data['taxAndCommercialReg'] ?? taxAndCommercialReg;

      cashInDrawer = (data['cashInDrawer'] ?? cashInDrawer).toDouble();
      fawryBalance = (data['fawryBalance'] ?? fawryBalance).toDouble();
      amanBalance = (data['amanBalance'] ?? amanBalance).toDouble();

      if (data['wallets'] is List && (data['wallets'] as List).isNotEmpty) {
        final previousSelectedId = wallets.isNotEmpty
            ? selectedWallet.id
            : null;
        wallets = (data['wallets'] as List)
            .map((w) => WalletModel.fromJson(w))
            .toList();
        selectedWallet = wallets.firstWhere(
          (w) => w.id == previousSelectedId,
          orElse: () => wallets.first,
        );
      }
      if (data['products'] is List) {
        products = (data['products'] as List)
            .map((p) => ProductModel.fromJson(p))
            .toList();
      }
      if (data['suppliers'] is List) {
        suppliers = (data['suppliers'] as List)
            .map((s) => SupplierModel.fromJson(s))
            .toList();
      }
      if (data['transactions'] is List) {
        transactions = (data['transactions'] as List)
            .map((t) => TransactionModel.fromJson(t))
            .toList();
      }

      _recalculateWalletUsage();
      _saveToDisk();
      syncStoreStateToCloud();
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  // ==================== 13. تحليلات التقارير ====================
  Map<String, int> get topSellingItems {
    final Map<String, int> counter = {};
    for (final tx in transactions) {
      if (tx.notes != null && tx.notes!.isNotEmpty) {
        final parts = tx.notes!.split('، ');
        for (final part in parts) {
          final match = RegExp(r'^(.*?)\s*\(x(.*?)\)$').firstMatch(part.trim());
          if (match != null) {
            final name = match.group(1) ?? part;
            counter[name] = (counter[name] ?? 0) + 1;
          }
        }
      }
    }
    final sortedEntries = counter.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Map.fromEntries(sortedEntries.take(5));
  }

  double getSalesByPeriod(String period) {
    return transactionsByPeriod(period).fold(
      0.0,
      (sum, t) => sum + (t.type == TransactionType.receive ? t.amount : 0),
    );
  }

  double getProfitsByPeriod(String period) {
    return transactionsByPeriod(period)
        .fold(0.0, (sum, t) => sum + t.commission);
  }

  // ==================== 14. تصدير ملفات Excel / CSV ====================
  Future<String?> exportTransactionsToCsv() async {
    final buffer = StringBuffer();
    buffer.write('\uFEFF');
    buffer.writeln(
      'رقم المعاملة,البيان,الطرف / العميل,التاريخ,المبلغ (ج.م),الربح (ج.م),الحالة,ملاحظات',
    );

    for (final tx in transactions) {
      final cleanNotes = (tx.notes ?? '').replaceAll(',', ' - ');
      final cleanClient = (tx.clientName ?? tx.clientPhone).replaceAll(
        ',',
        ' - ',
      );
      final dateStr = tx.createdAt.toString().split('.')[0];
      final statusStr = tx.status == TransactionStatus.debt
          ? 'آجل لم يسدد'
          : (tx.status == TransactionStatus.completed ? 'مكتملة' : 'معلقة');

      buffer.writeln(
        '${tx.id},${tx.walletPhone},$cleanClient,$dateStr,${tx.amount},${tx.commission},$statusStr,$cleanNotes',
      );
    }

    final now = DateTime.now();
    final fileName =
        'Cashawy_Transactions_${now.year}-${now.month}-${now.day}.csv';
    return await CashawyStorage.downloadFile(fileName, buffer.toString());
  }

  Future<String?> exportInventoryToCsv() async {
    final buffer = StringBuffer();
    buffer.write('\uFEFF');
    buffer.writeln(
      'الباركود,اسم المنتج,القسم,سعر الشراء,سعر البيع,الكمية بالمخزن,إجمالي القيمة,حد النواقص,نوع الصنف,حالة الرصيد',
    );

    for (final p in products) {
      final cleanName = p.name.replaceAll(',', ' - ');
      final totalValue = p.buyPrice * p.stockQuantity;
      final statusStr = p.isLowStock ? 'ناقص (يحتاج طلب)' : 'متوفر';
      final typeStr = p.isWeighted
          ? 'ميزان (كجم)'
          : (p.hasCarton ? '${p.bulkUnitName}/${p.unitName}' : p.unitName);

      buffer.writeln(
        '${p.barcode},$cleanName,${p.category},${p.buyPrice},${p.sellPrice},${p.stockQuantity},$totalValue,${p.minStockAlert},$typeStr,$statusStr',
      );
    }

    final now = DateTime.now();
    final fileName =
        'Cashawy_Inventory_Stock_${now.year}-${now.month}-${now.day}.csv';
    return await CashawyStorage.downloadFile(fileName, buffer.toString());
  }

  // ==================== 15. دوال الربط السحابي ومزامنة الرسائل ====================

  WalletModel? _firstWalletWhere(bool Function(WalletModel) test) {
    for (final wallet in wallets) {
      if (test(wallet)) return wallet;
    }
    return null;
  }

  /// ربط معاملة قادمة من بوابة الـ SMS بمحفظة مسجلة فعلياً.
  ///
  /// بيانات البوابة القديمة كانت ترسل اسم الشبكة (مثل "فودافون كاش") بدلاً
  /// من رقم المحفظة، لذلك نطابق بالرقم ثم بالاسم ثم بنوع الشبكة.
  WalletModel _resolveWalletForCloud(String walletPhone, String notes) {
    final raw = walletPhone.trim();

    if (raw.isNotEmpty) {
      final byPhone = _firstWalletWhere((w) => w.phoneNumber.trim() == raw);
      if (byPhone != null) return byPhone;

      final byTitle = _firstWalletWhere((w) => w.title.trim() == raw);
      if (byTitle != null) return byTitle;
    }

    final haystack = '$raw $notes'.toLowerCase();
    WalletProvider? provider;
    if (haystack.contains('فودافون') ||
        haystack.contains('vodafone') ||
        haystack.contains('vf-cash')) {
      provider = WalletProvider.vodafone;
    } else if (haystack.contains('أورنج') ||
        haystack.contains('اورنج') ||
        haystack.contains('orange')) {
      provider = WalletProvider.orange;
    } else if (haystack.contains('اتصالات') || haystack.contains('etisalat')) {
      provider = WalletProvider.etisalat;
    } else if (haystack.contains('إنستاباي') ||
        haystack.contains('انستاباي') ||
        haystack.contains('instapay')) {
      provider = WalletProvider.instapay;
    } else if (haystack.contains('we pay') || haystack.contains('وي باي')) {
      provider = WalletProvider.we;
    }

    if (provider != null) {
      final candidates = wallets.where((w) => w.provider == provider).toList();
      if (candidates.isNotEmpty) {
        final selected = _firstWalletWhere(
          (w) => w.id == selectedWallet.id && w.provider == provider,
        );
        return selected ?? candidates.first;
      }
    }

    return selectedWallet;
  }

  /// استقبال معاملة الـ SMS الملتقطة سحابياً وعرضها في فواتير اللاب توب
  void addCloudParsedTransaction({
    required String cloudId,
    required double amount,
    required String typeStr,
    required String walletPhone,
    required String clientPhone,
    required String notes,
    bool triggerAlert = true,
  }) {
    final exists = transactions.any((tx) => tx.id == cloudId);
    if (exists) return;

    final txType = typeStr == 'transfer'
        ? TransactionType.transfer
        : TransactionType.receive;

    final resolvedWallet = _resolveWalletForCloud(walletPhone, notes);

    final newTx = TransactionModel(
      id: cloudId,
      walletPhone: resolvedWallet.phoneNumber,
      clientPhone: clientPhone.isEmpty ? 'عميل كاش' : clientPhone,
      clientName: 'التقاط آلي من رسائل SMS',
      type: txType,
      amount: amount,
      commission: 0.0,
      networkFee: 0.0,
      deductCommission: false,
      status: TransactionStatus.completed,
      notes: notes,
      createdAt: DateTime.now(),
    );

    transactions.insert(0, newTx);
    _recalculateWalletUsage();

    if (triggerAlert) {
      liveTransactionAlert.value = newTx;
    }

    _saveToDisk();
    notifyListeners();
  }

  /// تحديث رصيد المحفظة الفعلي في اللاب توب بناءً على القراءة الفعلية للرسالة
  void updateWalletBalanceFromCloud({
    required String providerName,
    required double newBalance,
    String? walletPhone,
  }) {
    if (wallets.isEmpty || newBalance < 0) return;

    final raw = providerName.trim();
    final phone = walletPhone?.trim();

    WalletModel? target;
    if (phone != null && phone.isNotEmpty) {
      target = _firstWalletWhere((w) => w.phoneNumber.trim() == phone);
    }
    target ??= _firstWalletWhere((w) => w.phoneNumber.trim() == raw);
    target ??= _firstWalletWhere((w) => w.title.trim() == raw);
    target ??= _resolveWalletForCloud(raw, '');

    final rounded = (newBalance * 100).roundToDouble() / 100;
    if ((target.balance - rounded).abs() < 0.01) return;

    target.balance = rounded;
    _saveToDisk();
    notifyListeners();
  }

  /// رفع حالة المتجر ومؤشرات الخزنة إلى السحابة ليراها رادار المالك
  Future<void> syncStoreStateToCloud() async {
    try {
      final docRef = _firestore.collection('stores').doc(_cloudStoreId);

      final walletsPayload = wallets
          .map(
            (w) => {
              'id': w.id,
              'title': w.title,
              'phone': w.phoneNumber,
              'phoneNumber': w.phoneNumber,
              'provider': w.provider.name,
              'simSlot': w.simSlot,
              'balance': w.balance,
              'dailyTransferLimit': w.dailyTransferLimit,
              'monthlyTransferLimit': w.monthlyTransferLimit,
              'dailyReceiveLimit': w.dailyReceiveLimit,
              'monthlyReceiveLimit': w.monthlyReceiveLimit,
              'usedDailyTransfer': w.usedDailyTransfer,
              'usedMonthlyTransfer': w.usedMonthlyTransfer,
              'usedDailyReceive': w.usedDailyReceive,
              'usedMonthlyReceive': w.usedMonthlyReceive,
              'isNearLimit': w.isNearLimit,
            },
          )
          .toList();

      await docRef.set({
        'cashInDrawer': cashInDrawer,
        'fawryBalance': fawryBalance,
        'amanBalance': amanBalance,
        'todaySales': todayReceived,
        'todayProfits': todayProfits,
        'totalCapital': totalCapital,
        'wallets': walletsPayload,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint('☁️ [Cloud Sync] Store dashboard KPIs synced successfully.');
    } catch (e) {
      debugPrint('⚠️ [Cloud Sync] Failed to sync KPIs: $e');
    }
  }

  /// رفع فاتورة مبيعات جديدة إلى شريط العمليات المباشرة في موبايل المالك
  Future<void> pushSaleToCloud({
    required String invoiceId,
    required double amount,
    required String itemsSummary,
    bool isDebt = false,
    String? clientPhone,
    String? clientName,
  }) async {
    try {
      final txRef = _firestore
          .collection('stores')
          .doc(_cloudStoreId)
          .collection('live_transactions')
          .doc(invoiceId);

      await txRef.set({
        'id': invoiceId,
        'amount': amount,
        'type': 'receive',
        'walletPhone': isDebt ? 'آجل وشكك' : 'كاشير السوبر ماركت',
        'clientPhone': clientPhone ?? 'عميل نقدي',
        'clientName': clientName,
        'notes': itemsSummary,
        'status': isDebt ? 'debt' : 'completed',
        'timestamp': FieldValue.serverTimestamp(),
      });

      await syncStoreStateToCloud();
    } catch (e) {
      debugPrint('⚠️ [Cloud Sync] Failed to push transaction: $e');
    }
  }

  // ==================== 16. دوال إدارة المحافظ وإنستاباي ====================

  /// 1. إضافة محفظة أو حساب إنستاباي جديد
  void addNewWallet(WalletModel newWallet) {
    addWallet(newWallet);
    syncStoreStateToCloud();
  }

  /// اختيار المحفظة المناسبة لنوع الشبكة (يُستخدم عند التقاط رسالة SMS).
  WalletModel walletForProvider(WalletProvider provider) {
    final candidates = wallets.where((w) => w.provider == provider).toList();
    if (candidates.isEmpty) return selectedWallet;

    return _firstWalletWhere(
          (w) => w.id == selectedWallet.id && w.provider == provider,
        ) ??
        candidates.first;
  }

  /// 2. تعديل الرصيد الفعلي لمحفظة أو حساب إنستاباي
  void updateSingleWalletBalance(String walletId, double newBalance) {
    final idx = wallets.indexWhere((w) => w.id == walletId);
    if (idx != -1) {
      wallets[idx].balance = newBalance;
      _saveToDisk();
      syncStoreStateToCloud();
      notifyListeners();
    }
  }

  /// 3. حذف محفظة أو حساب إنستاباي
  void deleteWallet(String walletId) {
    if (wallets.length <= 1) return;
    wallets.removeWhere((w) => w.id == walletId);
    if (selectedWallet.id == walletId) {
      selectedWallet = wallets.first;
    }
    _saveToDisk();
    syncStoreStateToCloud();
    notifyListeners();
  }

  /// 4. جلب أرصدة الخزنة والدرج والمحافظ المحفوظة في السحابة عند إقلاع البرنامج
  Future<void> fetchStoreStateFromCloud() async {
    try {
      final doc = await _firestore
          .collection('stores')
          .doc(_cloudStoreId)
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;

        if (data.containsKey('cashInDrawer')) {
          cashInDrawer =
              (data['cashInDrawer'] as num?)?.toDouble() ?? cashInDrawer;
        }

        if (data.containsKey('fawryBalance')) {
          fawryBalance =
              (data['fawryBalance'] as num?)?.toDouble() ?? fawryBalance;
        }

        if (data.containsKey('amanBalance')) {
          amanBalance =
              (data['amanBalance'] as num?)?.toDouble() ?? amanBalance;
        }

        if (data.containsKey('wallets') && data['wallets'] is List) {
          final cloudWallets = data['wallets'] as List;
          final previousSelectedId = selectedWallet.id;

          for (final cw in cloudWallets) {
            if (cw is! Map) continue;

            final map = Map<String, dynamic>.from(cw);
            if (!map.containsKey('phoneNumber') && map.containsKey('phone')) {
              map['phoneNumber'] = map['phone'];
            }

            final rawPhone = (map['phoneNumber'] ?? '').toString().trim();
            if (rawPhone.isEmpty) continue;

            final incoming = WalletModel.fromJson(map);
            final index = wallets.indexWhere(
              (w) =>
                  w.id == incoming.id ||
                  w.phoneNumber.trim() == incoming.phoneNumber.trim(),
            );

            if (index == -1) {
              wallets.add(incoming);
            } else {
              final current = wallets[index];
              // نحدّث الرصيد دائماً، أما الحدود فلا نلمسها إلا لو السحابة
              // بتبعت الحقول الجديدة فعلاً (حتى لا نصفّر إعدادات المستخدم).
              wallets[index] = current.copyWith(
                balance: incoming.balance,
                title: (incoming.title.trim().isEmpty) ? null : incoming.title,
                provider: map.containsKey('provider')
                    ? incoming.provider
                    : null,
                dailyTransferLimit: map.containsKey('dailyTransferLimit')
                    ? incoming.dailyTransferLimit
                    : null,
                monthlyTransferLimit: map.containsKey('monthlyTransferLimit')
                    ? incoming.monthlyTransferLimit
                    : null,
                dailyReceiveLimit: map.containsKey('dailyReceiveLimit')
                    ? incoming.dailyReceiveLimit
                    : null,
                monthlyReceiveLimit: map.containsKey('monthlyReceiveLimit')
                    ? incoming.monthlyReceiveLimit
                    : null,
              );
            }
          }

          // إزالة محفظة البداية الوهمية بعد وصول محافظ حقيقية من السحابة.
          if (wallets.length > 1) {
            wallets.removeWhere(
              (w) =>
                  w.id == 'w1' &&
                  w.balance == 0 &&
                  w.phoneNumber == '01000000000' &&
                  !transactions.any((t) => t.walletPhone == w.phoneNumber),
            );
          }

          if (wallets.isNotEmpty) {
            selectedWallet = wallets.firstWhere(
              (w) => w.id == previousSelectedId,
              orElse: () => wallets.first,
            );
          }
        }
        _recalculateWalletUsage();
        _saveToDisk();
        notifyListeners();

        // نرفع الشكل الجديد للحدود (limits) حتى يظهر في رادار المالك
        // حتى لو لم تحدث أي عملية جديدة بعد التحديث.
        syncStoreStateToCloud();
        debugPrint('✅ [Store State] Hydrated from Firestore successfully.');
      }
    } catch (e) {
      debugPrint('Fetch cloud state error: $e');
    }
  }

  Future<void> loadStoreDataFromDatabase() async {
    final db = DatabaseHelper.instance;

    products = await db.getAllProducts();

    final dbWallets = await db.getAllWallets();
    if (dbWallets.isNotEmpty) {
      wallets = dbWallets;
      selectedWallet = wallets.first;
    }

    transactions = await db.getAllTransactions();
    suppliers = await db.getAllSuppliers();

    final savedCash = await db.getSetting('cashInDrawer');
    if (savedCash != null) {
      cashInDrawer = double.tryParse(savedCash) ?? cashInDrawer;
    }

    notifyListeners();
  }
}
