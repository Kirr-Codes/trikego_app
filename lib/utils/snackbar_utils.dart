import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart' show AppColors;

/// Centralized SnackBar utility for consistent styling across the app
/// 
/// This utility provides uniform snackbars with consistent:
/// - Colors (success: green, error: red, info: primary, warning: orange)
/// - Positioning (floating behavior)
/// - Typography (Inter font with proper weights)
/// - Icons for better visual feedback
/// - Duration based on message type
class SnackBarUtils {
  
  /// Shows a success snackbar with green background
  /// 
  /// Used for: Successful operations, confirmations, completions
  /// Duration: 3 seconds
  static void showSuccess(BuildContext context, String message) {
    if (!_isContextValid(context)) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.check_circle_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
        elevation: 6,
      ),
    );
  }

  /// Shows an error snackbar with red background
  /// 
  /// Used for: Errors, failures, validation issues
  /// Duration: 4 seconds (longer for errors)
  static void showError(BuildContext context, String message) {
    if (!_isContextValid(context)) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
        elevation: 6,
      ),
    );
  }

  /// Shows an info snackbar with primary app color background
  /// 
  /// Used for: Information, notifications, general messages
  /// Duration: 3 seconds
  static void showInfo(BuildContext context, String message) {
    if (!_isContextValid(context)) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.info_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
        elevation: 6,
      ),
    );
  }

  /// Shows a warning snackbar with orange background
  /// 
  /// Used for: Warnings, cautions, important notices
  /// Duration: 4 seconds
  static void showWarning(BuildContext context, String message) {
    if (!_isContextValid(context)) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.warning_amber_outlined,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.orange.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
        elevation: 6,
      ),
    );
  }

  /// Shows an SMS/OTP specific snackbar with custom SMS icon
  /// 
  /// Used specifically for: SMS sent confirmations, OTP related messages
  /// Duration: 3 seconds
  static void showSMS(BuildContext context, String message) {
    if (!_isContextValid(context)) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.sms_outlined,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
        elevation: 6,
      ),
    );
  }

  /// Shows a loading snackbar that doesn't auto-dismiss
  /// 
  /// Used for: Long-running operations, processing states
  /// Duration: Indefinite (must be manually dismissed)
  /// 
  /// **Important:** Always call `hideCurrentSnackBar()` when operation completes
  static void showLoading(BuildContext context, String message) {
    if (!_isContextValid(context)) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(days: 1), // Effectively indefinite
        elevation: 6,
      ),
    );
  }

  /// Hides the currently displayed snackbar
  /// 
  /// Use this to manually dismiss loading snackbars or any other snackbar
  static void hide(BuildContext context) {
    if (!_isContextValid(context)) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
  }

  /// Validates if the context is still valid and mounted
  /// 
  /// Prevents errors when trying to show snackbars on disposed widgets
  static bool _isContextValid(BuildContext context) {
    try {
      return context.mounted;
    } catch (e) {
      return false;
    }
  }
}

/// Extension on BuildContext for convenient snackbar access
/// 
/// Usage:
/// ```dart
/// context.showSuccess('Operation completed!');
/// context.showError('Something went wrong');
/// context.showInfo('Here's some information');
/// ```
extension SnackBarExtension on BuildContext {
  void showSuccess(String message) => SnackBarUtils.showSuccess(this, message);
  void showError(String message) => SnackBarUtils.showError(this, message);
  void showInfo(String message) => SnackBarUtils.showInfo(this, message);
  void showWarning(String message) => SnackBarUtils.showWarning(this, message);
  void showSMS(String message) => SnackBarUtils.showSMS(this, message);
  void showLoading(String message) => SnackBarUtils.showLoading(this, message);
  void hideSnackBar() => SnackBarUtils.hide(this);
}
