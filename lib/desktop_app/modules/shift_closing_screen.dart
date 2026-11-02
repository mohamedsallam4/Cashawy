import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../core/theme/app_theme.dart';
import '../../core/database/cashawy_store.dart';

class ShiftClosingScreen extends StatefulWidget {
  const ShiftClosingScreen({super.key});

  @override
  State<ShiftClosingScreen> createState() => _ShiftClosingScreenState();
}

class _ShiftClosingScreenState extends State<ShiftClosingScreen> {
  final CashawyStore _store = CashawyStore.instance;
  final NumberFormat _numFormat = NumberFormat('#,##0.00');

  final TextEditingController _actualCashController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  Map<String, dynamic>? _lastZReport;

  @override
  void dispose() {
    _actualCashController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _calculateAndCloseShift() {
    final actual = double.tryParse(_actualCashController.text.trim());
    if (actual == null || actual < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ يرجى إدخال إجمالي النقدية المعدودة في الدرج بشكل صحيح!'),
          backgroundColor: AppColors.alertRed,
        ),
      );
      return;
    }

    final report = _store.closeCurrentShift(
      actualCashCounted: actual,
      notes: _notesController.text.trim(),
    );

    setState(() {
      _lastZReport = report;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ تم تقفيل الوردية واستخراج تقرير الجرد (Z-Report) بنجاح!'),
        backgroundColor: AppColors.receiveGreen,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final startStr = DateFormat('yyyy/MM/dd hh:mm a').format(_store.shiftStartTime);
    final nowStr = DateFormat('yyyy/MM/dd hh:mm a').format(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inventory_outlined, color: Colors.white),
            SizedBox(width: 8),
            Text('تقفيل الوردية وجرد الدرج (Z-Report)'),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 850),
            child: _lastZReport != null
                ? _buildZReportResultCard(_lastZReport!)
                : _buildShiftCloseForm(startStr, nowStr),
          ),
        ),
      ),
    );
  }

  /// 1. استمارة عد النقدية وتقفيل الوردية
  Widget _buildShiftCloseForm(String startStr, String nowStr) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  radius: 26,
                  backgroundColor: AppColors.primary,
                  child: Icon(Icons.lock_clock, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('جرد صندوق الكاشير - الوردية الحالية', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    Text('الكاشير: ${_store.activeCashier} | بدأت الوردية: $startStr', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                  ],
                ),
              ],
            ),
            const Divider(height: 32),

            // كارت المعلومات التوضيحية
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _infoSummaryItem('مبيعات السوبر ماركت', '${_numFormat.format(_store.supermarketTodaySales)} ج.م', AppColors.primaryDark),
                  _infoSummaryItem('أرباح البضاعة المباعة', '${_numFormat.format(_store.supermarketTodayProfit)} ج.م', AppColors.capitalGold),
                  _infoSummaryItem('الفواتير والمعاملات', '${_store.todayTransactions.length}', AppColors.transferBlue),
                ],
              ),
            ),
            const SizedBox(height: 24),

            const Text(
              'خطوة العد الفعلي للنقدية بالدرج:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 4),
            Text(
              'قم بعد جميع النقود الورقية والفضية الموجودة داخل درج الكاشير واكتب الإجمالي بالأسفل:',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
            const SizedBox(height: 14),

            TextField(
              controller: _actualCashController,
              keyboardType: TextInputType.number,
              autofocus: true,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
              decoration: const InputDecoration(
                labelText: 'إجمالي النقدية المعدودة بالدرج فعلياً (ج.م)',
                prefixIcon: Icon(Icons.point_of_sale, size: 26, color: AppColors.primary),
                hintText: 'مثال: 7250',
              ),
            ),
            const SizedBox(height: 14),

            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'ملاحظات تقفيل الوردية (اختياري)',
                prefixIcon: Icon(Icons.notes),
                hintText: 'مثال: تم سداد 200 ج فاتورة كهرباء من الدرج',
              ),
            ),
            const SizedBox(height: 24),

            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.alertRed,
                padding: const EdgeInsets.symmetric(vertical: 18),
              ),
              onPressed: _calculateAndCloseShift,
              icon: const Icon(Icons.lock_outline),
              label: const Text('إغلاق الوردية واستخراج تقرير الجرد النهائي 🧾', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }

  /// 2. عرض تقرير Z-Report النهائي الملون بعد الجرد
  Widget _buildZReportResultCard(Map<String, dynamic> report) {
    final diff = report['difference'] as double;
    final isShortage = report['isShortage'] as bool;
    final isSurplus = report['isSurplus'] as bool;

    final Color statusColor = isShortage
        ? AppColors.alertRed
        : (isSurplus ? AppColors.transferBlue : AppColors.receiveGreen);

    final String statusTitle = isShortage
        ? '⚠️ يوجد عجز في الدرج'
        : (isSurplus ? 'ℹ️ يوجد زيادة نقدية في الدرج' : '✅ النقدية مطابقة تماماً (جرد سليم 100%)');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // شارة النتيجة
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: statusColor, width: 1.5),
              ),
              child: Row(
                children: [
                  Icon(
                    isShortage ? Icons.error_outline : (isSurplus ? Icons.info_outline : Icons.check_circle_outline),
                    color: statusColor,
                    size: 36,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(statusTitle, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: statusColor)),
                        const SizedBox(height: 4),
                        Text(
                          isShortage
                              ? 'قيمة العجز المطلوب توريده من الكاشير: ${_numFormat.format(diff.abs())} ج.م'
                              : (isSurplus
                                  ? 'قيمة الزيادة المسجلة في الخزنة: +${_numFormat.format(diff)} ج.م'
                                  : 'المبلغ الفعلي في الدرج مساوي للمبلغ المحسوب بالسيستم بالمليم.'),
                          style: TextStyle(color: statusColor, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 32),

            // تفاصيل بون الـ Z-Report
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey.shade300),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6),
                ],
              ),
              child: Column(
                children: [
                  Text(report['marketName'], style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                  const SizedBox(height: 2),
                  const Text('تقرير إغلاق الوردية وجرد الكاشير (Z-Report)', style: TextStyle(fontSize: 12, color: Colors.black54)),
                  const Text('----------------------------------------------------', style: TextStyle(color: Colors.black38)),
                  _receiptRow('رقم التقرير:', report['shiftId']),
                  _receiptRow('الكاشير المسؤول:', report['cashierName']),
                  _receiptRow('بداية الوردية:', DateFormat('yyyy/MM/dd hh:mm a').format(report['startTime'])),
                  _receiptRow('إغلاق الوردية:', DateFormat('yyyy/MM/dd hh:mm a').format(report['endTime'])),
                  const Text('----------------------------------------------------', style: TextStyle(color: Colors.black38)),
                  _receiptRow('العهدة الافتتاحية (الفكة):', '${_numFormat.format(report['openingCash'])} ج.م'),
                  _receiptRow('مبيعات الوردية الإجمالية:', '${_numFormat.format(report['supermarketSales'])} ج.م'),
                  _receiptRow('أرباح البضاعة الصافية:', '${_numFormat.format(report['supermarketProfit'])} ج.م'),
                  const Text('----------------------------------------------------', style: TextStyle(color: Colors.black38)),
                  _receiptRow('النقدية المفترضة دفترياً:', '${_numFormat.format(report['expectedCash'])} ج.م'),
                  _receiptRow('النقدية الفعلية بعد العد:', '${_numFormat.format(report['actualCash'])} ج.م', isBold: true),
                  _receiptRow(
                    'الفارق (عجز / زيادة):',
                    '${_numFormat.format(diff)} ج.م',
                    isBold: true,
                    customColor: statusColor,
                  ),
                  if (report['notes'].toString().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text('ملاحظة: ${report['notes']}', style: const TextStyle(fontSize: 11, color: Colors.black87)),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: const Text('الرجوع للرئيسية'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('🖨️ جاري طباعة تقرير تقفيل الوردية (Z-Report) على طابعة البونات...'),
                          backgroundColor: AppColors.receiveGreen,
                        ),
                      );
                    },
                    icon: const Icon(Icons.print),
                    label: const Text('طباعة تقرير Z-Report'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoSummaryItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color)),
      ],
    );
  }

  Widget _receiptRow(String label, String val, {bool isBold = false, Color? customColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: Colors.black87, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(
            val,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isBold ? FontWeight.w900 : FontWeight.bold,
              color: customColor ?? Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}