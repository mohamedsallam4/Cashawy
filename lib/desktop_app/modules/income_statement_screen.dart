import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../core/theme/app_theme.dart';
import '../../core/database/cashawy_store.dart';

class IncomeStatementScreen extends StatefulWidget {
  const IncomeStatementScreen({super.key});

  @override
  State<IncomeStatementScreen> createState() => _IncomeStatementScreenState();
}

class _IncomeStatementScreenState extends State<IncomeStatementScreen> {
  final CashawyStore _store = CashawyStore.instance;
  final NumberFormat _numFormat = NumberFormat('#,##0.00');

  String _selectedPeriod = 'today'; // 'today', 'week', 'month', 'all'

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.request_quote_rounded, color: Colors.white),
            SizedBox(width: 8),
            Text('قائمة الدخل وصافي الأرباح الحقيقي (P&L)'),
          ],
        ),
      ),
      body: ListenableBuilder(
        listenable: _store,
        builder: (context, _) {
          final pnl = _store.getIncomeStatement(_selectedPeriod);

          final grossSales = pnl['grossSales']!;
          final returnsTotal = pnl['returnsTotal']!;
          final netSales = pnl['netSales']!;
          final cogs = pnl['cogs']!;
          final grossMerchandiseProfit = pnl['grossMerchandiseProfit']!;
          final servicesProfit = pnl['servicesProfit']!;
          final totalGrossIncome = pnl['totalGrossIncome']!;
          final operatingExpenses = pnl['operatingExpenses']!;
          final wasteLosses = pnl['wasteLosses']!;
          final netOperatingProfit = pnl['netOperatingProfit']!;
          final netMargin = pnl['netMargin']!;

          final bool isNetPositive = netOperatingProfit >= 0;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 880),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // شريط الفترات الزمنية
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'التقرير المحاسبي لقائمة الدخل',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                        Wrap(
                          spacing: 8,
                          children: [
                            _buildPeriodChip('اليوم', 'today'),
                            _buildPeriodChip('آخر 7 أيام', 'week'),
                            _buildPeriodChip('هذا الشهر', 'month'),
                            _buildPeriodChip('كامل السجل', 'all'),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // بطاقة النتيجة النهائية للنشاط
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isNetPositive
                              ? [const Color(0xFF065F46), const Color(0xFF047857)]
                              : [const Color(0xFF991B1B), const Color(0xFFDC2626)],
                          begin: Alignment.topRight,
                          end: Alignment.bottomLeft,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: (isNetPositive ? AppColors.receiveGreen : AppColors.alertRed).withValues(alpha: 0.25),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'صافي الربح الفعلي النهائي (القابل للسحب الخالص)',
                                style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${_numFormat.format(netOperatingProfit)} ج.م',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 32,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              children: [
                                const Text('هامش صافي الربح', style: TextStyle(color: Colors.white70, fontSize: 11)),
                                Text(
                                  '${netMargin.toStringAsFixed(1)}%',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // جدول بنود قائمة الدخل الرسمية
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(22),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // 1. الإيرادات والمبيعات
                            _buildSectionHeader('1. المبيعات والإيرادات التشغيلية', Icons.storefront),
                            _buildStatementRow('إجمالي مبيعات البضاعة', grossSales, isBold: false),
                            _buildStatementRow('(-) مردودات ومرتجع المبيعات', -returnsTotal, isDeduction: true),
                            const Divider(height: 18),
                            _buildStatementRow('(=) صافي المبيعات التجارية', netSales, isSubtotal: true, color: AppColors.primaryDark),
                            const SizedBox(height: 18),

                            // 2. تكلفة المبيعات
                            _buildSectionHeader('2. تكلفة البضاعة المباعة (COGS)', Icons.shopping_cart_checkout),
                            _buildStatementRow('(-) تكلفة شراء البضاعة المباعة فعلياً من المخزن', -cogs, isDeduction: true),
                            const Divider(height: 18),
                            _buildStatementRow('(=) مجمل الربح من البضاعة (Gross Margin)', grossMerchandiseProfit, isSubtotal: true, color: AppColors.capitalGold),
                            const SizedBox(height: 18),

                            // 3. أرباح الخدمات الرقمية
                            _buildSectionHeader('3. إيرادات وعمولات الخدمات', Icons.phone_android),
                            _buildStatementRow('(+) صافي عمولات تحويل واستلام كاش وفوري وأمان', servicesProfit, isBold: false),
                            const Divider(height: 18),
                            _buildStatementRow('(=) الدخل الإجمالي الشامل للمحل', totalGrossIncome, isSubtotal: true, color: AppColors.transferBlue),
                            const SizedBox(height: 18),

                            // 4. الأعباء والمصروفات
                            _buildSectionHeader('4. المصروفات التشغيلية والخسائر', Icons.money_off),
                            _buildStatementRow('(-) مصروفات ونثريات المحل (كهرباء، أكياس، فطار عمال)', -operatingExpenses, isDeduction: true),
                            _buildStatementRow('(-) خسائر البضاعة التالفة والهالك المخزني', -wasteLosses, isDeduction: true),
                            const Divider(height: 22, thickness: 1.5),

                            // 5. الصافي النهائي
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: isNetPositive ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isNetPositive ? AppColors.receiveGreen : AppColors.alertRed,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        isNetPositive ? Icons.check_circle : Icons.warning_rounded,
                                        color: isNetPositive ? AppColors.receiveGreen : AppColors.alertRed,
                                      ),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'صافي الربح الفعلي المتبقي للنشاط (Net Profit)',
                                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    '${_numFormat.format(netOperatingProfit)} ج.م',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900,
                                      color: isNetPositive ? AppColors.receiveGreen : AppColors.alertRed,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
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

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.secondary),
          const SizedBox(width: 6),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.secondary),
          ),
        ],
      ),
    );
  }

  Widget _buildStatementRow(
    String label,
    double amount, {
    bool isBold = true,
    bool isSubtotal = false,
    bool isDeduction = false,
    Color? color,
  }) {
    final textColor = color ?? (isDeduction ? AppColors.alertRed : Colors.black87);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isSubtotal ? 13 : 12,
              fontWeight: isSubtotal ? FontWeight.bold : (isBold ? FontWeight.w600 : FontWeight.normal),
              color: isSubtotal ? textColor : Colors.black87,
            ),
          ),
          Text(
            '${_numFormat.format(amount)} ج.م',
            style: TextStyle(
              fontSize: isSubtotal ? 15 : 13,
              fontWeight: isSubtotal ? FontWeight.w900 : FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}