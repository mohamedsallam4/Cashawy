import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../core/theme/app_theme.dart';
import '../../core/database/cashawy_store.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  final CashawyStore _store = CashawyStore.instance;
  final TextEditingController _restoreJsonController = TextEditingController();
  bool _isProcessing = false;
  String? _lastSavedPath;

  @override
  void dispose() {
    _restoreJsonController.dispose();
    super.dispose();
  }

  Future<void> _handleExport() async {
    setState(() => _isProcessing = true);
    final path = await _store.saveBackupToFile();
    setState(() {
      _isProcessing = false;
      _lastSavedPath = path;
    });

    if (mounted) {
      if (path != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ تم إنشاء النسخة الاحتياطية بنجاح في:\n$path'),
            backgroundColor: AppColors.receiveGreen,
            duration: const Duration(seconds: 4),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ تعذر حفظ الملف، تم نسخ بيانات النسخة الاحتياطية للحافظة.'),
            backgroundColor: AppColors.alertRed,
          ),
        );
      }
    }
  }

  void _handleRestore() {
    final raw = _restoreJsonController.text.trim();
    if (raw.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ يرجى لصق كود النسخة الاحتياطية أولاً!'), backgroundColor: AppColors.alertRed),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد استعادة النسخة الاحتياطية ⚠️'),
        content: const Text(
          'تنبيه هام: استعادة هذه النسخة سيقوم بتحديث جميع المنتجات والفواتير وأرصدة الديون الحالية بالبيانات الموجودة في الملف.\n\nهل أنت متأكد من الاستمرار؟',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.alertRed),
            onPressed: () {
              Navigator.pop(ctx);
              final success = _store.restoreFromJson(raw);
              if (success) {
                _restoreJsonController.clear();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('🎉 تم استرجاع قاعدة البيانات بالكامل بنجاح!'),
                    backgroundColor: AppColors.receiveGreen,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('❌ فشل في قراءة البيانات، الكود غير صالح أو تالف!'),
                    backgroundColor: AppColors.alertRed,
                  ),
                );
              }
            },
            child: const Text('تأكيد الاستعادة الفورية'),
          ),
        ],
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
            Icon(Icons.security_update_good, color: Colors.white),
            SizedBox(width: 8),
            Text('النسخ الاحتياطي وحماية قاعدة البيانات'),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 850),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. بطاقة إنشاء وحفظ النسخة الاحتياطية
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const CircleAvatar(
                              radius: 24,
                              backgroundColor: AppColors.primary,
                              child: Icon(Icons.cloud_upload_outlined, color: Colors.white, size: 28),
                            ),
                            const SizedBox(width: 14),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('إنشاء نسخة احتياطية جديدة (Export Backup)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                                Text('حفظ كامل الأصناف، الفواتير، الديون، وأرصدة الموردين في ملف مستقل', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                              ],
                            ),
                          ],
                        ),
                        const Divider(height: 32),

                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                ),
                                onPressed: _isProcessing ? null : _handleExport,
                                icon: _isProcessing
                                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                    : const Icon(Icons.download_rounded),
                                label: Text(_isProcessing ? 'جاري إنشاء النسخة...' : 'حفظ نسخة في مجلد التنزيلات (Downloads)', style: const TextStyle(fontSize: 15)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
                              ),
                              onPressed: () {
                                final jsonStr = _store.exportBackupJson();
                                Clipboard.setData(ClipboardData(text: jsonStr));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('📋 تم نسخ بيانات قاعدة البيانات بالكامل إلى الحافظة!'), backgroundColor: AppColors.primary),
                                );
                              },
                              icon: const Icon(Icons.copy_all),
                              label: const Text('نسخ كـ JSON'),
                            ),
                          ],
                        ),
                        if (_lastSavedPath != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle, color: AppColors.receiveGreen, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text('المسار المحفوظ: $_lastSavedPath', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryDark)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // 2. بطاقة استرجاع البيانات
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const CircleAvatar(
                              radius: 24,
                              backgroundColor: AppColors.capitalGold,
                              child: Icon(Icons.settings_backup_restore, color: Colors.white, size: 28),
                            ),
                            const SizedBox(width: 14),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('استعادة قاعدة البيانات (Restore Backup)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                                Text('استرجاع البيانات من ملف أو كود النسخة الاحتياطية في حال تغيير الجهاز', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                              ],
                            ),
                          ],
                        ),
                        const Divider(height: 32),

                        TextField(
                          controller: _restoreJsonController,
                          maxLines: 5,
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                          decoration: const InputDecoration(
                            labelText: 'الصق محتوى كود النسخة الاحتياطية (JSON) هنا...',
                            alignLabelWithHint: true,
                            hintText: '{\n  "version": "1.0.0",\n  ...\n}',
                          ),
                        ),
                        const SizedBox(height: 16),

                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.secondary,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            onPressed: _handleRestore,
                            icon: const Icon(Icons.restore),
                            label: const Text('بدء فحص واستعادة البيانات الآن', style: TextStyle(fontSize: 15)),
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
      ),
    );
  }
}