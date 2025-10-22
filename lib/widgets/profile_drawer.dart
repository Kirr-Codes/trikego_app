import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart' show AppColors;
import '../utils/snackbar_utils.dart';
import '../Services/auth_service.dart';

class ProfileDrawer extends StatefulWidget {
  const ProfileDrawer({super.key});

  @override
  State<ProfileDrawer> createState() => _ProfileDrawerState();
}

class _ProfileDrawerState extends State<ProfileDrawer> {
  final AuthService _authService = AuthService();

  @override
  Widget build(BuildContext context) {
    final userData = _authService.currentUserData;
    final user = _authService.currentUser;
    return Drawer(
      backgroundColor: AppColors.primary,
      child: SafeArea(
        child: Column(
          children: [
            // Profile Section
            Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Profile Avatar
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                        width: 2,
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 38,
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      backgroundImage: userData?.user.profilePictureUrl != null
                          ? NetworkImage(userData!.user.profilePictureUrl!)
                          : null,
                      child: userData?.user.profilePictureUrl == null
                          ? Icon(
                              Icons.person,
                              size: 40,
                              color: Colors.white.withValues(alpha: 0.9),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Name
                  Text(
                    userData?.displayName ?? user?.displayName ?? 'User',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.visible,
                  ),
                  const SizedBox(height: 4),

                  // Phone Number
                  Text(
                    userData?.user.phoneNum ??
                        user?.phoneNumber ??
                        'No phone number',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.visible,
                  ),
                  const SizedBox(height: 20),

                  // Divider
                  Container(
                    height: 1,
                    width: double.infinity,
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                ],
              ),
            ),

            // Menu Items
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    _buildMenuItem(
                      icon: Icons.person_outline,
                      title: 'Edit profile',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(context, '/edit_profile');
                      },
                    ),
                    _buildMenuItem(
                      icon: Icons.history,
                      title: 'History',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(context, '/history');
                      },
                    ),
                    _buildMenuItem(
                      icon: Icons.settings_outlined,
                      title: 'Settings',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(context, '/settings');
                      },
                    ),
                    _buildMenuItem(
                      icon: Icons.info_outline,
                      title: 'About Us',
                      onTap: () {
                        Navigator.pop(context);
                        _showAboutDialog(context);
                      },
                    ),
                  ],
                ),
              ),
            ),

            // Logout Button
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _handleLogout(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF2E5BBA),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 3,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.logout, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Logout',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds a menu item with icon, title, and tap handler
  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: Colors.white, size: 24),
        title: Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        hoverColor: Colors.white.withValues(alpha: 0.1),
        splashColor: Colors.white.withValues(alpha: 0.2),
      ),
    );
  }

  /// Handles logout functionality
  void _handleLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Logout',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 20),
          ),
          content: Text(
            'Are you sure you want to logout?',
            style: GoogleFonts.inter(fontSize: 16, color: Colors.black87),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600],
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => _confirmLogout(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Logout',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Confirms and executes logout
  void _confirmLogout(BuildContext context) async {
    Navigator.pop(context); // Close dialog
    Navigator.pop(context); // Close drawer

    try {
      final result = await _authService.signOut();

      if (context.mounted) {
        if (result.isSuccess) {
          // Navigate to landing page and clear navigation stack
          Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
        } else {
          context.showError(result.message);
        }
      }
    } catch (e) {
      if (context.mounted) {
        context.showError('Failed to logout. Please try again.');
      }
    }
  }

  /// Shows about dialog with app information
  void _showAboutDialog(BuildContext context) {
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
                          'About TrikeGO',
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
                        Text(
                          'Your Trusted Tricycle Booking Platform',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'TrikeGO is a modern transportation solution designed to connect passengers with registered PB TODA tricycle drivers in Paombong, Bulacan. Our mission is to provide safe, reliable, and affordable transportation while supporting local drivers and their communities.',
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            color: Colors.grey.shade700,
                            height: 1.5,
                            letterSpacing: -0.1,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildAboutSection(
                          'Our Vision',
                          'To revolutionize local transportation by making tricycle rides more accessible, efficient, and convenient for everyone.',
                        ),
                        const SizedBox(height: 16),
                        _buildAboutSection(
                          'Key Features',
                          '• Real-time driver tracking\n'
                          '• Transparent fare calculation\n'
                          '• Secure booking system\n'
                          '• In-app notifications\n'
                          '• Ride history tracking',
                        ),
                        const SizedBox(height: 16),
                        _buildAboutSection(
                          'Our Commitment',
                          'We are committed to ensuring passenger safety, driver welfare, and community development. All our drivers are verified members of PB TODA, ensuring quality service and accountability.',
                        ),
                        const SizedBox(height: 16),
                        Divider(color: Colors.grey.shade300, height: 1),
                        const SizedBox(height: 12),
                        Text(
                          'Version 1.0.0',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '© 2024 TrikeGO - PB TODA',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
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

  Widget _buildAboutSection(String title, String content) {
    return Column(
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
        const SizedBox(height: 10),
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
    );
  }
}
