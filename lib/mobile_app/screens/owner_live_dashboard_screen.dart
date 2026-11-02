import 'package:cashawy_pro/mobile_app/screens/store_gateway_screen.dart';
import 'package:cashawy_pro/mobile_app/services/owner_radar_notifier.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../core/theme/app_theme.dart';

class OwnerLiveDashboardScreen extends StatefulWidget {
  const OwnerLiveDashboardScreen({super.key});
  @override
  State<OwnerLiveDashboardScreen> createState() =>
      _OwnerLiveDashboardScreenState();
}

class _OwnerLiveDashboardScreenState extends State<OwnerLiveDashboardScreen> {
  final NumberFormat _numFormat = NumberFormat('#,##0.00');
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // معرف الفرع الرئيسي المرتبط بسيستم الكاشير
  final String _storeId = 'supermarket_main_branch';

  @override
  void initState() {
    super.initState();
    // تفعيل الرادار الصوتي والاهتزاز اللحظي فور دخول المالك
    OwnerRadarNotifier.startListening();
  }

  @override
  void dispose() {
    OwnerRadarNotifier.stopListening();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF1F5F9),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: AppColors.secondary,
          title: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: AppColors.receiveGreen,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.receiveGreen,
                      blurRadius: 6,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'رادار المالك المباشر',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'بث حي ومباشر من جهاز الكاشير',
                    style: TextStyle(fontSize: 10, color: Colors.white70),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.phonelink_setup, color: Colors.white),
              tooltip: 'وضع بوابة المحل (SMS Gateway)',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const StoreGatewayScreen()),
                );
              },
            ),
            IconButton(
              icon: const Icon(
                Icons.notifications_active_outlined,
                color: Colors.white,
              ),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      '🔔 الرادار الصوتي نشط ويعمل فورياً مع أي حركة',
                    ),
                  ),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.logout_rounded, color: Colors.white70),
              tooltip: 'تسجيل الخروج',
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
              },
            ),
          ],
        ),
        body: StreamBuilder<DocumentSnapshot>(
          stream: _firestore.collection('stores').doc(_storeId).snapshots(),
          builder: (context, storeSnapshot) {
            if (storeSnapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.cloud_off,
                        size: 48,
                        color: AppColors.alertRed,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'خطأ في الاتصال بالسحابة: ${storeSnapshot.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              );
            }

            if (!storeSnapshot.hasData || !storeSnapshot.data!.exists) {
              return const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: AppColors.primary),
                    SizedBox(height: 16),
                    Text(
                      'جاري الاتصال بجهاز المحل واستلام الإحصائيات...',
                      style: TextStyle(fontSize: 13, color: Colors.black54),
                    ),
                  ],
                ),
              );
            }

            final storeData =
                (storeSnapshot.data!.data() as Map<String, dynamic>?) ?? {};
            final double cashInDrawer = (storeData['cashInDrawer'] ?? 0.0)
                .toDouble();
            final double todaySales = (storeData['todaySales'] ?? 0.0)
                .toDouble();
            final double todayProfits = (storeData['todayProfits'] ?? 0.0)
                .toDouble();
            final double totalCapital = (storeData['totalCapital'] ?? 0.0)
                .toDouble();
            final List<dynamic> rawWallets = storeData['wallets'] ?? [];

            final Timestamp? lastUpdatedTs =
                storeData['lastUpdated'] as Timestamp?;
            final String lastUpdatedStr = lastUpdatedTs != null
                ? DateFormat('hh:mm:ss a').format(lastUpdatedTs.toDate())
                : 'الآن';

            return RefreshIndicator(
              onRefresh: () async {
                setState(() {});
              },
              child: CustomScrollView(
                slivers: [
                  // 1. شريط حالة التحديث اللحظي
                  SliverToBoxAdapter(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      color: AppColors.primary.withValues(alpha: 0.1),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.wifi_tethering,
                                size: 16,
                                color: AppColors.primaryDark,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'البيانات متصلة سحابياً بالسوبر ماركت',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryDark,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            'آخر تحديث: $lastUpdatedStr',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 2. كروت المؤشرات المالية الكبرى
                  SliverPadding(
                    padding: const EdgeInsets.all(14),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _buildKpiCard(
                                  title: 'درج الكاشير الآن',
                                  value:
                                      '${_numFormat.format(cashInDrawer)} ج.م',
                                  icon: Icons.payments,
                                  color: AppColors.receiveGreen,
                                  subText: 'نقدية فعلية بالدرج',
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildKpiCard(
                                  title: 'مبيعات اليوم',
                                  value: '${_numFormat.format(todaySales)} ج.م',
                                  icon: Icons.shopping_basket_rounded,
                                  color: AppColors.transferBlue,
                                  subText: 'إجمالي المحصل اليوم',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: _buildKpiCard(
                                  title: 'صافي الأرباح اليوم',
                                  value:
                                      '${_numFormat.format(todayProfits)} ج.م',
                                  icon: Icons.trending_up,
                                  color: const Color(0xFFB45309),
                                  subText: 'أرباح البضاعة والخدمات',
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildKpiCard(
                                  title: 'إجمالي رأس المال',
                                  value:
                                      '${_numFormat.format(totalCapital)} ج.م',
                                  icon: Icons.account_balance,
                                  color: AppColors.secondary,
                                  subText: 'خزنة + محافظ + بضاعة',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 3. قسم رصد محافظ الكاش وحسابات إنستاباي
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 4,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'أرصدة المحافظ وإنستاباي الحالية',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${rawWallets.length} حسابات مسجلة',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 215,
                      child: rawWallets.isEmpty
                          ? const Center(
                              child: Text(
                                'لا توجد محافظ أو حسابات مسجلة في الفرع',
                              ),
                            )
                          : ListView.builder(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              itemCount: rawWallets.length,
                              itemBuilder: (context, index) {
                                final w =
                                    rawWallets[index] as Map<String, dynamic>;
                                final double balance = (w['balance'] ?? 0.0)
                                    .toDouble();
                                final bool isNearLimit =
                                    w['isNearLimit'] ?? false;
                                final String title = w['title'] ?? 'حساب';
                                final String phone =
                                    (w['phoneNumber'] ?? w['phone'] ?? '')
                                        .toString();
                                final String provider = (w['provider'] ?? '')
                                    .toString()
                                    .toLowerCase();

                                final double dailyTransferLimit =
                                    (w['dailyTransferLimit'] as num?)
                                        ?.toDouble() ??
                                    0.0;
                                final double monthlyTransferLimit =
                                    (w['monthlyTransferLimit'] as num?)
                                        ?.toDouble() ??
                                    0.0;
                                final double dailyReceiveLimit =
                                    (w['dailyReceiveLimit'] as num?)
                                        ?.toDouble() ??
                                    0.0;
                                final double monthlyReceiveLimit =
                                    (w['monthlyReceiveLimit'] as num?)
                                        ?.toDouble() ??
                                    0.0;
                                final double usedDailyTransfer =
                                    (w['usedDailyTransfer'] as num?)
                                        ?.toDouble() ??
                                    0.0;
                                final double usedMonthlyTransfer =
                                    (w['usedMonthlyTransfer'] as num?)
                                        ?.toDouble() ??
                                    0.0;
                                final double usedDailyReceive =
                                    (w['usedDailyReceive'] as num?)
                                        ?.toDouble() ??
                                    0.0;
                                final double usedMonthlyReceive =
                                    (w['usedMonthlyReceive'] as num?)
                                        ?.toDouble() ??
                                    0.0;

                                Color badgeColor = AppColors.vodafoneRed;
                                IconData badgeIcon = Icons.bolt;

                                if (provider == 'instapay' ||
                                    title.contains('إنستاباي') ||
                                    title.toLowerCase().contains('insta')) {
                                  badgeColor = const Color(0xFF6B21A8);
                                  badgeIcon = Icons.account_balance;
                                } else if (provider == 'orange' ||
                                    title.contains('أورنج') ||
                                    title.contains('اورنج')) {
                                  badgeColor = Colors.deepOrange;
                                  badgeIcon = Icons.wifi_tethering;
                                } else if (provider == 'etisalat' ||
                                    title.contains('اتصالات')) {
                                  badgeColor = const Color(0xFF15803D);
                                  badgeIcon = Icons.phone_android;
                                } else if (provider == 'we' ||
                                    title.contains('وي')) {
                                  badgeColor = const Color(0xFF5C2D91);
                                  badgeIcon = Icons.language;
                                }

                                return Container(
                                  width: 245,
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: isNearLimit
                                          ? AppColors.alertRed
                                          : Colors.grey.shade300,
                                      width: isNearLimit ? 1.5 : 1,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.03,
                                        ),
                                        blurRadius: 6,
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              title,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          CircleAvatar(
                                            radius: 12,
                                            backgroundColor: badgeColor,
                                            child: Icon(
                                              badgeIcon,
                                              size: 14,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        phone,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontFamily: 'monospace',
                                          color: Colors.black54,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text(
                                            'الرصيد:',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey,
                                            ),
                                          ),
                                          Text(
                                            '${_numFormat.format(balance)} ج.م',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w900,
                                              fontSize: 15,
                                              color: AppColors.primaryDark,
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (dailyTransferLimit > 0 ||
                                          monthlyTransferLimit > 0 ||
                                          dailyReceiveLimit > 0 ||
                                          monthlyReceiveLimit > 0) ...[
                                        _buildOwnerLimitRow(
                                          label: 'تحويل يومي',
                                          used: usedDailyTransfer,
                                          limit: dailyTransferLimit,
                                          color: AppColors.transferBlue,
                                        ),
                                        _buildOwnerLimitRow(
                                          label: 'استلام يومي',
                                          used: usedDailyReceive,
                                          limit: dailyReceiveLimit,
                                          color: AppColors.receiveGreen,
                                        ),
                                        _buildOwnerLimitRow(
                                          label: 'تحويل شهري',
                                          used: usedMonthlyTransfer,
                                          limit: monthlyTransferLimit,
                                          color: AppColors.transferBlue,
                                        ),
                                        _buildOwnerLimitRow(
                                          label: 'استلام شهري',
                                          used: usedMonthlyReceive,
                                          limit: monthlyReceiveLimit,
                                          color: AppColors.receiveGreen,
                                        ),
                                      ],
                                      if (isNearLimit)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.alertRed
                                                .withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: const Text(
                                            '⚠️ الحساب قارب على الليميت',
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.alertRed,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ),

                  // 4. شريط عنوان البث الحي للعمليات
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(14, 16, 14, 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.stream,
                                size: 18,
                                color: AppColors.transferBlue,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'شريط العمليات والفواتير المباشرة',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            'تحديث تلقائي لحظي',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.receiveGreen,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 5. قائمة العمليات الحية
                  StreamBuilder<QuerySnapshot>(
                    stream: _firestore
                        .collection('stores')
                        .doc(_storeId)
                        .collection('live_transactions')
                        .orderBy('timestamp', descending: true)
                        .limit(25)
                        .snapshots(),
                    builder: (context, txSnapshot) {
                      if (txSnapshot.connectionState ==
                              ConnectionState.waiting &&
                          !txSnapshot.hasData) {
                        return const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        );
                      }

                      final docs = txSnapshot.data?.docs ?? [];
                      if (docs.isEmpty) {
                        return const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.all(32),
                            child: Center(
                              child: Text(
                                'في انتظار تسجيل أول عملية من الكاشير...',
                              ),
                            ),
                          ),
                        );
                      }

                      return SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate((
                            context,
                            index,
                          ) {
                            final tx =
                                (docs[index].data() as Map<String, dynamic>?) ??
                                {};
                            final type = tx['type'] ?? 'receive';
                            final status = tx['status'] ?? 'completed';
                            final double amount = (tx['amount'] ?? 0.0)
                                .toDouble();
                            final String walletPhone = tx['walletPhone'] ?? '';
                            final String clientPhone = tx['clientPhone'] ?? '';
                            final String? clientName = tx['clientName'];
                            final String? notes = tx['notes'];

                            final Timestamp? ts = tx['timestamp'] as Timestamp?;
                            final String timeStr = ts != null
                                ? DateFormat('hh:mm:ss a').format(ts.toDate())
                                : 'الآن';

                            final bool isTransfer = type == 'transfer';
                            final bool isSale = type == 'sale';
                            final bool isDebt = status == 'debt';

                            Color badgeColor = AppColors.primary;
                            IconData iconData = Icons.point_of_sale;
                            String titlePrefix = isSale
                                ? 'فاتورة مبيعات'
                                : 'استلام';

                            if (isDebt) {
                              badgeColor = AppColors.alertRed;
                              iconData = Icons.receipt_long;
                              titlePrefix = 'بيع آجل (شكك)';
                            } else if (status == 'pending') {
                              badgeColor = const Color(0xFF6B21A8);
                              iconData = Icons.schedule;
                              titlePrefix = 'عملية مؤجلة';
                            } else if (walletPhone.contains('إنستاباي') ||
                                walletPhone.toLowerCase().contains('insta')) {
                              badgeColor = const Color(0xFF6B21A8);
                              iconData = Icons.account_balance;
                              titlePrefix = isTransfer
                                  ? 'تحويل إنستاباي'
                                  : 'استلام إنستاباي';
                            } else if (walletPhone.startsWith('01') ||
                                walletPhone.contains('كاش')) {
                              badgeColor = isTransfer
                                  ? AppColors.transferBlue
                                  : AppColors.receiveGreen;
                              iconData = isTransfer
                                  ? Icons.call_made
                                  : Icons.call_received;
                              titlePrefix = isTransfer
                                  ? 'تحويل كاش'
                                  : 'استلام كاش';
                            } else if (walletPhone == 'مصروفات ونثريات') {
                              badgeColor = const Color(0xFFB45309);
                              iconData = Icons.receipt_outlined;
                              titlePrefix = 'مصروف محل';
                            }

                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: badgeColor.withValues(
                                    alpha: 0.12,
                                  ),
                                  child: Icon(
                                    iconData,
                                    color: badgeColor,
                                    size: 20,
                                  ),
                                ),
                                title: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      titlePrefix,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: badgeColor,
                                      ),
                                    ),
                                    Text(
                                      '${_numFormat.format(amount)} ج.م',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 15,
                                        color: badgeColor,
                                      ),
                                    ),
                                  ],
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 2),
                                    Text(
                                      clientName != null &&
                                              clientName.isNotEmpty
                                          ? '$clientName ($clientPhone)'
                                          : (notes ?? clientPhone),
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.black87,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          walletPhone,
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: Colors.grey,
                                          ),
                                        ),
                                        Text(
                                          timeStr,
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: Colors.black45,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }, childCount: docs.length),
                        ),
                      );
                    },
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 30)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildOwnerLimitRow({
    required String label,
    required double used,
    required double limit,
    required Color color,
  }) {
    final percent = limit <= 0
        ? (used > 0 ? 1.0 : 0.0)
        : (used / limit).clamp(0.0, 1.0);
    final exceeded = used > limit + 0.01;
    final activeColor = exceeded ? AppColors.alertRed : color;

    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: exceeded ? AppColors.alertRed : Colors.black54,
                ),
              ),
              Text(
                '${_numFormat.format(used.toInt())} / ${_numFormat.format(limit.toInt())}',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: activeColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: percent,
              minHeight: 3,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(activeColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required String subText,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.black54,
                ),
              ),
              Icon(icon, size: 18, color: color),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subText,
            style: const TextStyle(fontSize: 9, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
