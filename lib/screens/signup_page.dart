// import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:intl_phone_field/countries.dart';
import 'package:trikego_app/Services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:trikego_app/screens/otp_page.dart';
import '../main.dart' show AppColors;

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController mobileController = TextEditingController();
  final TextEditingController emailController = TextEditingController();

  final AuthService _authService = AuthService();
  String _completePhoneNumber = '';
  bool isLoading = false;
  bool agreedToTerms = false;

  void _handleSignUp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      isLoading = true;
    });

    bool success = await _authService.sendOTP(
      phoneNumber: _completePhoneNumber,
      onCodeSent: (message) {
        setState(() {
          isLoading = false;
        });
        _showMessage(message);
        _navigateToOTPScreen();
      },
      onVerificationCompleted: (user) {
        setState(() {
          isLoading = false;
        });
        _navigateToHomeScreen();
      },
      onError: (error) {
        setState(() {
          isLoading = false;
        });
        _showMessage(error);
      },
    );
  }

  void _navigateToOTPScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OtpPage(
          phoneNumber: _completePhoneNumber,
          firstName: firstNameController.text.trim(),
          lastName: lastNameController.text.trim(),
          email: emailController.text.trim(),
        ),
      ),
    );
  }

  void _navigateToHomeScreen() {
    Navigator.pushReplacementNamed(context, '/homepage');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    firstNameController.dispose();
    lastNameController.dispose();
    mobileController.dispose();
    emailController.dispose();
    super.dispose();
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

  Widget _mobileField() {
    return IntlPhoneField(
      controller: mobileController,
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

      onChanged: (phone) {
        setState(() {
          // Update complete phone number with country code
          _completePhoneNumber = phone.completeNumber;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome to TrikeGO!',
                    style: GoogleFonts.inter(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sign Up',
                    style: GoogleFonts.inter(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: firstNameController,
                    textInputAction: TextInputAction.next,
                    decoration: _inputDecoration('First Name'),
                    style: GoogleFonts.inter(fontSize: 16),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your first name';
                      }
                      if (value.trim().length < 2) {
                        return 'First name must be at least 2 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: lastNameController,
                    textInputAction: TextInputAction.next,
                    decoration: _inputDecoration('Last Name'),
                    style: GoogleFonts.inter(fontSize: 16),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your last name';
                      }
                      if (value.trim().length < 2) {
                        return 'Last name must be at least 2 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _mobileField(),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    decoration: _inputDecoration('Email'),
                    style: GoogleFonts.inter(fontSize: 16),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your email';
                      }
                      if (!RegExp(
                        r'^[A-Za-z0-9._%+-]+@gmail\.com$',
                        caseSensitive: false,
                      ).hasMatch(value.trim())) {
                        return 'Please use a Gmail address';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: 24,
                        width: 24,
                        child: Checkbox.adaptive(
                          value: agreedToTerms,
                          onChanged: (v) =>
                              setState(() => agreedToTerms = v ?? false),
                          activeColor: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              height: 1.4,
                              color: Colors.black.withValues(alpha: 0.75),
                            ),
                            children: [
                              const TextSpan(
                                text:
                                    'By creating an account means you agree to the ',
                              ),
                              TextSpan(
                                text: 'Terms and Conditions',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                              const TextSpan(text: ', and our '),
                              TextSpan(
                                text: 'Privacy Policy',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isLoading || !agreedToTerms ? null : _handleSignUp,

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
                  'SIGN UP',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text.rich(
              TextSpan(
                text: 'Have an account? ',
                style: GoogleFonts.inter(fontSize: 16, color: Colors.black),
                children: [
                  TextSpan(
                    text: 'Sign In',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
