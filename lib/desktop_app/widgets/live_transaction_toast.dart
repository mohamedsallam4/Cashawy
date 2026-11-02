import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../core/theme/app_theme.dart';
import '../../core/services/audio_feedback_service.dart';
import '../../models/transaction_model.dart';
import '../../core/theme/parsers/cash_sms_parser.dart';

class LiveTransactionToast {
  static OverlayEntry? _currentEntry;
  static Timer? _timer;

  static void show(BuildContext context, TransactionModel transaction) {
    _currentEntry?.remove();
    _currentEntry = null;
    _timer?.cancel();

    // تشغيل نغمة التنبيه الصوتي
    AudioFeedbackService.playTransactionAlert();

    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (ctx) => _LiveToastWidget(
        transaction: transaction,
        onDismiss: () {
          entry.remove();
          if (_currentEntry == entry) _currentEntry = null;
        },
      ),
    );

    _currentEntry = entry;
    overlay.insert(entry);
  }
}

class _LiveToastWidget extends StatefulWidget {
  final TransactionModel transaction;
  final VoidCallback onDismiss;

  const _LiveToastWidget({
    required this.transaction,
    required this.onDismiss,
  });

  @override
  State<_LiveToastWidget> createState() => _LiveToastWidgetState();
}

class _LiveToastWidgetState extends State<_LiveToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutBack));

    _fadeAnimation = CurvedAnimation(parent: _animController, curve: Curves.easeIn);

    _animController.forward();

    // الإغلاق التلقائي بعد 5 ثوانٍ بالضبط
    _dismissTimer = Timer(const Duration(seconds: 5), _close);
  }

  void _close() async {
    if (!mounted) return;
    await _animController.reverse();
    widget.onDismiss();
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isReceive = widget.transaction.type == TransactionType.receive;
    final numFormat = NumberFormat('#,##0.00');
    final Color mainColor = isReceive ? AppColors.receiveGreen : AppColors.transferBlue;
    final String typeLabel = isReceive ? 'إشعار استلام كاش 💰' : 'إشعار تحويل كاش 🚀';

    return Positioned(
      top: 24,
      left: 24, // موضع علوي هادئ لا يحجب الأزرار
      child: Material(
        color: Colors.transparent,
        child: SlideTransition(
          position: _slideAnimation,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Container(
                width: 360,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: mainColor.withValues(alpha: 0.35), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: mainColor.withValues(alpha: 0.18),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: mainColor.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isReceive ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                              color: mainColor,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      typeLabel,
                                      style: TextStyle(
                                        color: mainColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                    InkWell(
                                      onTap: _close,
                                      child: const Icon(Icons.close, size: 16, color: Colors.grey),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '${numFormat.format(widget.transaction.amount)} ج.م',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900,
                                        color: mainColor,
                                      ),
                                    ),
                                    Text(
                                      widget.transaction.clientPhone,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                                if (widget.transaction.clientName != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    widget.transaction.clientName!,
                                    style: const TextStyle(fontSize: 11, color: Colors.black54),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    // شريط مؤقت الـ 5 ثوانٍ التنازلي
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 1.0, end: 0.0),
                        duration: const Duration(seconds: 5),
                        builder: (context, value, _) => LinearProgressIndicator(
                          value: value,
                          minHeight: 3.5,
                          backgroundColor: Colors.transparent,
                          valueColor: AlwaysStoppedAnimation<Color>(mainColor),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}