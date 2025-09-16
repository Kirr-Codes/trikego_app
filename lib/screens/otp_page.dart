import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pinput/pinput.dart';
import 'package:trikego_app/Services/auth_service.dart';
import '../main.dart' show AppColors;
import '../utils/snackbar_utils.dart';

class OtpPage extends StatefulWidget {
  final String phoneNumber;
  final String firstName;
  final String lastName;
  final String email;

  const OtpPage({
    Key? key,
    required this.phoneNumber,
    required this.firstName,
    required this.lastName,
    required this.email,
  }) : super(key: key);

  @override
  State<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends State<OtpPage> {
  final TextEditingController _codeController = TextEditingController();
  final AuthService _authService = AuthService();

  static const int _initialSeconds = 60;
  int _secondsRemaining = _initialSeconds;
  Timer? _timer;
  bool _isVerifying = false;
  bool _isResending = false;

  Future<void> _resendOtp() async {
    if (_isResending || _secondsRemaining > 0) return;

    setState(() => _isResending = true);

    try {
      final result = await _authService.resendOtp();
      if (!mounted) return;

      if (result.isSuccess) {
        context.showSMS(result.message);
        _startTimer();
      } else {
        context.showError(result.message);
      }
    } catch (e) {
      if (mounted) {
        context.showError('Failed to resend OTP. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() => _isResending = false);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _startTimer();
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

  Future<void> _registerUserInFirestore() async {
    try {
        
      final result = await _authService.registerUserInFirestore(
        firstName: widget.firstName,
        lastName: widget.lastName,
        email: widget.email,
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () => AuthResult.error('Registration timeout. Please try again.'),
      );

      if (!mounted) return;

      if (result.isSuccess) {
        context.showSuccess('Registration completed successfully!');
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/homepage',
          (route) => false,
        );
      } else {
        context.showError('Registration failed: ${result.message}');
        await _authService.signOut();
      }
    } catch (e) {
      if (mounted) {
        context.showError('Registration failed: ${e.toString()}');
        await _authService.signOut();
      }
    }
  }

  Future<void> _verifyCode() async {
    final code = _codeController.text.trim();

    if (code.length != 6) {
      context.showError('Please enter a valid 6-digit OTP code.');
      return;
    }

    setState(() => _isVerifying = true);

    try {
      final result = await _authService.verifyOtp(code);
      if (!mounted) return;

      if (result.isSuccess && result.hasUser) {
        await _registerUserInFirestore();
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

  @override
  void dispose() {
    _timer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const defaultPinTheme = PinTheme(
      width: 58,
      height: 58,
      textStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
      decoration: BoxDecoration(
        color: Color(0xFFF2F2F4),
        borderRadius: BorderRadius.all(Radius.circular(12)),
        border: Border.fromBorderSide(BorderSide(color: Color(0x1F000000))),
      ),
    );

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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Phone verification',
                style: GoogleFonts.inter(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Enter your OTP code',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 20),
              Pinput(
                controller: _codeController,
                length: 6,
                defaultPinTheme: defaultPinTheme,
                focusedPinTheme: defaultPinTheme.copyDecorationWith(
                  border: Border.all(color: AppColors.primary, width: 1.5),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: _secondsRemaining == 0 && !_isResending ? _resendOtp : null,
                behavior: HitTestBehavior.opaque,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isResending)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      ),
                    if (_isResending) const SizedBox(width: 8),
                    Text(
                      _isResending ? 'Resending...' : 'Resend code',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: (_secondsRemaining == 0 && !_isResending)
                            ? AppColors.primary
                            : Colors.black45,
                        decoration: (_secondsRemaining == 0 && !_isResending)
                            ? TextDecoration.underline
                            : TextDecoration.none,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              if (_secondsRemaining > 0)
                Text(
                  'Request new code in 00:${_secondsRemaining.toString().padLeft(2, '0')}',
                  style: GoogleFonts.inter(fontSize: 18, color: Colors.black45),
                ),
              const Spacer(),
              SafeArea(
                minimum: const EdgeInsets.fromLTRB(0, 0, 0, 24),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isVerifying ? null : _verifyCode,
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
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                            'VERIFY',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

}
