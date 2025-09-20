import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/gmail_connection_card.dart';
import '../widgets/delete_account_section.dart';
import '../widgets/section_header.dart';

class AccountSettingsScreen extends StatelessWidget {
  const AccountSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.arrow_back, color: Colors.black, size: 20),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Account',
          style: GoogleFonts.inter(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Colors.grey[200]),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            // Linked Account Section
            const SectionHeader(title: 'Linked Account'),
            const SizedBox(height: 16),
            const GmailConnectionCard(),

            const SizedBox(height: 32),

            // Delete Account Section
            _buildSectionDivider(),
            const SizedBox(height: 10),
            const SectionHeader(title: 'Delete Account'),
            const SizedBox(height: 12),
            const DeleteAccountSection(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionDivider() {
    return Container(
      height: 1,
      color: Colors.grey[300],
      margin: const EdgeInsets.symmetric(horizontal: 20),
    );
  }
}
