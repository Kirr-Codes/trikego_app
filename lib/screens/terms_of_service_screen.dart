import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
            color: Colors.black,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Terms of Service',
          style: GoogleFonts.inter(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              'Terms of Service',
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Last updated: ${DateTime.now().year}',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 24),

            // Introduction
            _buildSection(
              'Acceptance of Terms',
              'By accessing and using the TrikeGo mobile application ("the App"), you accept and agree to be bound by these Terms of Service ("Terms"). If you do not agree to these Terms, please do not use the App.',
            ),

            // Eligibility
            _buildSection(
              'Eligibility',
              'To use this App, you must:\n\n'
              '• Be at least 18 years of age\n'
              '• Have the legal capacity to enter into binding contracts\n'
              '• Provide accurate and complete registration information\n'
              '• Comply with all applicable local laws and regulations\n'
              '• Not be prohibited from using the service under Philippine law',
            ),

            // Account Responsibilities
            _buildSection(
              'Account Responsibilities',
              'You are responsible for:\n\n'
              '• Maintaining the confidentiality of your account credentials\n'
              '• All activities that occur under your account\n'
              '• Ensuring your profile information is accurate and up-to-date\n'
              '• Notifying us immediately of any unauthorized access\n'
              '• Not sharing your account with others',
            ),

            // Passenger Obligations
            _buildSection(
              'Passenger Obligations',
              'As a passenger, you agree to:\n\n'
              '• Provide accurate pickup and destination information\n'
              '• Be ready at the pickup location at the scheduled time\n'
              '• Treat drivers with respect and courtesy\n'
              '• Pay the agreed fare upon trip completion\n'
              '• Follow driver instructions regarding safety\n'
              '• Not bring prohibited items or engage in illegal activities\n'
              '• Cancel bookings promptly if your plans change',
            ),

            // Booking and Payments
            _buildSection(
              'Bookings and Payments',
              'Regarding bookings and payments:\n\n'
              '• Fares are calculated based on TODA-approved rates\n'
              '• Payment is made directly to the driver\n'
              '• The App does not process payments or collect commissions\n'
              '• Fare estimates are approximate and may vary\n'
              '• Cancellation fees may apply for late cancellations\n'
              '• All fare disputes must be resolved according to TODA policies',
            ),

            // Service Description
            _buildSection(
              'Service Description',
              'TrikeGo is a booking platform that connects passengers with PB TODA drivers:\n\n'
              '• We facilitate connections but do not provide transportation\n'
              '• Drivers are independent contractors, not our employees\n'
              '• We do not guarantee driver availability\n'
              '• Service quality depends on individual drivers\n'
              '• We are not responsible for driver actions or vehicle conditions',
            ),

            // Prohibited Activities
            _buildSection(
              'Prohibited Activities',
              'You may not:\n\n'
              '• Use the App for any illegal purposes\n'
              '• Harass, threaten, or discriminate against drivers\n'
              '• Provide false information or impersonate others\n'
              '• Attempt to hack, reverse engineer, or compromise the App\n'
              '• Create multiple accounts to abuse promotions\n'
              '• Use the App to transport prohibited or dangerous items\n'
              '• Interfere with other users\' ability to use the service',
            ),

            // Location Services
            _buildSection(
              'Location Services',
              'The App requires access to your device location to:\n\n'
              '• Determine your pickup location\n'
              '• Match you with nearby drivers\n'
              '• Provide navigation and routing services\n'
              '• Track trip progress\n'
              '• Improve service quality\n\n'
              'You can disable location services, but this will prevent you from using the App.',
            ),

            // Cancellation Policy
            _buildSection(
              'Cancellation Policy',
              'Regarding booking cancellations:\n\n'
              '• You may cancel bookings before driver acceptance without penalty\n'
              '• Cancellations after driver acceptance may incur fees\n'
              '• Repeated cancellations may result in account restrictions\n'
              '• Drivers may cancel if you are not at the pickup location\n'
              '• Emergency cancellations will be handled case-by-case',
            ),

            // Service Availability
            _buildSection(
              'Service Availability',
              'We reserve the right to:\n\n'
              '• Modify, suspend, or discontinue the App at any time\n'
              '• Update features and functionality without notice\n'
              '• Perform maintenance that may temporarily interrupt service\n'
              '• Change these Terms with reasonable notice\n'
              '• Limit service to certain geographic areas\n\n'
              'We are not liable for any service interruptions or modifications.',
            ),

            // Termination
            _buildSection(
              'Termination',
              'We may suspend or terminate your access to the App if you:\n\n'
              '• Violate these Terms of Service\n'
              '• Engage in fraudulent or illegal activities\n'
              '• Receive multiple complaints from drivers\n'
              '• Abuse the service or other users\n'
              '• Provide false or misleading information\n\n'
              'You may delete your account at any time through the App settings.',
            ),

            // Limitation of Liability
            _buildSection(
              'Limitation of Liability',
              'To the maximum extent permitted by law:\n\n'
              '• The App is provided "as is" without warranties of any kind\n'
              '• We are not liable for any accidents, injuries, or damages during trips\n'
              '• We do not guarantee uninterrupted or error-free service\n'
              '• We are not responsible for disputes between passengers and drivers\n'
              '• We are not liable for lost or damaged property\n'
              '• Our total liability shall not exceed the amount you paid to use the App (if any)',
            ),

            // Indemnification
            _buildSection(
              'Indemnification',
              'You agree to indemnify and hold harmless PB TODA, TrikeGo, and their officers, directors, employees, and agents from any claims, damages, losses, or expenses arising from:\n\n'
              '• Your use of the App\n'
              '• Your violation of these Terms\n'
              '• Your violation of any laws or regulations\n'
              '• Your interactions with drivers or other users',
            ),

            // Intellectual Property
            _buildSection(
              'Intellectual Property',
              'The App and its content, including but not limited to text, graphics, logos, and software, are the property of PB TODA and are protected by intellectual property laws. You may not copy, modify, distribute, or create derivative works without our written permission.',
            ),

            // Dispute Resolution
            _buildSection(
              'Dispute Resolution',
              'Any disputes arising from these Terms or your use of the App shall be resolved through:\n\n'
              '1. Direct communication with our customer support\n'
              '2. Mediation by PB TODA officials if necessary\n'
              '3. Arbitration or legal proceedings as a last resort\n\n'
              'These Terms are governed by the laws of the Philippines.',
            ),

            // Changes to Terms
            _buildSection(
              'Changes to These Terms',
              'We may update these Terms from time to time. We will notify you of any material changes by:\n\n'
              '• Posting the new Terms in the App\n'
              '• Updating the "Last updated" date\n'
              '• Sending a notification through the App\n\n'
              'Your continued use of the App after changes constitutes acceptance of the new Terms.',
            ),

            // Contact Information
            _buildSection(
              'Contact Us',
              'If you have any questions about these Terms of Service, please contact us:\n\n'
              'Email: support@pbtoda.com\n'
              'Phone: +63 912 345 6789\n'
              'Address: PB TODA Office, Paombong Bulacan, Philippines',
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          content,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: Colors.grey.shade700,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
