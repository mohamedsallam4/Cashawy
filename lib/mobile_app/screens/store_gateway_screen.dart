import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../core/theme/app_theme.dart';
import '../services/store_gateway_listener.dart';

class StoreGatewayScreen extends StatefulWidget {
  const StoreGatewayScreen({super.key});

  @override
  State<StoreGatewayScreen> createState() => _StoreGatewayScreenState();
}

class _StoreGatewayScreenState extends State<StoreGatewayScreen> {
  bool _isListening = false;
  final List _localLogs = [];
  final TextEditingController _deviceNameCtrl = TextEditingController(text: 'تليفون كاشير 1');

  // رمز الأدمن الافتراضي للحماية الميدانية ضد عبث العمال
  final String _adminPin = '1234';

  @override
  void initState() {
    super.initState();
    _activateGateway();
  }

  @override
  void dispose() {
    _deviceNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _activateGateway() async {
    final success = await StoreGatewayListener.startListening();
    setState(() {
      _isListening = success;
    });

    _addLog(
      title: success ? 'بوابة المحل نشطة ومحمية ⚡' : 'فشل طلب تصاريح الرسائل',
      subtitle: success
          ? 'الهاتف (${_deviceNameCtrl.text}) يرصد الرسائل ويرفعها فوراً لرادار المالك'
          : 'يرجى تفعيل صلاحية قراءة الرسائل من إعدادات الهاتف',
      isSuccess: success,
    );
  }

  void _addLog({required String title, required String subtitle, required bool isSuccess}) {
    if (!mounted) return;
    setState(() {
      _localLogs.insert(0, {
        'title': title,
        'subtitle': subtitle,
        'time': DateFormat('hh:mm:ss a').format(DateTime.now()),
        'isSuccess': isSuccess,
      });
    });
  }

  void _verifyAdminAction(VoidCallback onAuthorized, {String title = 'مطلوب إذن المالك 🔒'}) {
    final pinCtrl = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'هذا الإجراء مقفل لمنع التلاعب بسجل الشرايح. أدخل رقم الـ PIN:',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: pinCtrl,
              autofocus: true,
              obscureText: true,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'رمز الأدمن',
                labelStyle: TextStyle(color: Colors.white60),
                prefixIcon: Icon(Icons.password, color: AppColors.primary),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () {
              if (pinCtrl.text.trim() == _adminPin) {
                Navigator.pop(ctx);
                onAuthorized();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('❌ الرمز غير صحيح! محاولة غير مصرح بها.'),
                    backgroundColor: AppColors.alertRed,
                  ),
                );
              }
            },
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
  }

  void _showChangeDeviceNameDialog() {
    _verifyAdminAction(() {
      final tempCtrl = TextEditingController(text: _deviceNameCtrl.text);
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Text('تحديد اسم أو رقم هاتف الشريحة', style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: tempCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'مثال: تليفون كاشير 1، محفظة خط 010 الرئيسية',
              labelStyle: TextStyle(color: Colors.white60),
              prefixIcon: Icon(Icons.phonelink_setup, color: AppColors.primary),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء', style: TextStyle(color: Colors.white60))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: () {
                if (tempCtrl.text.trim().isNotEmpty) {
                  setState(() => _deviceNameCtrl.text = tempCtrl.text.trim());
                  Navigator.pop(ctx);
                  _addLog(
                    title: 'تم تحديث اسم البوابة',
                    subtitle: 'الجهاز يسجل العمليات الآن باسم: ${_deviceNameCtrl.text}',
                    isSuccess: true,
                  );
                }
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // منع الخروج بزر الرجوع إلا برقم الأدمن السري
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _verifyAdminAction(() {
            Navigator.of(context).pop();
          }, title: 'الخروج من وضع البوابة ⚠️');
        }
      },
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: const Color(0xFF0F172A),
          appBar: AppBar(
            backgroundColor: const Color(0xFF1E293B),
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.lock, color: Colors.white70),
              tooltip: 'الخروج مقفل برقم سري',
              onPressed: () {
                _verifyAdminAction(() => Navigator.of(context).pop(), title: 'الخروج من وضع البوابة ⚠️');
              },
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('بوابة رصد الشرايح المباشرة', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                Text('المعرف: ${_deviceNameCtrl.text}', style: const TextStyle(fontSize: 11, color: AppColors.primary)),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_note, color: Colors.white),
                tooltip: 'تغيير اسم الهاتف (محمي)',
                onPressed: _showChangeDeviceNameDialog,
              ),
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white),
                tooltip: 'إعادة تهيئة الاستماع',
                onPressed: _activateGateway,
              ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _isListening ? AppColors.receiveGreen : AppColors.alertRed,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: _isListening ? AppColors.receiveGreen : AppColors.alertRed,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: _isListening ? AppColors.receiveGreen : AppColors.alertRed,
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isListening ? 'الرادار يعمل ومحصّن ضد الإيقاف 🛡️' : 'البوابة غير متصلة ⚠️',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: _isListening ? AppColors.receiveGreen : AppColors.alertRed,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _isListening
                                  ? 'أي رسالة تصل إلى هذا الهاتف ستُرفع فوراً إلى السحابة مع البصمة الرقمية.'
                                  : 'اضغط على زر التحديث لمنح صلاحيات الرسائل لتفعيل الرصد.',
                              style: const TextStyle(fontSize: 11, color: Colors.white60),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Row(
                  children: [
                    Icon(Icons.history, size: 18, color: Colors.white70),
                    SizedBox(width: 6),
                    Text('سجل النشاط اللحظي للشريحة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
                  ],
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: _localLogs.isEmpty
                      ? const Center(
                          child: Text('في انتظار وصول رسائل SMS على هذا الهاتف...', style: TextStyle(color: Colors.white38, fontSize: 12)),
                        )
                      : ListView.separated(
                          itemCount: _localLogs.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final log = _localLogs[index];
                            final isSuccess = log['isSuccess'] as bool;
                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E293B),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white10),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    isSuccess ? Icons.check_circle_outline : Icons.error_outline,
                                    color: isSuccess ? AppColors.receiveGreen : AppColors.alertRed,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(log['title'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white)),
                                        const SizedBox(height: 2),
                                        Text(log['subtitle'], style: const TextStyle(fontSize: 11, color: Colors.white60)),
                                      ],
                                    ),
                                  ),
                                  Text(log['time'], style: const TextStyle(fontSize: 10, color: Colors.white38)),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}