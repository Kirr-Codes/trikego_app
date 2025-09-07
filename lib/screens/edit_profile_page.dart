import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:intl_phone_field/countries.dart';
import 'dart:io';
import '../main.dart' show AppColors;
import '../Services/auth_service.dart';
import '../utils/snackbar_utils.dart';
import 'phone_update_otp_page.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final AuthService _authService = AuthService();

  bool _isLoading = false;

  // Original values to track changes
  String _originalName = '';
  String _originalPhone = '';
  String _originalEmail = '';

  // Profile photo
  String? _profilePhotoUrl;
  File? _selectedImageFile;

  // Field editing states
  bool _isEditingName = false;
  bool _isEditingPhone = false;
  bool _isEditingEmail = false;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    // Add a small delay to ensure Firebase user data is fully loaded
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        _loadUserProfile();
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  /// Load current user profile data
  void _loadUserProfile() {
    final user = _authService.currentUser;
    if (user != null) {
      // Load display name if available
      final displayName = user.displayName ?? '';
      _nameController.text = displayName;
      _originalName = displayName;

      // Load phone number if available
      if (user.phoneNumber != null && user.phoneNumber!.isNotEmpty) {
        // Remove country code for display
        String phoneNumber = user.phoneNumber!;
        if (phoneNumber.startsWith('+63')) {
          final phoneWithoutCode = phoneNumber.substring(3);
          _mobileController.text = phoneWithoutCode;
          _originalPhone = phoneWithoutCode;
        }
      }

      // Load email - always load the email from Firebase Auth
      final email = user.email ?? '';
      _emailController.text = email;
      _originalEmail = email;

      // Debug print to check email loading
      print('Debug: User email: ${user.email}');
      print('Debug: Email controller text: ${_emailController.text}');

      // Load profile photo URL if available
      _profilePhotoUrl = user.photoURL;
    } else {
      print('Debug: No current user found');
    }
  }

  /// Check if any profile information has changed
  bool _hasChanges() {
    return _nameController.text.trim() != _originalName ||
           _mobileController.text.trim() != _originalPhone ||
           _emailController.text.trim() != _originalEmail ||
           _selectedImageFile != null;
  }

  /// Check if phone number has changed
  bool _hasPhoneNumberChanged() {
    return _mobileController.text.trim() != _originalPhone;
  }

  /// Handle phone number update with OTP verification
  Future<bool> _handlePhoneNumberUpdate() async {
    if (!_hasPhoneNumberChanged()) return true; // No phone change needed

    final newPhoneNumber = '+63${_mobileController.text.trim()}';
    
    try {
      // Start phone number update verification
      final result = await _authService.startPhoneNumberUpdate(
        newPhoneNumber: newPhoneNumber,
      );

      if (!mounted) return false;

      if (result.isSuccess) {
        // Navigate to OTP verification page
        final success = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (context) => PhoneUpdateOtpPage(
              newPhoneNumber: newPhoneNumber,
            ),
          ),
        );

        if (success == true) {
          // Phone number updated successfully
          _originalPhone = _mobileController.text.trim();
          return true;
        } else {
          // User cancelled or verification failed
          return false;
        }
      } else {
        context.showError(result.message);
        return false;
      }
    } catch (e) {
      if (mounted) {
        context.showError('Failed to start phone number verification. Please try again.');
      }
      return false;
    }
  }

  /// Show image picker options
  Future<void> _showImagePickerOptions() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Select Profile Photo',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildImagePickerOption(
                      icon: Icons.camera_alt,
                      label: 'Camera',
                      onTap: () {
                        Navigator.pop(context);
                        _pickImageFromCamera();
                      },
                    ),
                    _buildImagePickerOption(
                      icon: Icons.photo_library,
                      label: 'Gallery',
                      onTap: () {
                        Navigator.pop(context);
                        _pickImageFromGallery();
                      },
                    ),
                    if (_profilePhotoUrl != null || _selectedImageFile != null)
                      _buildImagePickerOption(
                        icon: Icons.delete,
                        label: 'Remove',
                        onTap: () {
                          Navigator.pop(context);
                          _removeProfilePhoto();
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Build image picker option widget
  Widget _buildImagePickerOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(icon, color: AppColors.primary, size: 30),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  /// Pick image from camera
  Future<void> _pickImageFromCamera() async {
    try {
      // For now, we'll show a placeholder message
      // In a real app, you would use image_picker package
      context.showInfo(
        'Camera functionality will be implemented with image_picker package',
      );
    } catch (e) {
      context.showError('Failed to access camera');
    }
  }

  /// Pick image from gallery
  Future<void> _pickImageFromGallery() async {
    try {
      // For now, we'll show a placeholder message
      // In a real app, you would use image_picker package
      context.showInfo(
        'Gallery functionality will be implemented with image_picker package',
      );
    } catch (e) {
      context.showError('Failed to access gallery');
    }
  }

  /// Remove profile photo
  void _removeProfilePhoto() {
    setState(() {
      _selectedImageFile = null;
      _profilePhotoUrl = null;
    });
    context.showInfo('Profile photo removed');
  }

  /// Build default avatar widget
  Widget _buildDefaultAvatar() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [const Color(0xFF8BB6FF), AppColors.primary],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.person,
          size: 60,
          color: Colors.white.withValues(alpha: 0.9),
        ),
      ),
    );
  }

  /// Show confirmation dialog before updating
  Future<bool> _showUpdateConfirmation() async {
    return await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                'Update Profile',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  fontSize: 20,
                ),
              ),
              content: Text(
                'Are you sure you want to update your profile information?',
                style: GoogleFonts.inter(fontSize: 16, color: Colors.black87),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    'Update',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  /// Handle profile update
  Future<void> _handleUpdate() async {
    if (!_formKey.currentState!.validate()) {
      context.showError('Please fill all required fields correctly.');
      return;
    }

    // Show confirmation dialog
    final confirmed = await _showUpdateConfirmation();
    if (!confirmed) return;

    setState(() => _isLoading = true);

    try {
      // First handle phone number update if changed
      if (_hasPhoneNumberChanged()) {
        final phoneUpdateSuccess = await _handlePhoneNumberUpdate();
        if (!phoneUpdateSuccess) {
          // Phone update failed or cancelled
          setState(() => _isLoading = false);
          return;
        }
      }

      // Update other profile information
      final result = await _authService.updateProfile(
        displayName: _nameController.text.trim(),
        photoURL: _profilePhotoUrl,
      );

      if (!mounted) return;

      if (result.isSuccess) {
        // Update original values after successful update
        _originalName = _nameController.text.trim();
        _originalEmail = _emailController.text.trim();

        context.showSuccess('Profile updated successfully!');
        Navigator.pop(context);
      } else {
        context.showError(result.message);
      }
    } catch (e) {
      if (mounted) {
        context.showError('Failed to update profile. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Input decoration for text fields
  InputDecoration _inputDecoration(String hint, {bool isReadOnly = false}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.inter(color: Colors.grey.shade500, fontSize: 16),
      filled: true,
      fillColor: isReadOnly ? Colors.grey.shade100 : Colors.grey.shade50,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isReadOnly ? Colors.grey.shade200 : Colors.grey.shade300,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isReadOnly ? Colors.grey.shade200 : Colors.grey.shade300,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.primary, width: 2),
      ),
      suffixIcon: isReadOnly
          ? Icon(Icons.edit, color: Colors.grey.shade600, size: 20)
          : null,
    );
  }

  /// Phone number field widget
  Widget _buildPhoneField() {
    return GestureDetector(
      onTap: !_isEditingPhone
          ? () {
              setState(() {
                _isEditingPhone = true;
              });
            }
          : null,
      child: IntlPhoneField(
        controller: _mobileController,
        enabled: _isEditingPhone,
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
        decoration: InputDecoration(
          hintText: 'Mobile Number',
          hintStyle: GoogleFonts.inter(
            color: Colors.grey.shade500,
            fontSize: 16,
          ),
          filled: true,
          fillColor: !_isEditingPhone
              ? Colors.grey.shade100
              : Colors.grey.shade50,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 18,
          ),
          // FIX 6: Explicitly set all border states to prevent blue border override
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: !_isEditingPhone
                  ? Colors.grey.shade200
                  : Colors.grey.shade300,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: !_isEditingPhone
                  ? Colors.grey.shade200
                  : Colors.grey.shade300,
            ),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color:
                  Colors.grey.shade200, // FIX 7: Specific disabled border color
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.primary, width: 2),
          ),
          // FIX 8: Override error border to maintain consistency
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red, width: 2),
          ),
          suffixIcon: !_isEditingPhone
              ? Icon(Icons.edit, color: Colors.grey.shade600, size: 20)
              : null,
        ),
        style: GoogleFonts.inter(
          fontSize: 16,
          color: _isEditingPhone ? Colors.black : Colors.grey.shade700,
        ),
        dropdownTextStyle: GoogleFonts.inter(fontSize: 16),
        flagsButtonPadding: const EdgeInsets.only(left: 8),
        onChanged: (phone) {
          setState(() {}); // Trigger rebuild to update button state
        },
        onSubmitted: (value) {
          setState(() {
            _isEditingPhone = false;
          });
        },
        validator: (phone) {
          if (phone == null || phone.number.isEmpty) {
            return 'Please enter your mobile number';
          }
          if (phone.number.length != 10) {
            return 'Please enter a valid 10-digit mobile number';
          }
          return null;
        },
      ),
    );
  }

  /// Exit edit mode for all fields
  void _exitEditMode() {
    setState(() {
      _isEditingName = false;
      _isEditingPhone = false;
      _isEditingEmail = false;
    });
    FocusScope.of(context).unfocus(); // Hide keyboard
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _exitEditMode, // Exit edit mode when tapping outside
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'Edit Profile',
            style: GoogleFonts.inter(
              color: Colors.black,
              fontWeight: FontWeight.w600,
              fontSize: 18,
            ),
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: Column(
            children: [
              // Scrollable content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        // Profile Avatar Section
                        Container(
                          margin: const EdgeInsets.only(bottom: 40),
                          child: GestureDetector(
                            onTap: _showImagePickerOptions,
                            child: Stack(
                              children: [
                                Container(
                                  width: 120,
                                  height: 120,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.primary.withValues(
                                      alpha: 0.1,
                                    ),
                                    border: Border.all(
                                      color: AppColors.primary.withValues(
                                        alpha: 0.2,
                                      ),
                                      width: 2,
                                    ),
                                  ),
                                  child: ClipOval(
                                    child: _selectedImageFile != null
                                        ? Image.file(
                                            _selectedImageFile!,
                                            fit: BoxFit.cover,
                                            width: 120,
                                            height: 120,
                                          )
                                        : _profilePhotoUrl != null
                                        ? Image.network(
                                            _profilePhotoUrl!,
                                            fit: BoxFit.cover,
                                            width: 120,
                                            height: 120,
                                            errorBuilder:
                                                (context, error, stackTrace) {
                                                  return _buildDefaultAvatar();
                                                },
                                          )
                                        : _buildDefaultAvatar(),
                                  ),
                                ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade600,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 3,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.camera_alt,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Name Field
                        TextFormField(
                          controller: _nameController,
                          readOnly: !_isEditingName,
                          decoration: _inputDecoration(
                            'Name',
                            isReadOnly: !_isEditingName,
                          ),
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            color: _isEditingName
                                ? Colors.black
                                : Colors.grey.shade700,
                          ),
                          onTap: !_isEditingName
                              ? () {
                                  setState(() {
                                    _isEditingName = true;
                                  });
                                }
                              : null,
                          onChanged: (value) => setState(
                            () {},
                          ), // Trigger rebuild to update button state
                          onFieldSubmitted: (value) {
                            setState(() {
                              _isEditingName = false;
                            });
                          },
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter your name';
                            }
                            if (value.trim().length < 2) {
                              return 'Name must be at least 2 characters';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),

                        // Mobile Number Field
                        _buildPhoneField(),
                        const SizedBox(height: 20),

                        // Email Field
                        TextFormField(
                          controller: _emailController,
                          readOnly: !_isEditingEmail,
                          decoration: _inputDecoration(
                            'Gmail',
                            isReadOnly: !_isEditingEmail,
                          ),
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            color: _isEditingEmail
                                ? Colors.black
                                : Colors.grey.shade700,
                          ),
                          keyboardType: TextInputType.emailAddress,
                          onTap: !_isEditingEmail
                              ? () {
                                  setState(() {
                                    _isEditingEmail = true;
                                  });
                                }
                              : null,
                          onChanged: (value) => setState(
                            () {},
                          ), // Trigger rebuild to update button state
                          onFieldSubmitted: (value) {
                            setState(() {
                              _isEditingEmail = false;
                            });
                          },
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter your email';
                            }
                            if (!RegExp(
                              r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                            ).hasMatch(value.trim())) {
                              return 'Please enter a valid email address';
                            }
                            return null;
                          },
                        ),

                        // Add extra space at bottom for keyboard
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
              ),

              // Fixed Update Button at bottom
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(color: Colors.white),
                child: SafeArea(
                  top: false,
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading || !_hasChanges()
                          ? null
                          : _handleUpdate,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _hasChanges()
                            ? AppColors.primary
                            : Colors.grey.shade400,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: _hasChanges() ? 2 : 0,
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
                              'Update',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                                color: _hasChanges()
                                    ? Colors.white
                                    : Colors.grey.shade600,
                              ),
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
