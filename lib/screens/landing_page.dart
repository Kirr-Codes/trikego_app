import 'package:flutter/material.dart';
import '../main.dart' show AppColors; // reuse brand colors
import 'package:google_fonts/google_fonts.dart';

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final Color primary = AppColors.primary;
    final Color secondary = AppColors.secondary;
    final Color background = AppColors.primary; // primary background

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Top branding section - takes 60% of available height
            Expanded(
              flex: 6,
              child: Container(
                width: double.infinity,
                color: primary,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: 300,
                        maxHeight: 200,
                      ),
                      child: Image.asset(
                        'assets/images/final_logo.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Bottom action panel with slide-up animation
            Expanded(
              flex: 4,
              child: TweenAnimationBuilder<Offset>(
                tween: Tween<Offset>(
                  begin: const Offset(0, 0.25),
                  end: Offset.zero,
                ),
                duration: const Duration(milliseconds: 1200),
                curve: Curves.easeOutCubic,
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: secondary,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(36),
                      topRight: Radius.circular(36),
                    ),
                  ),
                  padding: EdgeInsets.fromLTRB(
                    24,
                    32,
                    24,
                    24 + MediaQuery.of(context).padding.bottom,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        'Skip the hassle of finding a tricycle on the street, book instantly and travel with ease, saving you time and energy.',
                        style: GoogleFonts.josefinSans(
                          color: primary.withValues(alpha: 0.95),
                          height: 1.4,
                          fontWeight: FontWeight.w500,
                          fontSize: 16.0,
                        ),
                        textAlign: TextAlign.justify,
                      ),
                      const SizedBox(height: 38),
                      Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.of(context).pushNamed('/signup');
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: const Text(
                                'SIGN UP',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 15),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: () {
                                Navigator.of(context).pushNamed('/signin');
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: primary,
                                backgroundColor: Colors.white,
                                side: BorderSide(
                                  color: primary.withValues(alpha: 0.15),
                                  width: 1.5,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: const Text(
                                'SIGN IN',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                builder: (context, offset, child) {
                  final double opacity = (1.0 - offset.dy)
                      .clamp(0.0, 1.0)
                      .toDouble();
                  return FractionalTranslation(
                    translation: offset,
                    child: Opacity(opacity: opacity, child: child),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
