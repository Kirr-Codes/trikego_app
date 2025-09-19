import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart' show AppColors;
import '../Services/auth_service.dart';
import '../models/user_models.dart';
import '../utils/snackbar_utils.dart';

class AccountSettingsScreen extends StatelessWidget {
  const AccountSettingsScreen({super.key});

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
          'Account',
          style: GoogleFonts.inter(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Linked Account Section
          _buildSectionDivider(),
          _buildSectionHeader('Linked Account'),
          const SizedBox(height: 12),
          _buildLinkedAccountCard(context),

          const SizedBox(height: 24),

          // Delete Account Section
          _buildSectionDivider(),
          _buildSectionHeader('Delete Account', isDestructive: true),
          const SizedBox(height: 8),
          _buildDeleteAccountSection(context),
        ],
      ),
    );
  }

  Widget _buildSectionDivider() {
    return Container(
      height: 1,
      color: Colors.grey[300],
      margin: const EdgeInsets.symmetric(horizontal: 20),
    );
  }

  Widget _buildSectionHeader(String title, {bool isDestructive = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: isDestructive ? Colors.red : Colors.black87,
          ),
        ),
      ),
    );
  }

  Widget _buildLinkedAccountCard(BuildContext context) {
    final authService = AuthService();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            // Google Logo
            Container(
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
            const SizedBox(width: 12),
            // Google Text with user's email
            Expanded(
              child: FutureBuilder<UserWithPassenger?>(
                future: Future.value(authService.currentUserData),
                builder: (context, userDataSnapshot) {
                  if (userDataSnapshot.hasData &&
                      userDataSnapshot.data != null) {
                    final userData = userDataSnapshot.data!;
                    final userEmail = userData.user.email;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Google',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.black,
                          ),
                        ),
                        if (userEmail.isNotEmpty)
                          Text(
                            userEmail,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: Colors.grey[600],
                            ),
                          ),
                      ],
                    );
                  } else {
                    return Text(
                      'Google',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.black,
                      ),
                    );
                  }
                },
              ),
            ),
            // Status and Action
            FutureBuilder<UserWithPassenger?>(
              future: Future.value(authService.currentUserData),
              builder: (context, snapshot) {
                final userData = snapshot.data;
                final isGmailLinked =
                    userData != null && authService.hasGmailLinked;

                if (isGmailLinked) {
                  return Row(
                    children: [
                      Text(
                        'Connected',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.green[600],
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => _unlinkGmailAccount(context, authService),
                        child: Text(
                          'Disconnect',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.red[600],
                          ),
                        ),
                      ),
                    ],
                  );
                } else {
                  return GestureDetector(
                    onTap: () => _linkGmailAccount(context, authService),
                    child: Text(
                      'Connect',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeleteAccountSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Warning text
          Text(
            'Permanently remove your account and data.',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Proceed with caution.',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 12),
          // Delete button with arrow
          GestureDetector(
            onTap: () => _deleteAccount(context),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'Delete',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.red,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _linkGmailAccount(BuildContext context, AuthService authService) async {
    try {
      context.showLoading('Linking Gmail...');

      final result = await authService.linkGmailToCurrentUser();

        if (context.mounted) {
          context.hideSnackBar(); // Hide loading snackbar

          if (result.isSuccess) {
            context.showSuccess(result.message);
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

  void _unlinkGmailAccount(
    BuildContext context,
    AuthService authService,
  ) async {
    // Show confirmation dialog
    final shouldUnlink = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Unlink Gmail',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to unlink your Gmail account? You will need to use your phone number to sign in.',
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(color: Colors.grey[600]),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Unlink',
              style: GoogleFonts.inter(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (shouldUnlink == true && context.mounted) {
      try {
        context.showLoading('Unlinking Gmail...');

        // Add timeout to prevent hanging
        final result = await authService.unlinkGmailFromCurrentUser().timeout(
          const Duration(seconds: 10),
        );

        if (context.mounted) {
          context.hideSnackBar(); // Hide loading snackbar

          if (result.isSuccess) {
            context.showSuccess(result.message);
          } else {
            context.showError(result.message);
          }
        }
      } on TimeoutException {
        if (context.mounted) {
          context.hideSnackBar(); // Hide loading snackbar
          context.showError('Gmail unlinking timed out. Please try again.');
        }
      } catch (e) {
        if (context.mounted) {
          context.hideSnackBar(); // Hide loading snackbar
          context.showError(
            'Failed to unlink Gmail account. Please try again.',
          );
        }
      }
    }
  }

  void _deleteAccount(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Delete Account',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            color: Colors.red,
          ),
        ),
        content: Text(
          'Are you sure you want to permanently delete your account? This action cannot be undone.',
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(color: Colors.grey[600]),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Implement account deletion
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Account deletion - Coming soon!'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: Text(
              'Delete',
              style: GoogleFonts.inter(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
