import 'package:flutter/services.dart';

class AudioFeedbackService {
  static void playScanBeep() {
    SystemSound.play(SystemSoundType.click);
  }

  static void playErrorBuzz() {
    SystemSound.play(SystemSoundType.alert);
  }

  static void playCheckoutSuccess() {
    SystemSound.play(SystemSoundType.click);
  }

  /// نغمة تنبيه فوري عند حدوث عملية تحويل أو استلام
  static void playTransactionAlert() {
    SystemSound.play(SystemSoundType.alert);
  }
}