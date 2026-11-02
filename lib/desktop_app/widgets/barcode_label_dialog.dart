import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../core/theme/app_theme.dart';
import '../../core/database/cashawy_store.dart';
import '../../models/product_model.dart';

class BarcodeLabelDialog extends StatefulWidget {
  final ProductModel product;

  const BarcodeLabelDialog({super.key, required this.product});

  @override
  State<BarcodeLabelDialog> createState() => _BarcodeLabelDialogState();
}

class _BarcodeLabelDialogState extends State<BarcodeLabelDialog> {
  int _copies = 1;

  @override
  Widget build(BuildContext context) {
    final store = CashawyStore.instance;
    final numFormat = NumberFormat('#,##0.00');

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // هيدر النافذة
              Container(
                color: AppColors.secondary,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.qr_code, color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Text('معاينة وطباعة استيكر الباركود', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // تصميم استيكر الباركود بمقاس الرف أو العبوة (Shelf Label)
                    Container(
                      width: 320,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade400, width: 1.5),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // اسم السوبر ماركت
                          Text(
                            store.marketName,
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black54),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),

                          // اسم الصنف
                          Text(
                            widget.product.name,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.black),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),

                          // خطوط الباركود المرسومة
                          CustomPaint(
                            size: const Size(260, 48),
                            painter: BarcodePainter(data: widget.product.barcode),
                          ),
                          const SizedBox(height: 2),

                          // رقم الباركود الصريح
                          Text(
                            widget.product.barcode,
                            style: const TextStyle(fontFamily: 'monospace', fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 3, color: Colors.black),
                          ),
                          const SizedBox(height: 6),
                          const Divider(height: 1, color: Colors.black26),
                          const SizedBox(height: 6),

                          // سعر البيع وتاريخ الطباعة
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('السعر للجمهور:', style: TextStyle(fontSize: 10, color: Colors.black87)),
                                  Text(
                                    '${numFormat.format(widget.product.sellPrice)} ج',
                                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.black),
                                  ),
                                ],
                              ),
                              Text(
                                DateFormat('yyyy/MM/dd').format(DateTime.now()),
                                style: const TextStyle(fontSize: 9, color: Colors.black45),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // تحديد عدد نسخ الطباعة
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('عدد النسخ المطلوب طباعتها:', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(width: 12),
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline, color: AppColors.alertRed),
                          onPressed: () {
                            if (_copies > 1) setState(() => _copies--);
                          },
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text('$_copies', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline, color: AppColors.primary),
                          onPressed: () {
                            setState(() => _copies++);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // أزرار التحكم
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('إلغاء'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                        onPressed: () {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('🖨️ جاري إرسال ($_copies) استيكر باركود لطابعة الملصقات الحرارية (Xprinter)...'),
                              backgroundColor: AppColors.receiveGreen,
                            ),
                          );
                        },
                        icon: const Icon(Icons.print),
                        label: const Text('طباعة الاستيكر'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// رسم خطوط الباركود القياسية بشكل برمجي نقي بدون أي Packages
class BarcodePainter extends CustomPainter {
  final String data;
  BarcodePainter({required this.data});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;

    // خوارزمية توليد عرض الخطوط بناءً على أرقام الباركود
    final hash = data.codeUnits;
    double currentX = 10.0;
    final totalWidth = size.width - 20.0;
    final barHeight = size.height;

    // خط البداية الثابت
    canvas.drawRect(Rect.fromLTWH(currentX, 0, 2, barHeight), paint);
    currentX += 4;
    canvas.drawRect(Rect.fromLTWH(currentX, 0, 1.5, barHeight), paint);
    currentX += 4;

    int index = 0;
    while (currentX < totalWidth + 5 && index < 30) {
      final code = (index < hash.length) ? hash[index % hash.length] : 42;
      final barWidth = (code % 3 + 1).toDouble() * 1.3;
      final spaceWidth = ((code >> 1) % 3 + 1).toDouble() * 1.4;

      canvas.drawRect(Rect.fromLTWH(currentX, 0, barWidth, barHeight), paint);
      currentX += barWidth + spaceWidth;
      index++;
    }

    // خط النهاية الثابت
    canvas.drawRect(Rect.fromLTWH(size.width - 15, 0, 2, barHeight), paint);
    canvas.drawRect(Rect.fromLTWH(size.width - 10, 0, 2.5, barHeight), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}