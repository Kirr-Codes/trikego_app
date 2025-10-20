import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:trikego_app/Services/auth_service.dart';
import 'package:trikego_app/Services/fcm_service.dart';
import 'screens/signup_page.dart';
import 'screens/otp_page.dart';
import 'screens/signin_page.dart';
import 'screens/edit_profile_page.dart';
import 'screens/settings_screen.dart';
import 'screens/privacy_policy_screen.dart';
import 'screens/terms_of_service_screen.dart';
import 'screens/contact_us_screen.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/homepage.dart';
import 'screens/history_screen.dart';
import 'screens/payment_method_screen.dart';
import 'screens/notifications_screen.dart';
import 'widgets/auth_wrapper.dart';

import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Configure system UI
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      systemNavigationBarColor: AppColors.primary,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  await dotenv.load(fileName: ".env");

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Set up background message handler
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // Initialize Auth Service
  await AuthService().initialize();

  // Initialize FCM Service
  await FCMService().initialize();

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
        '/': (context) => const AuthWrapper(),
        '/signin': (context) => const SignInPage(),
        '/signup': (context) => const SignUpPage(),
        '/otp': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as String?;
          return OtpPage(phoneNumber: args ?? '', lastName: '', firstName: '');
        },
        '/homepage': (context) => const HomePage(),
        '/history': (context) => const HistoryScreen(),
        '/notifications': (context) => const NotificationsScreen(),
        '/edit_profile': (context) => const EditProfilePage(),
        '/settings': (context) => const SettingsScreen(),
        '/payment_method': (context) => const PaymentMethodScreen(),
        '/privacy_policy': (context) => const PrivacyPolicyScreen(),
        '/terms_of_service': (context) => const TermsOfServiceScreen(),
        '/contact_us': (context) => const ContactUsScreen(),
      },
    );
  }
}
