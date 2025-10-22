import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:intl_phone_field/countries.dart';
import 'package:trikego_app/Services/auth_service.dart';
import '../screens/otp_page.dart';
import '../utils/snackbar_utils.dart';
import '../main.dart' show AppColors;

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();

  final AuthService _authService = AuthService();
  String _completePhoneNumber = '';
  bool _isLoading = false;
  bool _agreedToTerms = false;
  bool _hasAttemptedSignUp = false;
  String? _phoneError;

  Future<void> _handleSignUp() async {
    setState(() {
      _hasAttemptedSignUp = true;
      // Validate phone number
      if (_mobileController.text.isEmpty) {
        _phoneError = 'Please enter your mobile number';
      } else if (_mobileController.text.length != 10) {
        _phoneError = 'Please enter a valid 10-digit mobile number';
      } else {
        _phoneError = null;
      }
    });
    
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_phoneError != null) {
      return;
    }

    if (!_agreedToTerms) {
      context.showError('Please agree to the Terms and Conditions.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final phoneExists = await _authService.checkPhoneNumberExists(
        _completePhoneNumber,
      );
      if (!mounted) return;

      if (phoneExists) {
        context.showError(
          'This phone number is already registered. Please use a different number or sign in instead.',
        );
        setState(() => _isLoading = false);
        return;
      }

      final userProfile = UserProfile(
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        phoneNumber: _completePhoneNumber,
      );

      final result = await _authService.startPhoneAuth(
        phoneNumber: _completePhoneNumber,
        userProfile: userProfile,
      );
      if (!mounted) return;

      if (result.isSuccess) {
        if (result.hasUser) {
          context.showSuccess(result.message);
          _navigateToHomeScreen();
        } else if (result.isOtpSent) {
          context.showSMS(result.message);
          _navigateToOTPScreen();
        }
      } else {
        context.showError(result.message);
      }
    } catch (e) {
      if (mounted) {
        context.showError('An unexpected error occurred. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _navigateToOTPScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OtpPage(
          phoneNumber: _completePhoneNumber,
          firstName: _firstNameController.text.trim(),
          lastName: _lastNameController.text.trim(),
        ),
      ),
    );
  }

  void _navigateToHomeScreen() {
    Navigator.pushNamedAndRemoveUntil(context, '/homepage', (route) => false);
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _mobileController.dispose();
    super.dispose();
  }

  void _showTermsDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 8,
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.5,
              maxWidth: 450,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 12, 12, 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Terms and Conditions',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: Colors.grey.shade600, size: 20),
                        onPressed: () => Navigator.pop(context),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        splashRadius: 18,
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: Colors.grey.shade200),
                // Content
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDialogSection(
                          'Acceptance of Terms',
                          'By accessing and using the TrikeGo mobile application, you accept and agree to be bound by these Terms of Service. If you do not agree to these Terms, please do not use the App.',
                        ),
                        _buildDialogSection(
                          'Eligibility',
                          'To use this App, you must:\n\n'
                          '• Be at least 18 years of age\n'
                          '• Have the legal capacity to enter into binding contracts\n'
                          '• Provide accurate and complete registration information\n'
                          '• Comply with all applicable local laws and regulations',
                        ),
                        _buildDialogSection(
                          'Account Responsibilities',
                          'You are responsible for:\n\n'
                          '• Maintaining the confidentiality of your account credentials\n'
                          '• All activities that occur under your account\n'
                          '• Ensuring your profile information is accurate and up-to-date\n'
                          '• Notifying us immediately of any unauthorized access',
                        ),
                        _buildDialogSection(
                          'Passenger Obligations',
                          'As a passenger, you agree to:\n\n'
                          '• Provide accurate pickup and destination information\n'
                          '• Be ready at the pickup location at the scheduled time\n'
                          '• Treat drivers with respect and courtesy\n'
                          '• Pay the agreed fare upon trip completion\n'
                          '• Follow driver instructions regarding safety',
                        ),
                        _buildDialogSection(
                          'Contact Us',
                          'If you have any questions about these Terms of Service:\n\n'
                          'Email: support@pbtoda.com\n'
                          'Phone: +63 912 345 6789',
                          isLast: true,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showPrivacyDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 8,
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.5,
              maxWidth: 450,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 12, 12, 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Privacy Policy',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: Colors.grey.shade600, size: 20),
                        onPressed: () => Navigator.pop(context),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        splashRadius: 18,
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: Colors.grey.shade200),
                // Content
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDialogSection(
                          'Introduction',
                          'This Privacy Policy describes how PB TODA collects, uses, and protects your information when you use our TrikeGo mobile application.',
                        ),
                        _buildDialogSection(
                          'Information We Collect',
                          'We collect the following types of information:\n\n'
                          '• Personal Information: Name, phone number, and profile picture\n'
                          '• Location Data: GPS location for navigation and service purposes\n'
                          '• Device Information: Device type, operating system, and app version\n'
                          '• Usage Data: App usage patterns and performance metrics',
                        ),
                        _buildDialogSection(
                          'How We Use Your Information',
                          'We use your information to:\n\n'
                          '• Provide and maintain our services\n'
                          '• Authenticate and verify your identity\n'
                          '• Enable location-based features\n'
                          '• Improve our app and services\n'
                          '• Communicate with you about updates and support',
                        ),
                        _buildDialogSection(
                          'Information Sharing',
                          'We do not sell, trade, or rent your personal information to third parties. We may share your information only when:\n\n'
                          '• Required by law or legal process\n'
                          '• With PB TODA officials for operational purposes\n'
                          '• With your explicit consent',
                        ),
                        _buildDialogSection(
                          'Data Security',
                          'We implement appropriate security measures to protect your personal information against unauthorized access, alteration, disclosure, or destruction.',
                        ),
                        _buildDialogSection(
                          'Your Rights',
                          'You have the right to:\n\n'
                          '• Access your personal information\n'
                          '• Update or correct your information\n'
                          '• Delete your account and associated data\n'
                          '• Request a copy of your data',
                        ),
                        _buildDialogSection(
                          'Contact Us',
                          'If you have any questions about this Privacy Policy:\n\n'
                          'Email: privacy@pbtoda.com\n'
                          'Phone: +63 912 345 6789',
                          isLast: true,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDialogSection(String title, String content, {bool isLast = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            content,
            style: GoogleFonts.inter(
              fontSize: 12.5,
              color: Colors.grey.shade700,
              height: 1.5,
              letterSpacing: -0.1,
            ),
          ),
        ],
      ),
    );
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
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
    );
  }

  Widget _mobileField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IntlPhoneField(
          controller: _mobileController,
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
          disableLengthCheck: true,
          invalidNumberMessage: null,
          decoration: _inputDecoration('Mobile Number').copyWith(
            errorBorder: _phoneError != null
                ? OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.red, width: 1.5),
                  )
                : null,
            enabledBorder: _phoneError != null
                ? OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.red, width: 1.5),
                  )
                : OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
                  ),
          ),
          style: GoogleFonts.inter(fontSize: 16),
          dropdownTextStyle: GoogleFonts.inter(fontSize: 16),
          flagsButtonPadding: const EdgeInsets.only(left: 8),
          onChanged: (phone) {
            setState(() {
              _completePhoneNumber = phone.completeNumber;
              // Clear error when user types
              if (_hasAttemptedSignUp) {
                if (_mobileController.text.isEmpty) {
                  _phoneError = 'Please enter your mobile number';
                } else if (_mobileController.text.length != 10) {
                  _phoneError = 'Please enter a valid 10-digit mobile number';
                } else {
                  _phoneError = null;
                }
              }
            });
          },
        ),
        if (_phoneError != null)
          Padding(
            padding: const EdgeInsets.only(left: 12, top: 8),
            child: Text(
              _phoneError!,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.red.shade700,
              ),
            ),
          ),
      ],
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
              autovalidateMode: _hasAttemptedSignUp 
                  ? AutovalidateMode.onUserInteraction 
                  : AutovalidateMode.disabled,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sign Up',
                    style: GoogleFonts.inter(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create your account',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _firstNameController,
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
                    controller: _lastNameController,
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
                  const SizedBox(height: 20),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: 24,
                        width: 24,
                        child: Checkbox.adaptive(
                          value: _agreedToTerms,
                          onChanged: (v) =>
                              setState(() => _agreedToTerms = v ?? false),
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
                                recognizer: TapGestureRecognizer()
                                  ..onTap = () => _showTermsDialog(context),
                              ),
                              const TextSpan(text: ', and our '),
                              TextSpan(
                                text: 'Privacy Policy',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                                recognizer: TapGestureRecognizer()
                                  ..onTap = () => _showPrivacyDialog(context),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
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
                onPressed: _isLoading || !_agreedToTerms ? null : _handleSignUp,

                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 3,
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
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
                    recognizer: TapGestureRecognizer()
                      ..onTap = () =>
                          Navigator.of(context).pushReplacementNamed('/signin'),
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
