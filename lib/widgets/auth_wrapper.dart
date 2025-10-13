import 'package:flutter/material.dart';
import '../Services/auth_service.dart';
import '../screens/landing_page.dart';
import '../screens/homepage.dart';

/// A wrapper widget that handles authentication state and redirects users accordingly.
/// This ensures persistent authentication - users stay logged in when they reopen the app.
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    // Listen to authentication state changes
    _authService.authStateStream.listen((authState) {
      if (mounted) {
        // The state will be handled in the build method
        setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: _authService.authStateStream,
      initialData: _authService.currentUser != null 
          ? AuthState.authenticated(_authService.currentUser!) 
          : AuthState.unauthenticated(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          // If there's an error, show landing page
          return const LandingPage();
        }

        final authState = snapshot.data;
        
        if (authState == null) {
          // Show loading indicator while checking auth state
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // Handle different authentication states
        if (authState.isAuthenticated) {
          // User is authenticated, show homepage
          return const HomePage();
        } else {
          // User is not authenticated (or any other state), show landing page
          return const LandingPage();
        }
      },
    );
  }
}
