import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pinput/pinput.dart';
import '../main.dart' show AppColors;
import '../Services/auth_service.dart';
import '../utils/snackbar_utils.dart';

class PhoneUpdateOtpPage extends StatefulWidget {
  final String newPhoneNumber;

  const PhoneUpdateOtpPage({
    super.key,
    required this.newPhoneNumber,
  });

  @override
  State<PhoneUpdateOtpPage> createState() => _PhoneUpdateOtpPageState();
}

class _PhoneUpdateOtpPageState extends State<PhoneUpdateOtpPage> {
  final TextEditingController codeController = TextEditingController();
  final AuthService _authService = AuthService();

  static const int initialSeconds = 60;
  late int secondsRemaining;
  Timer? _timer;
  bool isVerifying = false;
  bool isResending = false;

  @override
  void initState() {
    super.initState();
    secondsRemaining = initialSeconds;
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    codeController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() {
      secondsRemaining = initialSeconds;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;

      setState(() {
        if (secondsRemaining > 0) {
          secondsRemaining--;
        } else {
          timer.cancel();
        }
      });
    });
  }

  Future<void> _resendOtp() async {
    if (isResending || secondsRemaining > 0) return;

    setState(() => isResending = true);

    try {
      final result = await _authService.startPhoneNumberUpdate(
        newPhoneNumber: widget.newPhoneNumber,
      );

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
        setState(() => isResending = false);
      }
    }
  }

  Future<void> _verifyCode() async {
    final code = codeController.text.trim();

    if (code.length != 6) {
      context.showError('Please enter a valid 6-digit OTP code.');
      return;
    }

    setState(() => isVerifying = true);

    try {
      final result = await _authService.verifyPhoneNumberUpdateOtp(code);

      if (!mounted) return;

      if (result.isSuccess) {
        context.showSuccess(result.message);
        Navigator.pop(context, true); // Return true to indicate success
      } else {
        context.showError(result.message);
      }
    } catch (e) {
      if (mounted) {
        context.showError('Verification failed. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() => isVerifying = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final defaultPinTheme = PinTheme(
      width: 58,
      height: 58,
      textStyle: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w600),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withValues(alpha: 0.12)),
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
                controller: codeController,
                length: 6,
                defaultPinTheme: defaultPinTheme,
                focusedPinTheme: defaultPinTheme.copyDecorationWith(
                  border: Border.all(color: AppColors.primary, width: 1.5),
                ),
                keyboardType: TextInputType.number,
                onCompleted: (pin) => _verifyCode(),
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: secondsRemaining == 0 && !isResending ? _resendOtp : null,
                behavior: HitTestBehavior.opaque,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isResending)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      ),
                    if (isResending) const SizedBox(width: 8),
                    Text(
                      isResending ? 'Resending...' : 'Resend code',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: (secondsRemaining == 0 && !isResending)
                            ? AppColors.primary
                            : Colors.black45,
                        decoration: (secondsRemaining == 0 && !isResending)
                            ? TextDecoration.underline
                            : TextDecoration.none,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              if (secondsRemaining > 0)
                Text(
                  'Request new code in 00:${secondsRemaining.toString().padLeft(2, '0')}',
                  style: GoogleFonts.inter(fontSize: 18, color: Colors.black45),
                ),
              const Spacer(),
              SafeArea(
                minimum: const EdgeInsets.fromLTRB(0, 0, 0, 24),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isVerifying ? null : _verifyCode,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 3,
                    ),
                    child: isVerifying
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
