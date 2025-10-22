import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:intl_phone_field/countries.dart';
import '../main.dart' show AppColors;
import '../Services/auth_service.dart';
import '../utils/snackbar_utils.dart';

class SignInPage extends StatefulWidget {
  const SignInPage({super.key});

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _smsCodeController = TextEditingController();
  final AuthService _authService = AuthService();
  String _completePhoneNumber = '';

  static const int _initialSeconds = 60;
  int _secondsRemaining = 0;
  Timer? _timer;

  bool _isSendingOtp = false;
  bool _isVerifying = false;
  bool _isGmailLoading = false;

  @override
  void dispose() {
    _timer?.cancel();
    _phoneController.dispose();
    _smsCodeController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _secondsRemaining = _initialSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_secondsRemaining > 0) {
          _secondsRemaining--;
        } else {
          timer.cancel();
        }
      });
    });
  }

  Future<void> _sendOtp() async {
    if (_completePhoneNumber.isEmpty) {
      context.showError('Please enter a valid phone number');
      return;
    }

    setState(() => _isSendingOtp = true);

    try {
      final phoneExists = await _authService.checkPhoneNumberExists(
        _completePhoneNumber,
      );
      if (!mounted) return;

      if (!phoneExists) {
        context.showError(
          'This phone number is not registered. Please sign up first.',
        );
        setState(() => _isSendingOtp = false);
        return;
      }

      final result = await _authService.startPhoneAuth(
        phoneNumber: _completePhoneNumber,
      );
      if (!mounted) return;

      if (result.isSuccess) {
        context.showSMS('OTP sent to $_completePhoneNumber');
        _startTimer();
      } else {
        context.showError(result.message);
      }
    } catch (e) {
      if (mounted) {
        context.showError('Failed to send OTP. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() => _isSendingOtp = false);
      }
    }
  }

  Future<void> _verifyCode() async {
    final code = _smsCodeController.text.trim();

    if (code.length != 6) {
      context.showError('Please enter a valid 6-digit OTP code.');
      return;
    }

    setState(() => _isVerifying = true);

    try {
      final result = await _authService.verifyOtp(code);
      if (!mounted) return;

      if (result.isSuccess && result.hasUser) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/homepage',
          (route) => false,
        );
      } else {
        context.showError(result.message);
      }
    } catch (e) {
      if (mounted) {
        context.showError('Verification failed. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() => _isVerifying = false);
      }
    }
  }

  Future<void> _signInWithGmail() async {
    setState(() => _isGmailLoading = true);

    try {
      final result = await _authService.signInWithGmail();
      if (!mounted) return;

      if (result.isSuccess) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/homepage',
          (route) => false,
        );
      } else {
        // Check if this was a cancellation - don't show error for cancellation
        if (result.message == 'Gmail sign-in was cancelled by user') {
          // User cancelled, don't show any message and don't navigate
          return;
        }

        // Handle specific error cases
        if (result.errorCode == 'ACCOUNT_NOT_REGISTERED') {
          context.showError(
            'Gmail account not registered. Please make sure the email is linked to an account.',
          );
        } else if (result.errorCode == 'ACCOUNT_NOT_LINKED') {
          context.showError(
            'This Gmail account is not linked to your registered account. '
            'Please sign in with your phone number first, then link your Gmail account.',
          );
        } else {
          context.showError(result.message);
        }
      }
    } catch (e) {
      if (mounted) {
        context.showError('Gmail sign-in failed. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() => _isGmailLoading = false);
      }
    }
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

  bool get _isPhoneValid =>
      _completePhoneNumber.startsWith('+63') &&
      _completePhoneNumber.length >= 12;
  bool get _isCodeValid => _smsCodeController.text.trim().length == 6;

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
                  controller: _phoneController,
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
                    () => _completePhoneNumber = phone.completeNumber,
                  ),
                ),
                const SizedBox(height: 12),
                Stack(
                  alignment: Alignment.centerRight,
                  children: [
                    TextField(
                      controller: _smsCodeController,
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
                        onPressed:
                            (_isPhoneValid &&
                                _secondsRemaining == 0 &&
                                !_isSendingOtp)
                            ? _sendOtp
                            : null,
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          disabledForegroundColor: Colors.black45,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          backgroundColor: Colors.transparent,
                        ),
                        child: _isSendingOtp
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.primary,
                                ),
                              )
                            : Text(
                                _secondsRemaining > 0
                                    ? 'Resend (00:${_secondsRemaining.toString().padLeft(2, '0')})'
                                    : 'Get SMS Code',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w600,
                                ),
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
                    onPressed: (_isPhoneValid && _isCodeValid && !_isVerifying)
                        ? _verifyCode
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 3,
                    ),
                    child: _isVerifying
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
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
                    onPressed: _isGmailLoading ? null : _signInWithGmail,
                    icon: Container(
                      width: 25,
                      height: 25,
                      decoration: const BoxDecoration(
                        image: DecorationImage(
                          image: NetworkImage(
                            'https://developers.google.com/identity/images/g-logo.png',
                          ),
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    label: Text(
                      'Sign in with Google',
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
                        color: Colors.black.withValues(alpha: 0.6),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      backgroundColor: Colors.white,
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
                  ..onTap = () =>
                      Navigator.of(context).pushReplacementNamed('/signup'),
              ),
            ],
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
