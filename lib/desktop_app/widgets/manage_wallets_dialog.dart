import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../core/theme/app_theme.dart';
import '../../core/database/cashawy_store.dart';
import '../../core/theme/parsers/cash_sms_parser.dart';
import '../../models/wallet_model.dart';

class ManageWalletsDialog extends StatefulWidget {
  const ManageWalletsDialog({super.key});

  @override
  State<ManageWalletsDialog> createState() => _ManageWalletsDialogState();
}

class _ManageWalletsDialogState extends State<ManageWalletsDialog> {
  final CashawyStore _store = CashawyStore.instance;
  final NumberFormat _numFormat = NumberFormat('#,##0.00');

  void _showAddWalletModal() {
    final titleCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final balanceCtrl = TextEditingController(text: '0');
    final pinCtrl = TextEditingController();
    WalletProvider selectedProvider = WalletProvider.vodafone;
    int simSlot = 0;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final isInsta = selectedProvider == WalletProvider.instapay;

          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  Icon(
                    isInsta
                        ? Icons.account_balance
                        : Icons.account_balance_wallet,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isInsta
                        ? 'إضافة حساب إنستاباي بنكي (InstaPay)'
                        : 'إضافة محفظة كاش جديدة',
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<WalletProvider>(
                        value: selectedProvider,
                        decoration: const InputDecoration(
                          labelText: 'النوع / الشبكة',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: WalletProvider.vodafone,
                            child: Text('فودافون كاش (Vodafone Cash)'),
                          ),
                          DropdownMenuItem(
                            value: WalletProvider.instapay,
                            child: Text('إنستاباي (InstaPay / حساب بنكي)'),
                          ),
                          DropdownMenuItem(
                            value: WalletProvider.orange,
                            child: Text('أورنج كاش (Orange Cash)'),
                          ),
                          DropdownMenuItem(
                            value: WalletProvider.etisalat,
                            child: Text('اتصالات كاش (Etisalat Cash)'),
                          ),
                          DropdownMenuItem(
                            value: WalletProvider.we,
                            child: Text('وي باي (WE Pay)'),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() {
                              selectedProvider = val;
                              if (val == WalletProvider.instapay &&
                                  titleCtrl.text.isEmpty) {
                                titleCtrl.text = 'إنستاباي - البنك الأهلي';
                              }
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: titleCtrl,
                        decoration: InputDecoration(
                          labelText: isInsta
                              ? 'اسم الحساب المميز (مثال: إنستاباي بنك مصر)'
                              : 'اسم الخط (مثال: فودافون كاش 2)',
                          prefixIcon: const Icon(Icons.badge_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: phoneCtrl,
                        keyboardType: isInsta
                            ? TextInputType.text
                            : TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: isInsta
                              ? 'عنوان الدفع اللحظي (IPA) أو رقم الهاتف المسجل'
                              : 'رقم الشريحة (11 رقم)',
                          hintText: isInsta
                              ? 'market@instapay أو 010...'
                              : '01012345678',
                          prefixIcon: Icon(
                            isInsta
                                ? Icons.alternate_email
                                : Icons.phone_android,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: balanceCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'الرصيد الفعلي الحالي (ج.م)',
                          prefixIcon: Icon(Icons.monetization_on_outlined),
                        ),
                      ),
                      if (!isInsta) ...[
                        const SizedBox(height: 12),
                        TextField(
                          controller: pinCtrl,
                          obscureText: true,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'الرقم السري للمحفظة (للتحويل السريع)',
                            prefixIcon: Icon(Icons.lock_outline),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: ChoiceChip(
                                label: const Center(
                                  child: Text('SIM 1 (الشريحة الأولى)'),
                                ),
                                selected: simSlot == 0,
                                onSelected: (_) =>
                                    setDialogState(() => simSlot = 0),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ChoiceChip(
                                label: const Center(
                                  child: Text('SIM 2 (الشريحة الثانية)'),
                                ),
                                selected: simSlot == 1,
                                onSelected: (_) =>
                                    setDialogState(() => simSlot = 1),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                  ),
                  onPressed: () {
                    final title = titleCtrl.text.trim();
                    final identifier = phoneCtrl.text.trim();
                    final balance =
                        double.tryParse(balanceCtrl.text.trim()) ?? 0.0;

                    if (title.isNotEmpty && identifier.isNotEmpty) {
                      _store.addNewWallet(
                        WalletModel(
                          id: 'w_${DateTime.now().millisecondsSinceEpoch}',
                          phoneNumber: identifier,
                          title: title,
                          provider: selectedProvider,
                          simSlot: isInsta ? -1 : simSlot,
                          pinCode: pinCtrl.text.trim(),
                          balance: balance,
                        ),
                      );
                      Navigator.pop(ctx);
                      setState(() {});
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '✅ تم إضافة ($title) وتفعيل المزامنة السحابية بنجاح!',
                          ),
                          backgroundColor: AppColors.receiveGreen,
                        ),
                      );
                    }
                  },
                  child: const Text('إضافة واعتماد'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showEditBalanceModal(WalletModel wallet) {
    final ctrl = TextEditingController(text: wallet.balance.toStringAsFixed(2));

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text('تعديل رصيد: ${wallet.title}'),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'الرصيد الفعلي الحالي (جنيه)',
              prefixIcon: Icon(Icons.edit),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
              onPressed: () {
                final val = double.tryParse(ctrl.text.trim());
                if (val != null) {
                  _store.updateSingleWalletBalance(wallet.id, val);
                  Navigator.pop(ctx);
                  setState(() {});
                }
              },
              child: const Text('حفظ التعديل'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditLimitsModal(WalletModel wallet) {
    final dailyTransferCtrl = TextEditingController(
      text: wallet.dailyTransferLimit.toStringAsFixed(0),
    );
    final monthlyTransferCtrl = TextEditingController(
      text: wallet.monthlyTransferLimit.toStringAsFixed(0),
    );
    final dailyReceiveCtrl = TextEditingController(
      text: wallet.dailyReceiveLimit.toStringAsFixed(0),
    );
    final monthlyReceiveCtrl = TextEditingController(
      text: wallet.monthlyReceiveLimit.toStringAsFixed(0),
    );

    String? errorText;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                const Icon(Icons.tune, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(child: Text('حدود الليميت: ${wallet.title}')),
              ],
            ),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'اضبط الحدود حسب حدود الشبكة الفعلية للخط. لا يمكن أن تكون أي قيمة صفر أو أقل.',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: dailyTransferCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'تحويل يومي',
                              prefixIcon: Icon(Icons.arrow_upward),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: monthlyTransferCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'تحويل شهري',
                              prefixIcon: Icon(Icons.calendar_month),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: dailyReceiveCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'استلام يومي',
                              prefixIcon: Icon(Icons.arrow_downward),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: monthlyReceiveCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'استلام شهري',
                              prefixIcon: Icon(Icons.calendar_month),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (errorText != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        errorText!,
                        style: const TextStyle(
                          color: AppColors.alertRed,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () {
                          final isInsta = wallet.isInstaPay;
                          setDialogState(() {
                            dailyTransferCtrl.text = isInsta
                                ? '120000'
                                : '60000';
                            monthlyTransferCtrl.text = isInsta
                                ? '400000'
                                : '200000';
                            dailyReceiveCtrl.text = isInsta
                                ? '120000'
                                : '100000';
                            monthlyReceiveCtrl.text = isInsta
                                ? '400000'
                                : '200000';
                          });
                        },
                        icon: const Icon(Icons.restore, size: 16),
                        label: const Text('استعادة الحدود الافتراضية للشبكة'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                ),
                onPressed: () {
                  final dailyTransfer =
                      double.tryParse(dailyTransferCtrl.text.trim()) ?? 0.0;
                  final monthlyTransfer =
                      double.tryParse(monthlyTransferCtrl.text.trim()) ?? 0.0;
                  final dailyReceive =
                      double.tryParse(dailyReceiveCtrl.text.trim()) ?? 0.0;
                  final monthlyReceive =
                      double.tryParse(monthlyReceiveCtrl.text.trim()) ?? 0.0;

                  if (dailyTransfer <= 0 ||
                      monthlyTransfer <= 0 ||
                      dailyReceive <= 0 ||
                      monthlyReceive <= 0) {
                    setDialogState(
                      () => errorText =
                          'كل الحدود يجب أن تكون أرقاماً أكبر من صفر.',
                    );
                    return;
                  }

                  if (dailyTransfer > monthlyTransfer) {
                    setDialogState(
                      () => errorText =
                          'الحد اليومي للتحويل لا يمكن أن يكون أكبر من الشهري.',
                    );
                    return;
                  }

                  if (dailyReceive > monthlyReceive) {
                    setDialogState(
                      () => errorText = 'الحد اليومي للاستلام لا يمكن أن يكون أكبر من الشهري.',
                    );
                    return;
                  }

                  _store.updateWalletLimits(
                    walletId: wallet.id,
                    dailyTransferLimit: dailyTransfer,
                    monthlyTransferLimit: monthlyTransfer,
                    dailyReceiveLimit: dailyReceive,
                    monthlyReceiveLimit: monthlyReceive,
                  );

                  Navigator.pop(ctx);
                  setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ تم تحديث حدود الليميت بنجاح'),
                      backgroundColor: AppColors.receiveGreen,
                    ),
                  );
                },
                child: const Text('حفظ الحدود'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalWalletsMoney = _store.wallets.fold(
      0.0,
      (sum, w) => sum + w.balance,
    );

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720, maxHeight: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // هيدر النافذة
              Container(
                color: AppColors.secondary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.account_balance_wallet,
                          color: Colors.white,
                          size: 24,
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'إدارة محافظ الكاش وحسابات إنستاباي',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              'إجمالي أرصدة الحسابات: ${_numFormat.format(totalWalletsMoney)} ج.م',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // شريط إضافة حساب جديد
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'الحسابات المسجلة (${_store.wallets.length})',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                      ),
                      onPressed: _showAddWalletModal,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('إضافة محفظة / إنستاباي +'),
                    ),
                  ],
                ),
              ),

              // قائمة الحسابات
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _store.wallets.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final w = _store.wallets[index];
                    final isInsta = w.provider == WalletProvider.instapay;

                    Color badgeColor = AppColors.vodafoneRed;
                    IconData badgeIcon = Icons.bolt;

                    if (isInsta) {
                      badgeColor = const Color(
                        0xFF6B21A8,
                      ); // لون بنفسجي مميز لإنستاباي
                      badgeIcon = Icons.account_balance;
                    } else if (w.provider == WalletProvider.orange) {
                      badgeColor = Colors.deepOrange;
                      badgeIcon = Icons.wifi_tethering;
                    } else if (w.provider == WalletProvider.etisalat) {
                      badgeColor = const Color(0xFF15803D);
                      badgeIcon = Icons.phone_android;
                    }

                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: badgeColor.withValues(alpha: 0.15),
                            child: Icon(badgeIcon, color: badgeColor, size: 22),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      w.title,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: badgeColor.withValues(
                                          alpha: 0.1,
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        isInsta
                                            ? 'InstaPay'
                                            : 'SIM ${w.simSlot + 1}',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: badgeColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  w.phoneNumber,
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 12,
                                    color: Colors.black54,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'تحويل: يومي ${_numFormat.format(w.usedDailyTransfer.toInt())}/${_numFormat.format(w.dailyTransferLimit.toInt())}  •  شهري ${_numFormat.format(w.usedMonthlyTransfer.toInt())}/${_numFormat.format(w.monthlyTransferLimit.toInt())}',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w600,
                                    color:
                                        (w.dailyTransferRemaining <= 0 ||
                                            w.monthlyTransferRemaining <= 0)
                                        ? AppColors.alertRed
                                        : Colors.black54,
                                  ),
                                ),
                                Text(
                                  'استلام: يومي ${_numFormat.format(w.usedDailyReceive.toInt())}/${_numFormat.format(w.dailyReceiveLimit.toInt())}  •  شهري ${_numFormat.format(w.usedMonthlyReceive.toInt())}/${_numFormat.format(w.monthlyReceiveLimit.toInt())}',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w600,
                                    color:
                                        (w.dailyReceiveRemaining <= 0 ||
                                            w.monthlyReceiveRemaining <= 0)
                                        ? AppColors.alertRed
                                        : Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text(
                                'الرصيد الفعلي',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey,
                                ),
                              ),
                              Text(
                                '${_numFormat.format(w.balance)} ج.م',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.primaryDark,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 10),
                          IconButton(
                            tooltip: 'تعديل حدود الليميت',
                            icon: const Icon(
                              Icons.tune,
                              color: AppColors.capitalGold,
                            ),
                            onPressed: () => _showEditLimitsModal(w),
                          ),
                          IconButton(
                            tooltip: 'تعديل الرصيد',
                            icon: const Icon(
                              Icons.edit_note,
                              color: AppColors.transferBlue,
                            ),
                            onPressed: () => _showEditBalanceModal(w),
                          ),
                          if (_store.wallets.length > 1)
                            IconButton(
                              tooltip: 'حذف',
                              icon: const Icon(
                                Icons.delete_outline,
                                color: AppColors.alertRed,
                              ),
                              onPressed: () {
                                setState(() {
                                  _store.deleteWallet(w.id);
                                });
                              },
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  height: 46,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondary,
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('تم واعتماد الحسابات'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
