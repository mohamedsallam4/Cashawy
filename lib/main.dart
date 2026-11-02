import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'core/database/cashawy_store.dart';
import 'desktop_app/widgets/Screens/cashawy_pos_screen.dart';
import 'mobile_app/screens/owner_live_dashboard_screen.dart';
import 'mobile_app/screens/owner_login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const CashawyApp());
}

class CashawyApp extends StatelessWidget {
  const CashawyApp({super.key});

  Widget _getInitialScreen() {
    // 1. الديسكتوب والويب: نقطة بيع السوبر ماركت (POS)
    if (kIsWeb || defaultTargetPlatform == TargetPlatform.windows) {
      return const CashawyPosScreen();
    }

    // 2. الهواتف الذكية (Android / iOS): بوابه مراقبة المالك المؤمنة
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasData && snapshot.data != null) {
          // المالك مسجل دخوله مسبقاً
          return const OwnerLiveDashboardScreen();
        }
        // مستخدم غير مسجل، يفتح شاشة الدخول
        return const OwnerLoginScreen();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: CashawyStore.instance,
      builder: (context, _) {
        final store = CashawyStore.instance;
        return MaterialApp(
          title: store.marketName,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: store.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: _getInitialScreen(),
          ),
        );
      },
    );
  }
}