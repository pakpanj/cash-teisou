import 'package:flutter/material.dart';
import 'package:cash_teisou/core/constants/colors.dart';
import 'package:cash_teisou/features/home/presentation/page/main_screen.dart'; // Import MainScreen baru
import 'package:cash_teisou/core/services/ad_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await AdService().initialize();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppThemeMode>(
      valueListenable: globalThemeNotifier,
      builder: (context, currentMode, child) {
        return MaterialApp(
          title: 'Finance App',
          debugShowCheckedModeBanner: false,
          theme: AppThemes.getTheme(currentMode),
          home: const MainScreen(),
        );
      },
    );
  }
}