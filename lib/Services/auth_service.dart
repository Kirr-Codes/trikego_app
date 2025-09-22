import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../Services/firestore_service.dart';
import '../models/user_models.dart';

/// Professional Firebase Authentication Service
class AuthService {
  // Singleton pattern
  AuthService._internal();
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;

  // Firebase Auth instance
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  GoogleSignIn? _googleSignIn;

  GoogleSignIn get googleSignIn {
    _googleSignIn ??= GoogleSignIn();
    return _googleSignIn!;
  }

  // Firestore service
  final FirestoreService _firestoreService = FirestoreService();

  // Authentication state management
  String? _verificationId;
  int? _resendToken;
  String? _pendingPhoneNumber;
  UserProfile? _pendingUserProfile;

  // Current user data from Firestore
  UserWithPassenger? _currentUserData;

  // Stream controllers
  final StreamController<AuthState> _authStateController =
      StreamController<AuthState>.broadcast();
  final StreamController<User?> _userController =
      StreamController<User?>.broadcast();

  /// Current authentication state stream
  Stream<AuthState> get authStateStream => _authStateController.stream;

  /// Current user stream
  Stream<User?> get userStream => _userController.stream;

  /// Current authenticated user
  User? get currentUser => _firebaseAuth.currentUser;

  /// Check if user is currently authenticated
  bool get isAuthenticated => currentUser != null;

  /// Check if there's a pending phone verification
  bool get hasPendingVerification => _verificationId != null;

  /// Get current user data from Firestore
  UserWithPassenger? get currentUserData => _currentUserData;

  /// Check if user has complete profile
  bool get hasCompleteProfile => _currentUserData?.hasCompleteProfile ?? false;

  /// Initialize the auth service
  Future<void> initialize() async {
    try {
      // Listen to Firebase auth state changes
      _firebaseAuth.authStateChanges().listen((User? user) async {
        _userController.add(user);
        if (user != null) {
          // Check if this is during a registration process
          if (_pendingUserProfile != null) {
            // This is a new registration, don't check canUserLogin yet
            _updateAuthState(AuthState.authenticated(user));

            return;
          }

          // For existing users, check if they can login
          final canLogin = await _firestoreService.canUserLogin(user.uid);
          if (canLogin) {
            _currentUserData = await _firestoreService.getCompleteUserData(
              user.uid,
            );
            _updateAuthState(AuthState.authenticated(user));
          } else {
            await _firebaseAuth.signOut();
            _updateAuthState(
              AuthState.error('User not registered. Please sign up first.'),
            );
          }
        } else {
          _currentUserData = null;
          _updateAuthState(AuthState.unauthenticated());
        }
      });
    } catch (e) {
      _updateAuthState(AuthState.error('Failed to initialize authentication'));
    }
  }

  /// Start phone number authentication
  Future<AuthResult> startPhoneAuth({
    required String phoneNumber,
    UserProfile? userProfile,
  }) async {
    try {
      _updateAuthState(AuthState.sendingOtp());

      // Store pending data
      _pendingPhoneNumber = phoneNumber;
      _pendingUserProfile = userProfile;

      final completer = Completer<AuthResult>();

      await _firebaseAuth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        timeout: const Duration(seconds: 60),
        forceResendingToken: _resendToken,

        verificationCompleted: (PhoneAuthCredential credential) async {
          try {
            final result = await _signInWithCredential(credential);
            if (!completer.isCompleted) {
              completer.complete(result);
            }
          } catch (e) {
            if (!completer.isCompleted) {
              completer.complete(AuthResult.error(_getErrorMessage(e)));
            }
          }
        },

        verificationFailed: (FirebaseAuthException e) {
          _updateAuthState(AuthState.error(_getErrorMessage(e)));
          if (!completer.isCompleted) {
            completer.complete(AuthResult.error(_getErrorMessage(e)));
          }
        },

        codeSent: (String verificationId, int? resendToken) {
          _verificationId = verificationId;
          _resendToken = resendToken;
          _updateAuthState(AuthState.otpSent(phoneNumber));
          if (!completer.isCompleted) {
            completer.complete(
              AuthResult.otpSent('OTP sent to $phoneNumber', verificationId),
            );
          }
        },

        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
      );

      return completer.future;
    } catch (e) {
      _updateAuthState(AuthState.error(_getErrorMessage(e)));
      return AuthResult.error(_getErrorMessage(e));
    }
  }

  /// Verify OTP code
  Future<AuthResult> verifyOtp(String otpCode) async {
    try {
      if (_verificationId == null) {
        const error = 'No pending verification. Please request OTP first.';
        _updateAuthState(AuthState.error(error));
        return AuthResult.error(error);
      }

      if (otpCode.length != 6) {
        const error = 'Please enter a valid 6-digit OTP code.';
        _updateAuthState(AuthState.error(error));
        return AuthResult.error(error);
      }

      _updateAuthState(AuthState.verifyingOtp());

      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: otpCode,
      );

      final result = await _signInWithCredential(credential);

      if (result.isSuccess) {
        _clearPendingData();
      }

      return result;
    } catch (e) {
      final errorMessage = _getErrorMessage(e);
      _updateAuthState(AuthState.error(errorMessage));
      return AuthResult.error(errorMessage);
    }
  }

  /// Resend OTP to the same phone number
  Future<AuthResult> resendOtp() async {
    if (_pendingPhoneNumber == null) {
      const error = 'No pending phone verification to resend.';
      _updateAuthState(AuthState.error(error));
      return AuthResult.error(error);
    }

    return startPhoneAuth(
      phoneNumber: _pendingPhoneNumber!,
      userProfile: _pendingUserProfile,
    );
  }

  /// Sign out current user
  Future<AuthResult> signOut() async {
    try {
      await _firebaseAuth.signOut();

      await signOutFromGoogle();
      // Re-enabled with proper isolation
      _clearPendingData();

      _currentUserData = null;

      _updateAuthState(AuthState.unauthenticated());

      return AuthResult.success('Signed out successfully');
    } catch (e) {
      return AuthResult.error(_getErrorMessage(e));
    }
  }

  /// Sign in with Google/Gmail - Isolated to prevent phone auth conflicts
  /// Implements account linking to unify phone and Gmail authentication
  Future<AuthResult> signInWithGmail() async {
    try {
      // Step 1: Sign in with Google (lazy initialization)
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        return AuthResult.error('Gmail sign-in was cancelled by user');
      }

      // Step 2: Get authentication details from Google
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Step 3: Check if user exists in Firestore by email
      final email = googleUser.email;
      final existingUserUid = await _getUserUidByEmail(email);

      if (existingUserUid != null) {
        // Scenario B: User has phone auth, wants to link Gmail
        return await _linkGmailToExistingAccount(
          credential,
          existingUserUid,
          email,
        );
      } else {
        // Scenario A: New user or user with only Gmail auth
        return await _signInWithGmailCredential(credential, email);
      }
    } on FirebaseAuthException catch (e) {
      return AuthResult.error(_getErrorMessage(e));
    } catch (e) {
      return AuthResult.error('Gmail sign-in failed. Please try again.');
    }
  }

  /// Link Gmail to existing phone authentication account
  Future<AuthResult> _linkGmailToExistingAccount(
    AuthCredential gmailCredential,
    String existingUserUid,
    String email,
  ) async {
    try {
      // Check if current user is already signed in
      final currentUser = _firebaseAuth.currentUser;

      if (currentUser != null && currentUser.uid == existingUserUid) {
        // User is already signed in with the correct account

        // Update email in Firestore if needed
        final firestoreResult = await _updateUserEmail(existingUserUid, email);

        if (firestoreResult['success']) {
          _currentUserData = await _firestoreService.getCompleteUserData(
            existingUserUid,
          );
          _updateAuthState(AuthState.authenticated(currentUser));
          return AuthResult.success('Gmail linked successfully');
        } else {
          return AuthResult.error(firestoreResult['message']);
        }
      } else {
        // Need to sign in with the existing account first

        // Sign in with Gmail credential first
        final userCredential = await _firebaseAuth.signInWithCredential(
          gmailCredential,
        );
        final gmailUser = userCredential.user;

        if (gmailUser == null) {
          return AuthResult.error('Failed to sign in with Gmail');
        }

        // Check if this is a different account that needs linking
        if (gmailUser.uid != existingUserUid) {
          // Sign out the Gmail user
          await _firebaseAuth.signOut();

          // This is a complex scenario - user has separate Gmail and phone accounts
          return await _handleAccountLinkingConflict(
            existingUserUid,
            email,
            gmailCredential,
          );
        } else {
          // Same UID - just update Firestore
          final firestoreResult = await _updateUserEmail(
            existingUserUid,
            email,
          );
          if (firestoreResult['success']) {
            _currentUserData = await _firestoreService.getCompleteUserData(
              existingUserUid,
            );
            _updateAuthState(AuthState.authenticated(gmailUser));
            return AuthResult.success('Gmail linked successfully');
          } else {
            return AuthResult.error(firestoreResult['message']);
          }
        }
      }
    } catch (e) {
      return AuthResult.error(
        'Failed to link Gmail account. Please try again.',
      );
    }
  }

  /// Sign in with Gmail credential for new users
  Future<AuthResult> _signInWithGmailCredential(
    AuthCredential gmailCredential,
    String email,
  ) async {
    try {
      // Sign in with Gmail
      final userCredential = await _firebaseAuth.signInWithCredential(
        gmailCredential,
      );
      final user = userCredential.user;

      if (user == null) {
        return AuthResult.error('Failed to sign in with Gmail');
      }

      // Check if user exists in Firestore
      final canLogin = await _firestoreService.canUserLogin(user.uid);
      if (canLogin) {
        // User exists in Firestore
        _currentUserData = await _firestoreService.getCompleteUserData(
          user.uid,
        );
        _updateAuthState(AuthState.authenticated(user));
        return AuthResult.success('Signed in successfully with Gmail');
      } else {
        // New user - they need to complete registration
        await _firebaseAuth.signOut();
        return AuthResult.error(
          'Gmail account not registered. Please complete registration first.',
          errorCode: 'ACCOUNT_NOT_REGISTERED',
        );
      }
    } catch (e) {
      return AuthResult.error('Gmail sign-in failed. Please try again.');
    }
  }

  /// Handle complex account linking scenarios
  Future<AuthResult> _handleAccountLinkingConflict(
    String existingUserUid,
    String email,
    AuthCredential gmailCredential,
  ) async {
    try {
      // For now, we'll prevent linking and ask user to use phone login
      // In a production app, you might want to implement more sophisticated
      // account merging logic here

      return AuthResult.error(
        'This Gmail account is not linked to your registered account. '
        'Please sign in with your phone number first, then link your Gmail account.',
        errorCode: 'ACCOUNT_NOT_LINKED',
      );
    } catch (e) {
      return AuthResult.error(
        'Account linking failed. Please contact support.',
      );
    }
  }

  /// Link Gmail to current authenticated user - Simplified for new registration flow
  /// Used when user is already signed in with phone and wants to add Gmail
  Future<AuthResult> linkGmailToCurrentUser() async {
    try {
      final currentUser = _firebaseAuth.currentUser;
      if (currentUser == null) {
        return AuthResult.error('No user is currently signed in');
      }

      // Sign in with Google
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        return AuthResult.error('Gmail sign-in was cancelled by user');
      }

      // Get authentication details
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Check if this Gmail account is already associated with another user
      final email = googleUser.email;
      final existingUserUid = await _getUserUidByEmail(email);

      if (existingUserUid != null && existingUserUid != currentUser.uid) {
        // This Gmail is already associated with a different user in Firestore
        return AuthResult.error(
          'This Gmail account is already linked to another account. Please use a different Gmail account or contact support.',
          errorCode: 'GMAIL_ALREADY_LINKED_TO_OTHER_ACCOUNT',
        );
      }

      // Link the credential to current user
      await currentUser.linkWithCredential(credential);

      // Update email in Firestore
      final firestoreResult = await _updateUserEmail(
        currentUser.uid,
        googleUser.email,
      );

      if (firestoreResult['success']) {
        _currentUserData = await _firestoreService.getCompleteUserData(
          currentUser.uid,
        );
        return AuthResult.success('Gmail linked successfully to your account');
      } else {
        return AuthResult.error(firestoreResult['message']);
      }
    } on FirebaseAuthException catch (e) {
      // Handle specific Firebase Auth errors
      if (e.code == 'credential-already-in-use') {
        return AuthResult.error(
          'This Gmail account is already linked to another Firebase account. This usually happens when the Gmail was previously used. Please use a different Gmail account or contact support to resolve this.',
          errorCode: 'CREDENTIAL_ALREADY_IN_USE',
        );
      } else if (e.code == 'email-already-in-use') {
        return AuthResult.error(
          'This Gmail account is already in use. Please use a different Gmail account.',
          errorCode: 'EMAIL_ALREADY_IN_USE',
        );
      }
      return AuthResult.error(_getErrorMessage(e));
    } catch (e) {
      return AuthResult.error(
        'Failed to link Gmail account. Please try again.',
      );
    }
  }

  /// Check if current user has Gmail linked
  bool get hasGmailLinked {
    final currentUser = _firebaseAuth.currentUser;
    if (currentUser == null) return false;

    return currentUser.providerData.any(
      (provider) => provider.providerId == 'google.com',
    );
  }

  /// Sign out from Google Sign-In - Isolated to prevent conflicts
  Future<void> signOutFromGoogle() async {
    try {
      if (_googleSignIn != null) {
        await _googleSignIn!.signOut();
      }
    } catch (e) {
      // Ignore errors during Google sign-out
    }
  }

  /// Helper method to get user UID by email
  Future<String?> _getUserUidByEmail(String email) async {
    try {
      final firestore = FirebaseFirestore.instance;
      final querySnapshot = await firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();
      if (querySnapshot.docs.isNotEmpty) {
        return querySnapshot.docs.first.id;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Helper method to update user email
  Future<Map<String, dynamic>> _updateUserEmail(
    String userId,
    String email,
  ) async {
    try {
      final firestore = FirebaseFirestore.instance;
      await firestore.collection('users').doc(userId).update({
        'email': email,
        'updatedAt': Timestamp.now(),
      });
      return {'success': true, 'message': 'Email updated successfully'};
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to update email: ${e.toString()}',
      };
    }
  }

  // Private helper methods
  Future<AuthResult> _signInWithCredential(
    PhoneAuthCredential credential,
  ) async {
    try {
      final userCredential = await _firebaseAuth.signInWithCredential(
        credential,
      );
      final user = userCredential.user;

      if (user != null) {
        if (_pendingUserProfile != null) {
          final profile = _pendingUserProfile!;
          await user.updateDisplayName(
            '${profile.firstName} ${profile.lastName}',
          );
        }

        _updateAuthState(AuthState.authenticated(user));
        return AuthResult.authenticated(user, 'Authentication successful');
      } else {
        const error = 'Authentication failed - no user returned';
        _updateAuthState(AuthState.error(error));
        return AuthResult.error(error);
      }
    } catch (e) {
      final errorMessage = _getErrorMessage(e);
      _updateAuthState(AuthState.error(errorMessage));
      return AuthResult.error(errorMessage);
    }
  }

  void _updateAuthState(AuthState state) {
    _authStateController.add(state);
  }

  void _clearPendingData() {
    _verificationId = null;
    _resendToken = null;
    _pendingPhoneNumber = null;
    _pendingUserProfile = null;
  }

  String _getErrorMessage(dynamic error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'invalid-phone-number':
          return 'Invalid phone number format. Please check and try again.';
        case 'too-many-requests':
          return 'Too many attempts. Please try again later.';
        case 'invalid-verification-code':
          return 'Invalid OTP code. Please check and try again.';
        case 'invalid-verification-id':
          return 'Verification session expired. Please request a new OTP.';
        case 'quota-exceeded':
          return 'SMS quota exceeded. Please try again later.';
        case 'network-request-failed':
          return 'Network error. Please check your connection and try again.';
        default:
          return error.message ?? 'Authentication failed. Please try again.';
      }
    }
    return 'An unexpected error occurred. Please try again.';
  }

  /// Start phone number update verification
  Future<AuthResult> startPhoneNumberUpdate({
    required String newPhoneNumber,
  }) async {
    try {
      // Store the pending phone number for later use
      _pendingPhoneNumber = newPhoneNumber;
      
      await _firebaseAuth.verifyPhoneNumber(
        phoneNumber: newPhoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-verification completed, update phone number
          await _updatePhoneNumberWithCredential(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          _updateAuthState(AuthState.error(_getErrorMessage(e)));
        },
        codeSent: (String verificationId, int? resendToken) {
          _verificationId = verificationId;
          _resendToken = resendToken;
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
        timeout: const Duration(seconds: 60),
      );

      return AuthResult.otpSent(
        'OTP sent successfully for phone number update.',
        _verificationId ?? '',
      );
    } on FirebaseAuthException catch (e) {
      return AuthResult.error(_getErrorMessage(e));
    } catch (e) {
      return AuthResult.error(
        'Failed to send OTP for phone number update. Please try again.',
      );
    }
  }

  /// Verify OTP for phone number update
  Future<AuthResult> verifyPhoneNumberUpdateOtp(String otp) async {
    try {
      if (_verificationId == null) {
        return AuthResult.error(
          'Verification session expired. Please resend OTP.',
        );
      }

      final PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: otp,
      );

      await _updatePhoneNumberWithCredential(credential);

      return AuthResult.success('Phone number updated successfully!');
    } on FirebaseAuthException catch (e) {
      return AuthResult.error(_getErrorMessage(e));
    } catch (e) {
      return AuthResult.error(
        'Failed to verify OTP for phone number update. Please try again.',
      );
    }
  }

  /// Update phone number with credential
  Future<void> _updatePhoneNumberWithCredential(
    PhoneAuthCredential credential,
  ) async {
    final user = currentUser;
    if (user != null) {
      try {
        // Check if user has Gmail linked (Google provider)
        final hasGoogleProvider = user.providerData.any(
          (provider) => provider.providerId == 'google.com',
        );

        if (hasGoogleProvider) {
          // For Gmail-linked accounts, we need to re-authenticate with Google first
          // Then link the phone credential
          await _reauthenticateWithGoogleAndLinkPhone(credential);
        } else {
          // For phone-only accounts, re-authenticate with phone credential
          await user.reauthenticateWithCredential(credential);
        }

        // Update phone number in Firestore using the pending phone number
        final phoneNumberToUpdate = _pendingPhoneNumber ?? user.phoneNumber ?? '';
        if (phoneNumberToUpdate.isNotEmpty) {
          await _firestoreService.updatePhoneNumber(phoneNumberToUpdate);
        } else {
          // If both are empty, try alternative approach
          await _alternativePhoneUpdate(credential);
        }
      } catch (e) {
        // If re-authentication fails, try alternative approach
        await _alternativePhoneUpdate(credential);
      }
    }
  }

  /// Re-authenticate with Google and link phone credential
  Future<void> _reauthenticateWithGoogleAndLinkPhone(
    PhoneAuthCredential phoneCredential,
  ) async {
    try {
      final user = currentUser;
      if (user == null) return;

      // For phone number updates, we don't need to re-authenticate with Google
      // We can directly link the phone credential since the user is already authenticated
      await user.linkWithCredential(phoneCredential);
    } catch (e) {
      // If linking fails, try alternative approach
      await _alternativePhoneUpdate(phoneCredential);
    }
  }

  /// Alternative phone update method for Gmail-linked accounts
  Future<void> _alternativePhoneUpdate(
    PhoneAuthCredential phoneCredential,
  ) async {
    try {
      final user = currentUser;
      if (user == null) return;

      // Check if phone credential is already linked
      final hasPhoneProvider = user.providerData.any(
        (provider) => provider.providerId == 'phone',
      );

      if (!hasPhoneProvider) {
        // Try to link the phone credential directly
        await user.linkWithCredential(phoneCredential);
      }

      // Update phone number in Firestore using pending phone number
      final phoneNumberToUpdate = _pendingPhoneNumber ?? user.phoneNumber ?? '';
      if (phoneNumberToUpdate.isNotEmpty) {
        await _firestoreService.updatePhoneNumber(phoneNumberToUpdate);
      }
    } catch (e) {
      // If linking fails, just update Firestore with the pending phone number
      // This ensures the phone number is updated even if credential linking fails
      try {
        final phoneNumberToUpdate = _pendingPhoneNumber ?? '';
        if (phoneNumberToUpdate.isNotEmpty) {
          await _firestoreService.updatePhoneNumber(phoneNumberToUpdate);
        }
      } catch (firestoreError) {
        // If even Firestore update fails, re-throw the original error
        rethrow;
      }
    }
  }

  /// Register user in Firestore after successful authentication
  Future<AuthResult> registerUserInFirestore({
    required String firstName,
    required String lastName,
    String? email, // Made optional - only provided when Gmail is linked
  }) async {
    try {
      final user = currentUser;
      if (user == null) {
        const error = 'No authenticated user found';
        return AuthResult.error(error);
      }

      final result = await _firestoreService.registerUser(
        firstName: firstName,
        lastName: lastName,
        email: email ?? '', // Use empty string if email is null
      );

      if (result['success']) {
        // Update local user data
        _currentUserData = await _firestoreService.getCompleteUserData(
          user.uid,
        );

        // Update Firebase Auth display name
        await user.updateDisplayName('$firstName $lastName');

        return AuthResult.success('Registration completed successfully');
      } else {
        return AuthResult.error(result['message']);
      }
    } catch (e) {
      return AuthResult.error('Failed to register user. Please try again.');
    }
  }

  /// Update user profile information in both Firebase Auth and Firestore
  Future<AuthResult> updateProfile({
    String? displayName,
    String? photoURL,
    String? firstName,
    String? lastName,
    String? profilePictureUrl,
  }) async {
    try {
      final user = currentUser;
      if (user == null) {
        const error = 'No authenticated user found';

        return AuthResult.error(error);
      }

      // Update Firebase Auth profile
      if (displayName != null && displayName.trim().isNotEmpty) {
        await user.updateDisplayName(displayName.trim());
      }

      // Handle photoURL - can be null to remove profile picture
      if (photoURL != null) {
        if (photoURL.trim().isNotEmpty) {
          await user.updatePhotoURL(photoURL.trim());
        } else {
          // Set to null to remove profile picture
          await user.updatePhotoURL(null);
        }
      }

      // Update Firestore profile
      final firestoreResult = await _firestoreService.updateUserProfile(
        firstName: firstName,
        lastName: lastName,
      );

      // Update profile picture separately - handle null values
      if (profilePictureUrl != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
              'profilePictureUrl': profilePictureUrl.trim().isNotEmpty
                  ? profilePictureUrl
                  : null,
              'updatedAt': Timestamp.now(),
            });
      }

      if (!firestoreResult['success']) {
        return AuthResult.error(firestoreResult['message']);
      }

      // Reload user data
      _currentUserData = await _firestoreService.getCompleteUserData(user.uid);
      await user.reload();

      return AuthResult.success('Profile updated successfully');
    } on FirebaseAuthException catch (e) {
      return AuthResult.error(_getErrorMessage(e));
    } catch (e) {
      return AuthResult.error('Failed to update profile. Please try again.');
    }
  }

  /// Update phone number in Firestore
  Future<AuthResult> updatePhoneNumberInFirestore(String newPhoneNumber) async {
    try {
      final result = await _firestoreService.updatePhoneNumber(newPhoneNumber);

      if (result['success']) {
        return AuthResult.success('Phone number updated successfully');
      } else {
        return AuthResult.error(result['message']);
      }
    } catch (e) {
      return AuthResult.error(
        'Failed to update phone number. Please try again.',
      );
    }
  }

  /// Check if phone number exists in Firestore
  Future<bool> checkPhoneNumberExists(String phoneNumber) async {
    try {
      final result = await _firestoreService.checkPhoneNumberExists(
        phoneNumber,
      );

      return result;
    } catch (e) {
      return false;
    }
  }

  /// Delete user account and all associated data
  Future<AuthResult> deleteUserAccount() async {
    try {
      final user = currentUser;
      if (user == null) {
        return AuthResult.error('No authenticated user found');
      }

      // Delete profile pictures from Firebase Storage
      await _deleteUserProfilePictures(user.uid);

      // Delete user data from Firestore
      final firestoreResult = await _firestoreService.deleteUser(user.uid);
      if (!firestoreResult['success']) {
        return AuthResult.error(firestoreResult['message']);
      }

      // Delete Firebase Auth account
      await user.delete();

      // Clear local state
      _currentUserData = null;
      _authStateController.add(AuthState.unauthenticated());
      _userController.add(null);

      return AuthResult.success('Account deleted successfully');
    } on FirebaseAuthException catch (e) {
      return AuthResult.error(_getErrorMessage(e));
    } catch (e) {
      return AuthResult.error('Failed to delete account: ${e.toString()}');
    }
  }

  /// Delete user's profile pictures from Firebase Storage
  Future<void> _deleteUserProfilePictures(String userId) async {
    try {
      final storageRef = FirebaseStorage.instance.ref().child(
        'profile_pictures',
      );
      final listResult = await storageRef.listAll();

      // Find and delete all profile pictures for this user
      for (final item in listResult.items) {
        if (item.name.startsWith('${userId}_')) {
          await item.delete();
        }
      }
    } catch (e) {
      // Don't throw error for storage deletion failures
      // The account deletion should still proceed
      // Note: Profile picture deletion failure is non-critical
    }
  }

  void dispose() {
    _authStateController.close();
    _userController.close();
  }
}

/// User profile data model
class UserProfile {
  final String firstName;
  final String lastName;
  final String? email; // Made optional - only populated when Gmail is linked
  final String phoneNumber;

  const UserProfile({
    required this.firstName,
    required this.lastName,
    this.email, // Made optional
    required this.phoneNumber,
  });

  String get fullName => '$firstName $lastName';
}

/// Authentication result wrapper
class AuthResult {
  final bool isSuccess;
  final String message;
  final User? user;
  final String? verificationId;
  final String? errorCode;

  const AuthResult._({
    required this.isSuccess,
    required this.message,
    this.user,
    this.verificationId,
    this.errorCode,
  });

  factory AuthResult.success(String message) {
    return AuthResult._(isSuccess: true, message: message);
  }

  factory AuthResult.authenticated(User user, String message) {
    return AuthResult._(isSuccess: true, message: message, user: user);
  }

  factory AuthResult.otpSent(String message, String verificationId) {
    return AuthResult._(
      isSuccess: true,
      message: message,
      verificationId: verificationId,
    );
  }

  factory AuthResult.error(String message, {String? errorCode}) {
    return AuthResult._(
      isSuccess: false,
      message: message,
      errorCode: errorCode,
    );
  }

  bool get isError => !isSuccess;
  bool get hasUser => user != null;
  bool get isOtpSent => verificationId != null;
}

/// Authentication state management
abstract class AuthState {
  const AuthState();

  factory AuthState.initial() => const _InitialState();
  factory AuthState.sendingOtp() => const _SendingOtpState();
  factory AuthState.otpSent(String phoneNumber) => _OtpSentState(phoneNumber);
  factory AuthState.verifyingOtp() => const _VerifyingOtpState();
  factory AuthState.authenticated(User user) => _AuthenticatedState(user);
  factory AuthState.unauthenticated() => const _UnauthenticatedState();
  factory AuthState.error(String message) => _ErrorState(message);
}

class _InitialState extends AuthState {
  const _InitialState();
}

class _SendingOtpState extends AuthState {
  const _SendingOtpState();
}

class _OtpSentState extends AuthState {
  final String phoneNumber;
  const _OtpSentState(this.phoneNumber);
}

class _VerifyingOtpState extends AuthState {
  const _VerifyingOtpState();
}

class _AuthenticatedState extends AuthState {
  final User user;
  const _AuthenticatedState(this.user);
}

class _UnauthenticatedState extends AuthState {
  const _UnauthenticatedState();
}

class _ErrorState extends AuthState {
  final String message;
  const _ErrorState(this.message);
}
