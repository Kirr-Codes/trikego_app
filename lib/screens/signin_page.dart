import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:intl_phone_field/countries.dart';
import '../main.dart' show AppColors;

class SignInPage extends StatefulWidget {
  const SignInPage({super.key});

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController smsCodeController = TextEditingController();
  String completePhoneNumber = '';

  static const int initialSeconds = 60;
  int secondsRemaining = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    phoneController.dispose();
    smsCodeController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => secondsRemaining = initialSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {
        if (secondsRemaining > 0) {
          secondsRemaining--;
        } else {
          t.cancel();
        }
      });
    });
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.inter(color: Colors.black.withValues(alpha: 0.35)),
      filled: true,
      fillColor: const Color(0xFFF2F2F4),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
    );
  }

  bool get isPhoneValid =>
      completePhoneNumber.startsWith('+63') && completePhoneNumber.length >= 12;
  bool get isCodeValid => smsCodeController.text.trim().length == 6;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sign In',
                  style: GoogleFonts.inter(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Enter your mobile number',
                  style: GoogleFonts.inter(fontSize: 18, color: Colors.black87),
                ),
                const SizedBox(height: 20),
                IntlPhoneField(
                  controller: phoneController,
                  initialCountryCode: 'PH',
                  countries: const [
                    Country(
                      name: 'Philippines',
                      flag: '🇵🇭',
                      code: 'PH',
                      dialCode: '63',
                      nameTranslations: {},
                      minLength: 10,
                      maxLength: 10,
                    ),
                  ],
                  showDropdownIcon: false,
                  disableLengthCheck: false,
                  decoration: _inputDecoration('Mobile Number'),
                  style: GoogleFonts.inter(fontSize: 16),
                  dropdownTextStyle: GoogleFonts.inter(fontSize: 16),
                  flagsButtonPadding: const EdgeInsets.only(left: 8),
                  onChanged: (phone) => setState(
                    () => completePhoneNumber = phone.completeNumber,
                  ),
                ),
                const SizedBox(height: 12),
                Stack(
                  alignment: Alignment.centerRight,
                  children: [
                    TextField(
                      controller: smsCodeController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      decoration: _inputDecoration(
                        'SMS Code',
                      ).copyWith(counterText: ''),
                      style: GoogleFonts.inter(fontSize: 16),
                      onChanged: (_) => setState(() {}),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: TextButton(
                        onPressed: (isPhoneValid && secondsRemaining == 0)
                            ? () {
                                // TODO: trigger request SMS using completePhoneNumber
                                _startTimer();
                              }
                            : null,
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          disabledForegroundColor: Colors.black45,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          backgroundColor: Colors.transparent,
                        ),
                        child: Text(
                          secondsRemaining > 0
                              ? 'Resend (00:${secondsRemaining.toString().padLeft(2, '0')})'
                              : 'Get SMS Code',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Enter the 6-digit code sent to your number.',
                  style: GoogleFonts.inter(fontSize: 16, color: Colors.black45),
                ),
                // Primary Sign In CTA placed inline (to match reference layout)
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: (isPhoneValid && isCodeValid) ? () {} : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 3,
                    ),
                    child: Text(
                      'SIGN IN',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    const Expanded(
                      child: Divider(thickness: 1, color: Color(0x1A000000)),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'or',
                        style: GoogleFonts.inter(
                          color: Colors.black38,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const Expanded(
                      child: Divider(thickness: 1, color: Color(0x1A000000)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).pushNamed('/signin_email'),
                    icon: const Icon(
                      Icons.mail_outline,
                      color: AppColors.primary,
                    ),
                    label: Text(
                      'Sign in with email',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: Colors.black,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 16,
                      ),
                      side: BorderSide(
                        color: Colors.black.withValues(alpha: 0.12),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      backgroundColor: const Color(0xFFF2F2F4),
                      alignment: Alignment.center,
                    ),
                  ),
                ),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Text.rich(
          TextSpan(
            text: "Don't have an account? ",
            style: GoogleFonts.inter(fontSize: 16, color: Colors.black),
            children: [
              TextSpan(
                text: 'Sign Up',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
                recognizer: TapGestureRecognizer()
                  ..onTap = () => Navigator.of(context).pushNamed('/signup'),
              ),
            ],
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
