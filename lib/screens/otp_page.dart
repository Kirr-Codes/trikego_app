import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pinput/pinput.dart';
import '../main.dart' show AppColors;
import '../Services/auth_service.dart';
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
  final TextEditingController codeController = TextEditingController();
  final AuthService _authService = AuthService();

  static const int initialSeconds = 60;
  late int secondsRemaining;
  Timer? _timer;
  bool isVerifying = false;
  bool isResending = false;
  String phoneNumber = '';

  Future<void> _sendCode({bool isResend = false}) async {
    setState(() {
      isResending = isResend;
    });
    if (isResend) {
      await _authService.resendOTP(
        phoneNumber: widget.phoneNumber,
        onCodeSent: (message) {
          _showSuccessMessage(message);
          _startTimer();
        },
        onError: (error) {
          _showErrorMessage(error);
        },
      );
    } else {
      await _authService.sendOTP(
        phoneNumber: widget.phoneNumber,
        onCodeSent: (message) {
          _showSuccessMessage(message);
          _startTimer();
        },
        onVerificationCompleted: (_) async {
          if (!mounted) return;
          Navigator.pushReplacementNamed(context, '/homepage');
        },
        onError: (error) {
          _showErrorMessage(error);
        },
      );
    }
    if (!mounted) return;
    setState(() {
      isResending = false;
    });
  }

  @override
  void initState() {
    super.initState();
    secondsRemaining = initialSeconds;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _sendCode();
    });
    _startTimer();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Get phone number from navigation arguments
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is String) {
      phoneNumber = args;
    }
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

  Future<void> _verifyCode() async {
    setState(() {
      isVerifying = true;
    });
    try {
      final code = codeController.text.trim();
      if (code.length != 6) {
        _showErrorMessage('Enter the 6-digit code.');
        return;
      }
      final user = await _authService.verifyOTP(code);

      if (!mounted) return;

      if (user != null) {
        Navigator.pushReplacementNamed(context, '/homepage');
      } else {
        _showErrorMessage('Invalid OTP. Please try again.');
      }
    } catch (e) {
      _showErrorMessage(e.toString());
    } finally {
      if (mounted) {
        setState(() {
          isVerifying = false;
        });
      }
    }
  }

  void _resendCode() async {
    if (isResending || secondsRemaining > 0) return;
    await _sendCode(isResend: true);
  }

  void _showErrorMessage(String message) {
    if (!mounted) return;
    context.showError(message);
  }

  void _showSuccessMessage(String message) {
    if (!mounted) return;
    context.showSuccess(message);
  }

  @override
  void dispose() {
    _timer?.cancel();
    codeController.dispose();
    super.dispose();
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
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: secondsRemaining == 0 ? _resendCode : null,
                behavior: HitTestBehavior.opaque,
                child: Text(
                  'Resend code',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: secondsRemaining == 0
                        ? AppColors.primary
                        : Colors.black45,
                    decoration: secondsRemaining == 0
                        ? TextDecoration.underline
                        : TextDecoration.none,
                  ),
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
