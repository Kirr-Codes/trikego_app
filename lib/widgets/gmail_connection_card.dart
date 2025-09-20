import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart' show AppColors;
import '../Services/auth_service.dart';
import '../models/user_models.dart';
import '../utils/snackbar_utils.dart';

class GmailConnectionCard extends StatefulWidget {
  const GmailConnectionCard({super.key});

  @override
  State<GmailConnectionCard> createState() => _GmailConnectionCardState();
}

class _GmailConnectionCardState extends State<GmailConnectionCard> {
  final AuthService _authService = AuthService();
  UserWithPassenger? _userData;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  void _loadUserData() async {
    final userData = _authService.currentUserData;
    if (mounted) {
      setState(() {
        _userData = userData;
      });
    }
  }

  @override
  Widget build(BuildContext context) {

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[200]!, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Google Logo with subtle background
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey[200]!, width: 1),
              ),
              child: Center(
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(
                    image: DecorationImage(
                      image: NetworkImage(
                        'https://developers.google.com/identity/images/g-logo.png',
                      ),
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Google Text with user's email
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Google Account',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (_userData != null && _userData!.user.email.isNotEmpty)
                    Text(
                      _userData!.user.email,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: Colors.grey[600],
                      ),
                    )
                  else
                    Text(
                      'Not connected',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: Colors.grey[500],
                      ),
                    ),
                ],
              ),
            ),
            // Status and Action
            _buildStatusAndAction(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusAndAction() {
    final isGmailLinked = _userData != null && _authService.hasGmailLinked;

    if (isGmailLinked) {
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 6,
          vertical: 3,
        ),
        decoration: BoxDecoration(
          color: Colors.green[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.green[200]!, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle,
              size: 10,
              color: Colors.green[600],
            ),
            const SizedBox(width: 2),
            Text(
              'Connected',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Colors.green[700],
              ),
            ),
          ],
        ),
      );
    } else {
      return GestureDetector(
        onTap: () => _linkGmailAccount(context),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.3),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            'Connect',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      );
    }
  }

  void _linkGmailAccount(BuildContext context) async {
    try {
      context.showLoading('Linking Gmail...');

      final result = await _authService.linkGmailToCurrentUser();

      if (context.mounted) {
        context.hideSnackBar(); // Hide loading snackbar

        if (result.isSuccess) {
          context.showSuccess(result.message);
          // Refresh the user data to update the UI
          _loadUserData();
        } else {
          context.showError(result.message);
        }
      }
    } catch (e) {
      if (context.mounted) {
        context.hideSnackBar(); // Hide loading snackbar
        context.showError('Failed to link Gmail account. Please try again.');
      }
    }
  }
}
