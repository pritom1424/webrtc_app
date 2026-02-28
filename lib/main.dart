import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webrtc_app/core/services/notification_service.dart';
import 'package:webrtc_app/core/theme/app_theme.dart';
import 'package:webrtc_app/features/auth/screen/login_screen.dart';
import 'package:webrtc_app/root_screen.dart';
import 'firebase_options.dart';
import 'features/auth/screen/splash_screen.dart';
import 'package:webrtc_app/core/constants/app_nav_paths.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await NotificationService.instance.initialize();
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BDCOM',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: SplashScreen(),
      routes: {
        AppNavPaths.loginPage: (context) => LoginScreen(),
        AppNavPaths.rootPage: (context) => RootScreen(),
      },
    );
  }
}
