import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../models/product_model.dart';
import '../../models/transaction_model.dart';
import '../../models/wallet_model.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('cashawy_store.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    // 1. تهيئة محرك FFI لنظام الويندوز
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dbPath = await _resolveDatabasePath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<String> _resolveDatabasePath() async {
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
      final appSupportDir = await getApplicationSupportDirectory();
      return appSupportDir.path;
    } else {
      return await getDatabasesPath();
    }
  }

  Future<void> _createDB(Database db, int version) async {
    // 1. جدول المنتجات والبضائع
    await db.execute('''
      CREATE TABLE products (
        id TEXT PRIMARY KEY,
        barcode TEXT UNIQUE NOT NULL,
        name TEXT NOT NULL,
        category TEXT NOT NULL,
        buyPrice REAL NOT NULL,
        sellPrice REAL NOT NULL,
        stockQuantity REAL NOT NULL,
        minStockAlert REAL NOT NULL,
        isWeighted INTEGER NOT NULL,
        unitName TEXT NOT NULL,
        hasCarton INTEGER NOT NULL,
        bulkUnitName TEXT NOT NULL,
        cartonBarcode TEXT,
        cartonUnitsCount INTEGER NOT NULL,
        cartonSellPrice REAL NOT NULL
      )
    ''');

    await db.execute('CREATE INDEX idx_products_barcode ON products (barcode);');

    await db.execute('''
      CREATE TABLE wallets (
        id TEXT PRIMARY KEY,
        phoneNumber TEXT NOT NULL,
        title TEXT NOT NULL,
        provider TEXT NOT NULL,
        simSlot INTEGER NOT NULL,
        pinCode TEXT NOT NULL,
        balance REAL NOT NULL,
        dailyTransferLimit REAL NOT NULL,
        monthlyTransferLimit REAL NOT NULL,
        dailyReceiveLimit REAL NOT NULL,
        monthlyReceiveLimit REAL NOT NULL,
        usedDailyTransfer REAL NOT NULL,
        usedMonthlyTransfer REAL NOT NULL,
        usedDailyReceive REAL NOT NULL,
        usedMonthlyReceive REAL NOT NULL
      )
    ''');

    // 3. جدول المعاملات والفواتير
    await db.execute('''
      CREATE TABLE transactions (
        id TEXT PRIMARY KEY,
        walletPhone TEXT NOT NULL,
        clientPhone TEXT NOT NULL,
        clientName TEXT,
        type TEXT NOT NULL,
        amount REAL NOT NULL,
        commission REAL NOT NULL,
        networkFee REAL NOT NULL,
        deductCommission INTEGER NOT NULL,
        status TEXT NOT NULL,
        notes TEXT,
        createdAt TEXT NOT NULL
      )
    ''');

    await db.execute('CREATE INDEX idx_transactions_created ON transactions (createdAt);');
    await db.execute('CREATE INDEX idx_transactions_status ON transactions (status);');

    // 4. جدول الموردين والشركات
    await db.execute('''
      CREATE TABLE suppliers (
        id TEXT PRIMARY KEY,
        companyName TEXT NOT NULL,
        phone TEXT NOT NULL,
        balanceOwed REAL NOT NULL
      )
    ''');

    // 5. جدول إعدادات المحل والأرصدة
    await db.execute('''
      CREATE TABLE store_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }

  // ==================== عمليات المنتجات (Products) ====================

  Future<void> insertOrUpdateProduct(ProductModel product) async {
    final db = await database;
    await db.insert(
      'products',
      {
        'id': product.id,
        'barcode': product.barcode,
        'name': product.name,
        'category': product.category,
        'buyPrice': product.buyPrice,
        'sellPrice': product.sellPrice,
        'stockQuantity': product.stockQuantity,
        'minStockAlert': product.minStockAlert,
        'isWeighted': product.isWeighted ? 1 : 0,
        'unitName': product.unitName,
        'hasCarton': product.hasCarton ? 1 : 0,
        'bulkUnitName': product.bulkUnitName,
        'cartonBarcode': product.cartonBarcode,
        'cartonUnitsCount': product.cartonUnitsCount,
        'cartonSellPrice': product.cartonSellPrice,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<ProductModel>> getAllProducts() async {
    final db = await database;
    final maps = await db.query('products');
    return maps.map((map) {
      return ProductModel(
        id: map['id']?.toString() ?? '',
        barcode: map['barcode']?.toString() ?? '',
        name: map['name']?.toString() ?? '',
        category: map['category']?.toString() ?? 'عام',
        buyPrice: (map['buyPrice'] as num?)?.toDouble() ?? 0.0,
        sellPrice: (map['sellPrice'] as num?)?.toDouble() ?? 0.0,
        stockQuantity: (map['stockQuantity'] as num?)?.toDouble() ?? 0.0,
        minStockAlert: (map['minStockAlert'] as num?)?.toDouble() ?? 5.0,
        isWeighted: map['isWeighted'] == 1 || map['isWeighted'] == true,
        unitName: map['unitName']?.toString() ?? 'قطعة',
        hasCarton: map['hasCarton'] == 1 || map['hasCarton'] == true,
        bulkUnitName: map['bulkUnitName']?.toString() ?? 'كرتونة',
        cartonBarcode: map['cartonBarcode']?.toString(),
        cartonUnitsCount: (map['cartonUnitsCount'] as num?)?.toInt() ?? 1,
        cartonSellPrice: (map['cartonSellPrice'] as num?)?.toDouble() ?? 0.0,
      );
    }).toList();
  }

  Future<void> updateProductStock(String barcodeOrId, double newStock) async {
    final db = await database;
    await db.update(
      'products',
      {'stockQuantity': newStock},
      where: 'barcode = ? OR id = ?',
      whereArgs: [barcodeOrId, barcodeOrId],
    );
  }

  Future<void> deleteProduct(String id) async {
    final db = await database;
    await db.delete('products', where: 'id = ?', whereArgs: [id]);
  }

  // ==================== عمليات المحافظ (Wallets) ====================

  Future<void> insertOrUpdateWallet(WalletModel wallet) async {
    final db = await database;
    await db.insert(
      'wallets',
      wallet.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<WalletModel>> getAllWallets() async {
    final db = await database;
    final maps = await db.query('wallets');
    return maps.map((m) => WalletModel.fromJson(m)).toList();
  }

  Future<void> updateWalletBalance(String walletId, double newBalance) async {
    final db = await database;
    await db.update(
      'wallets',
      {'balance': newBalance},
      where: 'id = ?',
      whereArgs: [walletId],
    );
  }

  // ==================== عمليات المعاملات والفواتير (Transactions) ====================

  Future<void> insertTransaction(TransactionModel tx) async {
    final db = await database;
    await db.insert(
      'transactions',
      {
        'id': tx.id,
        'walletPhone': tx.walletPhone,
        'clientPhone': tx.clientPhone,
        'clientName': tx.clientName,
        'type': tx.type.name,
        'amount': tx.amount,
        'commission': tx.commission,
        'networkFee': tx.networkFee,
        'deductCommission': tx.deductCommission ? 1 : 0,
        'status': tx.status.name,
        'notes': tx.notes,
        'createdAt': tx.createdAt.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<TransactionModel>> getAllTransactions() async {
    final db = await database;
    final maps = await db.query(
      'transactions',
      orderBy: 'createdAt DESC',
    );
    return maps.map((m) {
      final mapCopy = Map<String, dynamic>.from(m);
      mapCopy['deductCommission'] = (m['deductCommission'] == 1 || m['deductCommission'] == true);
      return TransactionModel.fromJson(mapCopy);
    }).toList();
  }

  Future<void> updateTransactionStatus(String id, String newStatus, {double? newAmount}) async {
    final db = await database;
    final updateData = <String, dynamic>{'status': newStatus};
    if (newAmount != null) updateData['amount'] = newAmount;
    await db.update('transactions', updateData, where: 'id = ?', whereArgs: [id]);
  }

  // ==================== عمليات الموردين (Suppliers) ====================

  Future<void> insertOrUpdateSupplier(SupplierModel supplier) async {
    final db = await database;
    await db.insert(
      'suppliers',
      supplier.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<SupplierModel>> getAllSuppliers() async {
    final db = await database;
    final maps = await db.query('suppliers');
    return maps.map((m) => SupplierModel.fromJson(m)).toList();
  }

  // ==================== إعدادات المتجر (Settings) ====================

  Future<void> setSetting(String key, String value) async {
    final db = await database;
    await db.insert(
      'store_settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> getSetting(String key) async {
    final db = await database;
    final maps = await db.query(
      'store_settings',
      where: 'key = ?',
      whereArgs: [key],
    );
    if (maps.isNotEmpty) {
      return maps.first['value'] as String?;
    }
    return null;
  }
}