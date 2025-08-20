import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pinput/pinput.dart';
import '../main.dart' show AppColors;
import '../Services/auth_service.dart';

class OtpPage extends StatefulWidget {
  final String phoneNumber;
  const OtpPage({super.key, required this.phoneNumber});

  @override
  State<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends State<OtpPage> {
  final TextEditingController codeController = TextEditingController();
  static const int initialSeconds = 60;
  late int secondsRemaining;
  Timer? _timer;
  bool isSendingCode = false;
  bool isVerifying = false;
  String? _verificationId;
  int? _resendToken;

  void _startTimer() {
    _timer?.cancel();
    secondsRemaining = initialSeconds;
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

  Future<void> _sendCode() async {
    setState(() => isSendingCode = true);
    await AuthService().verifyPhoneNumber(
      phoneNumber: widget.phoneNumber,
      onCodeSent: (_) {
        if (!mounted) return;
        setState(() {
          isSendingCode = false;
          _verificationId = AuthService().verificationId;
          _resendToken = AuthService().resendToken;
        });
        _startTimer();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            backgroundColor: AppColors.primary,
            content: Row(
              children: const [
                Icon(Icons.sms_outlined, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'OTP sent',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      onVerificationCompleted: (_) async {
        if (!mounted) return;
        setState(() => isSendingCode = false);
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      },
      onVerificationFailed: (err) {
        if (!mounted) return;
        setState(() => isSendingCode = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            backgroundColor: Colors.red.shade700,
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Verification failed: $err',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      forceResendingToken: _resendToken,
    );
  }

  Future<void> _verifyCode() async {
    setState(() => isVerifying = true);
    try {
      final navigator = Navigator.of(context);
      final messenger = ScaffoldMessenger.of(context);
      final code = codeController.text.trim();
      final user = await AuthService().verifyOTP(code);
      if (!mounted) return;
      if (user != null) {
        navigator.pushNamedAndRemoveUntil('/', (route) => false);
      } else {
        messenger.showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            backgroundColor: Colors.red.shade700,
            content: Row(
              children: const [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Invalid OTP',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          backgroundColor: Colors.red.shade700,
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  e.toString(),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (mounted) setState(() => isVerifying = false);
  }

  void _resendCode() {
    if (secondsRemaining == 0) {
      _sendCode();
    }
  }

  @override
  void initState() {
    super.initState();
    secondsRemaining = initialSeconds;
    // Defer sending code until after first frame to avoid using context before init completes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Reset any previous session state on re-entry
      _timer?.cancel();
      secondsRemaining = initialSeconds;
      isSendingCode = false;
      isVerifying = false;
      // Bootstrap from AuthService if there is a pending verification (re-entry)
      _verificationId = AuthService().verificationId;
      _resendToken = AuthService().resendToken;
      if (_verificationId != null) {
        _startTimer();
      } else {
        _sendCode();
      }
    });
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
