import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/database/cashawy_store.dart';

class MarketSettingsScreen extends StatefulWidget {
  const MarketSettingsScreen({super.key});

  @override
  State<MarketSettingsScreen> createState() => _MarketSettingsScreenState();
}

class _MarketSettingsScreenState extends State<MarketSettingsScreen> {
  final CashawyStore _store = CashawyStore.instance;

  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _addressCtrl;
  late TextEditingController _licenseCtrl;
  late TextEditingController _cashierCtrl;
  late TextEditingController _adminPinCtrl;
  late TextEditingController _footerMsgCtrl;
  late TextEditingController _policyCtrl;
  late TextEditingController _taxCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: _store.marketName);
    _phoneCtrl = TextEditingController(text: _store.marketPhone);
    _addressCtrl = TextEditingController(text: _store.marketAddress);
    _licenseCtrl = TextEditingController(text: _store.licenseKey);
    _cashierCtrl = TextEditingController(text: _store.activeCashier);
    _adminPinCtrl = TextEditingController(); // تركه فارغاً كإجراء أمني للحفاظ على الرمز المشفر
    _footerMsgCtrl = TextEditingController(text: _store.receiptFooterMessage);
    _policyCtrl = TextEditingController(text: _store.returnPolicyNote);
    _taxCtrl = TextEditingController(text: _store.taxAndCommercialReg);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _licenseCtrl.dispose();
    _cashierCtrl.dispose();
    _adminPinCtrl.dispose();
    _footerMsgCtrl.dispose();
    _policyCtrl.dispose();
    _taxCtrl.dispose();
    super.dispose();
  }

  void _saveSettings() {
    _store.updateMarketLicense(
      name: _nameCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      address: _addressCtrl.text.trim(),
      license: _licenseCtrl.text.trim(),
      cashier: _cashierCtrl.text.trim(),
      newAdminPin: _adminPinCtrl.text.trim(),
      footerMessage: _footerMsgCtrl.text.trim(),
      policyNote: _policyCtrl.text.trim(),
      taxInfo: _taxCtrl.text.trim(),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ تم حفظ كافة إعدادات السوبر ماركت وتخصيص الفاتورة وتأمين الأدمن بنجاح!'),
        backgroundColor: AppColors.receiveGreen,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.admin_panel_settings, color: Colors.white),
            SizedBox(width: 8),
            Text('إعدادات الهوية، الفاتورة، وتأمين النظام'),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. كارت هوية الفرع والكاشير
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: AppColors.primary,
                              child: Icon(Icons.storefront, color: Colors.white, size: 22),
                            ),
                            SizedBox(width: 12),
                            Text('بيانات السوبر ماركت والفرع', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          ],
                        ),
                        const Divider(height: 24),
                        TextField(
                          controller: _nameCtrl,
                          decoration: const InputDecoration(labelText: 'اسم السوبر ماركت التجاري', prefixIcon: Icon(Icons.business)),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _phoneCtrl,
                                decoration: const InputDecoration(labelText: 'هاتف المحل / الدليفري', prefixIcon: Icon(Icons.phone)),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: _cashierCtrl,
                                decoration: const InputDecoration(labelText: 'اسم الكاشير الافتراضي', prefixIcon: Icon(Icons.badge_outlined)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _addressCtrl,
                          decoration: const InputDecoration(labelText: 'عنوان الفرع بالكامل', prefixIcon: Icon(Icons.location_on_outlined)),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 2. كارت تخصيص بون الفاتورة الحرارية
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: AppColors.transferBlue,
                              child: Icon(Icons.receipt_long, color: Colors.white, size: 22),
                            ),
                            SizedBox(width: 12),
                            Text('تخصيص الفاتورة الورقية (بون الكاشير)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          ],
                        ),
                        const Divider(height: 24),
                        TextField(
                          controller: _taxCtrl,
                          decoration: const InputDecoration(
                            labelText: 'بيانات السجل التجاري والبطاقة الضريبية (تظهر أعلى الفاتورة)',
                            prefixIcon: Icon(Icons.assignment_outlined),
                            hintText: 'مثال: س.ت: 10492 | ب.ض: 582-901',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _footerMsgCtrl,
                          decoration: const InputDecoration(
                            labelText: 'رسالة الترحيب والشكر (تظهر بأسفل الفاتورة)',
                            prefixIcon: Icon(Icons.sentiment_very_satisfied),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _policyCtrl,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'سياسة الاستبدال والاسترجاع المطبوعة للعميل',
                            prefixIcon: Icon(Icons.policy_outlined),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 3. كارت الأمان وكلمة المرور
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: AppColors.alertRed,
                              child: Icon(Icons.security, color: Colors.white, size: 22),
                            ),
                            SizedBox(width: 12),
                            Text('أمان النظام والرقم السري للأدمن', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          ],
                        ),
                        const Divider(height: 24),
                        TextField(
                          controller: _adminPinCtrl,
                          keyboardType: TextInputType.number,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'تعيين رقم سري جديد للأدمن (Admin PIN)',
                            hintText: 'اتركه فارغاً للإبقاء على الرقم الحالي',
                            prefixIcon: Icon(Icons.password),
                            helperText: 'يستخدم لفتح شاشات الأرباح، التصفير، والمخزن عند تفعيل وضع الكاشير',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _licenseCtrl,
                          decoration: const InputDecoration(
                            labelText: 'كود ترخيص النسخة (License Key)',
                            prefixIcon: Icon(Icons.key),
                          ),
                        ),
                        const SizedBox(height: 16),
                        ListTile(
                          tileColor: _store.isDarkMode ? Colors.black26 : const Color(0xFFF1F5F9),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          leading: Icon(_store.isDarkMode ? Icons.dark_mode : Icons.light_mode, color: AppColors.primary),
                          title: const Text('الوضع الليلي الفخم (Dark Mode)', style: TextStyle(fontWeight: FontWeight.bold)),
                          trailing: Switch(
                            value: _store.isDarkMode,
                            activeColor: AppColors.primary,
                            onChanged: (_) => _store.toggleThemeMode(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: _saveSettings,
                  icon: const Icon(Icons.save),
                  label: const Text('حفظ كافة الإعدادات واعتماد التعديلات', style: TextStyle(fontSize: 16)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}