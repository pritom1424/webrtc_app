import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webrtc_app/core/theme/app_theme.dart';
import 'package:webrtc_app/features/auth/screen/login_screen.dart';
import 'package:webrtc_app/features/p2p/screen/user_list_screen.dart';
import 'package:webrtc_app/features/rooms/screen/roomlist_screen.dart';
import 'package:webrtc_app/root_screen.dart';
import 'firebase_options.dart';
import 'features/auth/screen/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ConnectRTC',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const SplashScreen(),
      routes: {
        '/login': (context) => LoginScreen(), // placeholder
        '/root': (context) => RootScreen(), // placeholder
      },
    );
  }
}
