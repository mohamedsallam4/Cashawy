import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';

class OwnerRadarNotifier {
  static StreamSubscription? _subscription;
  static bool _isFirstLoad = true;
  static const String _storeId = 'supermarket_main_branch';

  /// تشغيل الاستماع الصوتي فور تسجيل دخول المالك
  static void startListening() {
    _subscription?.cancel();
    _isFirstLoad = true;

    _subscription = FirebaseFirestore.instance
        .collection('stores')
        .doc(_storeId)
        .collection('live_transactions')
        .orderBy('timestamp', descending: true)
        .limit(1)
        .snapshots()
        .listen((snapshot) {
      // نتجاهل أول جلب للبيانات عند فتح البرنامج لكي لا يرن على فواتير قديمة
      if (_isFirstLoad) {
        _isFirstLoad = false;
        return;
      }

      if (snapshot.docChanges.isNotEmpty) {
        for (final change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.added) {
            // إطلاق اهتزاز قوي وصوت تنبيه مباشر
            HapticFeedback.heavyImpact();
            SystemSound.play(SystemSoundType.alert);
          }
        }
      }
    });
  }

  static void stopListening() {
    _subscription?.cancel();
    _subscription = null;
  }
}