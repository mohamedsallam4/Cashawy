import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.windows:
        return web;
      default:
        return web;
    }
  }

  // إعدادات الويب واللاب توب
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBoL3AtBXSKhO9H5Feoj2guP5yfhnFFEDs',
    appId: '1:19752277378:web:cef186978fa9aacb7aab9b',
    messagingSenderId: '19752277378',
    projectId: 'cashawy',
    authDomain: 'cashawy.firebaseapp.com',
    storageBucket: 'cashawy.firebasestorage.app',
  );

  // إعدادات تطبيق الموبايل (Android)
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBoL3AtBXSKhO9H5Feoj2guP5yfhnFFEDs',
    appId: '1:19752277378:android:1d658696ebba54697aab9b',
    messagingSenderId: '19752277378',
    projectId: 'cashawy',
    storageBucket: 'cashawy.firebasestorage.app',
  );
}