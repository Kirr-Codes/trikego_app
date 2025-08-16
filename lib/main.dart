import 'package:flutter/material.dart';
import 'screens/landing_page.dart';
import 'screens/signup_page.dart';
import 'screens/signin_email_page.dart';
import 'screens/otp_page.dart';
import 'screens/signin_page.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      systemNavigationBarColor: AppColors.primary,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const MyApp());
}

/// Brand color definitions used across the app
class AppColors {
  static const Color primary = Color(0xFF0E4078); // 0E4078
  static const Color secondary = Color(0xFF9BBBFC); // 9BBBFC
  static const Color background = Color(0xFFFDFDFF); // FDFDFF
}

/// Theming configuration for the application
class AppTheme {
  static ColorScheme get colorScheme => const ColorScheme.light(
    primary: AppColors.primary,
    onPrimary: Colors.white,
    secondary: AppColors.secondary,
    onSecondary: AppColors.primary,
    error: Colors.red,
    onError: Colors.white,
    surface: AppColors.background,
    onSurface: AppColors.primary,
  );

  static ThemeData get themeData {
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: GoogleFonts.interTextTheme(),
      scaffoldBackgroundColor: AppColors.background,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Trikego',
      theme: AppTheme.themeData,
      initialRoute: '/',
      routes: {
        '/': (context) => const LandingPage(),
        '/signin': (context) => const SignInPage(),
        '/signin_email': (context) => const SignInEmailPage(),
        '/signup': (context) => const SignUpPage(),
        '/otp': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as String?;
          return OtpPage(phoneNumber: args ?? '');
        },
      },
    );
  }
}
