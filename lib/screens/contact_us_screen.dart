import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class ContactUsScreen extends StatelessWidget {
  const ContactUsScreen({super.key});

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
          'Contact Us',
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
            _buildCallSupportOption(context),
          ],
        ),
      ),
    );
  }

  Widget _buildCallSupportOption(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300, width: 1),
      ),
      child: ListTile(
        leading: Icon(
          Icons.headset_mic_outlined,
          color: Colors.black,
          size: 24,
        ),
        title: Text(
          'Call Support',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        subtitle: Text(
          '(+63) 965 597 2427',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: Colors.grey.shade600,
          ),
        ),
        onTap: () => _copyPhoneNumber(context),
        trailing: const Icon(
          Icons.copy,
          size: 16,
          color: Colors.black54,
        ),
      ),
    );
  }

  void _copyPhoneNumber(BuildContext context) {
    const String phoneNumber = '(+63) 965 597 2427';
    
    Clipboard.setData(const ClipboardData(text: phoneNumber));
    
  }
}
