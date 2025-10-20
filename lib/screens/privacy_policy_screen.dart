import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'terms_of_service_screen.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Privacy Policy',
          style: GoogleFonts.inter(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Column(
          children: [
            const SizedBox(height: 20),
            _buildPolicyOption(
              context,
              Icons.description_outlined,
              'Privacy Policy',
              'How we collect and use your data.',
              () => _navigateToPrivacyPolicy(context),
            ),
            const SizedBox(height: 16),
            _buildPolicyOption(
              context,
              Icons.article_outlined,
              'Terms of Service',
              'User agreement and conditions.',
              () => _navigateToTermsOfService(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPolicyOption(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300, width: 1),
      ),
      child: ListTile(
        leading: Icon(icon, color: Colors.black, size: 24),
        title: Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: Colors.grey.shade600,
          ),
        ),
        onTap: onTap,
        trailing: const Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: Colors.black54,
        ),
      ),
    );
  }

  void _navigateToPrivacyPolicy(BuildContext context) {
    // Navigate to detailed privacy policy content
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const DetailedPrivacyPolicyScreen(),
      ),
    );
  }

  void _navigateToTermsOfService(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const TermsOfServiceScreen()),
    );
  }
}

class DetailedPrivacyPolicyScreen extends StatelessWidget {
  const DetailedPrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Privacy Policy',
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
              'Privacy Policy',
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
              'Introduction',
              'This Privacy Policy describes how PB TODA ("we", "our", or "us") collects, uses, and protects your information when you use our Driver/Operator mobile application.',
            ),

            // Information We Collect
            _buildSection(
              'Information We Collect',
              'We collect the following types of information:\n\n'
              '• Personal Information: Name, phone number, and profile picture\n'
              '• Location Data: GPS location for navigation and service purposes\n'
              '• Device Information: Device type, operating system, and app version\n'
              '• Usage Data: App usage patterns and performance metrics',
            ),

            // How We Use Your Information
            _buildSection(
              'How We Use Your Information',
              'We use your information to:\n\n'
              '• Provide and maintain our services\n'
              '• Authenticate and verify your identity\n'
              '• Enable location-based features\n'
              '• Improve our app and services\n'
              '• Communicate with you about updates and support\n'
              '• Ensure compliance with TODA regulations',
            ),

            // Information Sharing
            _buildSection(
              'Information Sharing',
              'We do not sell, trade, or rent your personal information to third parties. We may share your information only in the following circumstances:\n\n'
              '• With PB TODA officials for operational purposes\n'
              '• When required by law or legal process\n'
              '• To protect our rights and safety\n'
              '• With your explicit consent',
            ),

            // Data Security
            _buildSection(
              'Data Security',
              'We implement appropriate security measures to protect your personal information against unauthorized access, alteration, disclosure, or destruction. However, no method of transmission over the internet is 100% secure.',
            ),

            // Your Rights
            _buildSection(
              'Your Rights',
              'You have the right to:\n\n'
              '• Access your personal information\n'
              '• Update or correct your information\n'
              '• Delete your account and associated data\n'
              '• Opt-out of certain data collection\n'
              '• Request a copy of your data',
            ),

            // Location Data
            _buildSection(
              'Location Data',
              'Our app uses GPS location data to provide navigation and location-based services. Location data is only collected when the app is in use and with your permission. You can disable location services in your device settings.',
            ),

            // Data Retention
            _buildSection(
              'Data Retention',
              'We retain your personal information only as long as necessary to provide our services and comply with legal obligations. When you delete your account, we will remove your personal information within 30 days.',
            ),

            // Children\'s Privacy
            _buildSection(
              'Children\'s Privacy',
              'Our app is not intended for children under 18 years of age. We do not knowingly collect personal information from children under 18.',
            ),

            // Changes to Privacy Policy
            _buildSection(
              'Changes to This Privacy Policy',
              'We may update this Privacy Policy from time to time. We will notify you of any changes by posting the new Privacy Policy in the app and updating the "Last updated" date.',
            ),

            // Contact Information
            _buildSection(
              'Contact Us',
              'If you have any questions about this Privacy Policy, please contact us:\n\n'
              'Email: privacy@pbtoda.com\n'
              'Phone: +63 912 345 6789\n'
              'Address: PB TODA Office, Bacolod City, Negros Occidental',
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
