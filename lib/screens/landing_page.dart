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
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double height = constraints.maxHeight;
            final double width = constraints.maxWidth;
            final double topSectionHeight = height * 0.62;

            // Responsive scaling based on device width (375 is iPhone baseline)
            final double scale = (width / 375.0).clamp(0.9, 1.2);
            final double paragraphFontSize = 16.0 * scale;
            final double bottomInset = MediaQuery.of(context).padding.bottom;
            final double logoMaxWidth = (width * 0.60).clamp(180.0, 420.0);
            final double logoMaxHeight = (topSectionHeight * 0.36).clamp(
              120.0,
              260.0,
            );
            return Column(
              children: [
                // Top branding section
                Container(
                  height: topSectionHeight,
                  width: double.infinity,
                  color: primary, // match primary scaffold
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: Center(
                          child: SizedBox(
                            width: logoMaxWidth,
                            height: logoMaxHeight,
                            child: FittedBox(
                              fit: BoxFit.contain,
                              alignment: Alignment.center,
                              child: Image.asset(
                                'assets/images/landingpage_logo.png',
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Bottom action panel with slide-up animation on first build
                TweenAnimationBuilder<Offset>(
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
                    padding: EdgeInsets.fromLTRB(24, 32, 24, 24 + bottomInset),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'Skip the hassle of finding a tricycle on the street, book instantly and travel with ease, saving you time and energy.',
                          style: GoogleFonts.josefinSans(
                            color: Colors.white.withValues(alpha: 0.95),
                            height: 1.4,
                            fontWeight: FontWeight.w500,
                            fontSize: paragraphFontSize,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const Spacer(),
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
                    return Expanded(
                      child: FractionalTranslation(
                        translation: offset,
                        child: Opacity(opacity: opacity, child: child),
                      ),
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
