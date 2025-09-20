import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart';

class ServiceUnavailablePage extends StatelessWidget {
  final String? userLocation;
  final String? reason;

  const ServiceUnavailablePage({
    super.key,
    this.userLocation,
    this.reason,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const SizedBox(height: 20),
              // Main Heading
              Text(
                'TrikeGO rides are not available here',
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
                textAlign: TextAlign.left,
              ),

              const SizedBox(height: 15),

              // User Location Info
              if (userLocation != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.location_on, color: Colors.red.shade600, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Your current location:',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.red.shade700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              userLocation!,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: Colors.red.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Explanatory Text
              Text(
                reason ?? 'Ride booking is exclusively available for passengers in Paombong, Bulacan. Please ensure that you are within our service area to proceed.',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: Colors.black,
                  height: 1.5,
                ),
                textAlign: TextAlign.left,
              ),

              const SizedBox(height: 60),

              // Map Icon
              Center(
                child: Image.asset(
                  'assets/images/map_icon.png',
                  width: 200,
                  height: 200,
                  fit: BoxFit.contain,
                ),
              ),

              const Spacer(),

              // Back Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Back',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
