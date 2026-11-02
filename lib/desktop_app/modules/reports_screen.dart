import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../core/theme/app_theme.dart';
import '../../core/database/cashawy_store.dart';
import '../../models/transaction_model.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final CashawyStore _store = CashawyStore.instance;
  final NumberFormat _numFormat = NumberFormat('#,##0.00');
  String _selectedPeriod = 'today'; // 'today', 'week', 'month'

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.analytics_outlined, color: Colors.white),
            SizedBox(width: 8),
            Text('لوحة تقارير وتحليلات المبيعات والأرباح'),
          ],
        ),
        actions: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
            onPressed: () async {
              final result = await _store.exportTransactionsToCsv();
              if (context.mounted && result != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '📊 تم تصدير ملف إكسيل المبيعات بنجاح إلى:\n$result',
                    ),
                    backgroundColor: AppColors.receiveGreen,
                  ),
                );
              }
            },
            icon: const Icon(Icons.table_view_outlined, size: 18),
            label: const Text('تصدير لـ Excel (CSV)'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: ListenableBuilder(
        listenable: _store,
        builder: (context, _) {
          final totalSales = _store.getSalesByPeriod(_selectedPeriod);
          final totalProfit = _store.getProfitsByPeriod(_selectedPeriod);
          final topItems = _store.topSellingItems;

          // حساب نسب طرق الدفع
          final filteredTxs = _store.transactionsByPeriod(_selectedPeriod);

          double cashSales = 0;
          double walletSales = 0;
          double debtSales = 0;

          for (final tx in filteredTxs) {
            if (tx.status == TransactionStatus.debt) {
              debtSales += tx.amount;
            } else if (tx.walletPhone.startsWith('01')) {
              walletSales += tx.amount;
            } else {
              cashSales += tx.amount;
            }
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // فلتر الفترات الزمنية
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'نظرة عامة على أداء النشاط',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    Row(
                      children: [
                        _buildPeriodChip('اليوم', 'today'),
                        const SizedBox(width: 8),
                        _buildPeriodChip('آخر 7 أيام', 'week'),
                        const SizedBox(width: 8),
                        _buildPeriodChip('هذا الشهر', 'month'),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // بطاقات المبيعات وصافي الأرباح
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricCard(
                        title: 'إجمالي المبيعات والتحصيلات',
                        amount: totalSales,
                        color: AppColors.primary,
                        icon: Icons.payments_outlined,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _buildMetricCard(
                        title: 'صافي الأرباح المحققة',
                        amount: totalProfit,
                        color: AppColors.capitalGold,
                        icon: Icons.trending_up,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _buildMetricCard(
                        title: 'قيمة بضاعة المخزن الإجمالية',
                        amount: _store.inventoryValue,
                        color: AppColors.purpleAccent,
                        icon: Icons.inventory_2_outlined,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // قسمين: الأصناف الأكثر مبيعاً + طرق الدفع
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // اليمين: الأصناف الأكثر مبيعاً
                    Expanded(
                      flex: 5,
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: const [
                                  Icon(
                                    Icons.star_rounded,
                                    color: AppColors.capitalGold,
                                    size: 24,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'الأصناف الأكثر طلباً ومبيعاً',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 24),
                              if (topItems.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.all(32),
                                  child: Center(
                                    child: Text(
                                      'لا توجد بيانات مبيعات كافية في هذه الفترة',
                                    ),
                                  ),
                                )
                              else
                                ...topItems.entries.map((entry) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(6),
                                              decoration: BoxDecoration(
                                                color: AppColors.primary
                                                    .withValues(alpha: 0.1),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: const Icon(
                                                Icons.shopping_bag,
                                                size: 16,
                                                color: AppColors.primary,
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Text(
                                              entry.key,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF1F5F9),
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          child: Text(
                                            '${entry.value} قطعة مباعة',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                              color: AppColors.primaryDark,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),

                    // الشمال: توزيع طرق السداد
                    Expanded(
                      flex: 5,
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: const [
                                  Icon(
                                    Icons.pie_chart_outline,
                                    color: AppColors.transferBlue,
                                    size: 24,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'توزيع طرق سداد المبيعات',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 24),
                              _buildPaymentMethodRow(
                                'نقدي بالدرج (Cash)',
                                cashSales,
                                AppColors.receiveGreen,
                                Icons.money,
                              ),
                              const SizedBox(height: 12),
                              _buildPaymentMethodRow(
                                'محافظ إلكترونية (كاش)',
                                walletSales,
                                AppColors.transferBlue,
                                Icons.phone_android,
                              ),
                              const SizedBox(height: 12),
                              _buildPaymentMethodRow(
                                'آجل وشكك (ديون في السوق)',
                                debtSales,
                                AppColors.alertRed,
                                Icons.receipt_long,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPeriodChip(String label, String value) {
    final isSel = _selectedPeriod == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSel,
      selectedColor: AppColors.primary,
      labelStyle: TextStyle(
        color: isSel ? Colors.white : Colors.black87,
        fontWeight: FontWeight.bold,
      ),
      onSelected: (_) => setState(() => _selectedPeriod = value),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required double amount,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: color,
                ),
              ),
              Icon(icon, color: color, size: 24),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${_numFormat.format(amount)} ج.م',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodRow(
    String title,
    double amount,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          Text(
            '${_numFormat.format(amount)} ج.م',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
