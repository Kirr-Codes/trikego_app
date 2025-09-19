import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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

  // Google Sign-In instance - Lazy initialization to prevent conflicts
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
            _log('New user authenticated during registration: ${user.uid}');
            return;
          }

          // For existing users, check if they can login
          final canLogin = await _firestoreService.canUserLogin(user.uid);
          if (canLogin) {
            _currentUserData = await _firestoreService.getCompleteUserData(
              user.uid,
            );
            _updateAuthState(AuthState.authenticated(user));
            _log('User authenticated: ${user.uid}');
          } else {
            _log('User not found in Firestore or inactive: ${user.uid}');
            await _firebaseAuth.signOut();
            _updateAuthState(
              AuthState.error('User not registered. Please sign up first.'),
            );
          }
        } else {
          _currentUserData = null;
          _updateAuthState(AuthState.unauthenticated());
          _log('User signed out');
        }
      });

      _log('AuthService initialized successfully');
    } catch (e) {
      _logError('Failed to initialize AuthService', e);
      _updateAuthState(AuthState.error('Failed to initialize authentication'));
    }
  }

  /// Start phone number authentication
  Future<AuthResult> startPhoneAuth({
    required String phoneNumber,
    UserProfile? userProfile,
  }) async {
    try {
      _log('Starting phone authentication for: $phoneNumber');
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
            _log('Auto-verification completed');
            final result = await _signInWithCredential(credential);
            if (!completer.isCompleted) {
              completer.complete(result);
            }
          } catch (e) {
            _logError('Auto-verification failed', e);
            if (!completer.isCompleted) {
              completer.complete(AuthResult.error(_getErrorMessage(e)));
            }
          }
        },

        verificationFailed: (FirebaseAuthException e) {
          _logError('Phone verification failed', e);
          _updateAuthState(AuthState.error(_getErrorMessage(e)));
          if (!completer.isCompleted) {
            completer.complete(AuthResult.error(_getErrorMessage(e)));
          }
        },

        codeSent: (String verificationId, int? resendToken) {
          _log('OTP sent successfully');
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
          _log('Auto-retrieval timeout for verification: $verificationId');
          _verificationId = verificationId;
        },
      );

      return completer.future;
    } catch (e) {
      _logError('Failed to start phone authentication', e);
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

      _log('Verifying OTP code');
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
      _logError('OTP verification failed', e);
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

    _log('Resending OTP to: $_pendingPhoneNumber');
    return startPhoneAuth(
      phoneNumber: _pendingPhoneNumber!,
      userProfile: _pendingUserProfile,
    );
  }

  /// Sign out current user
  Future<AuthResult> signOut() async {
    try {
      _log('Signing out user');
      await _firebaseAuth.signOut();
      await signOutFromGoogle(); // Re-enabled with proper isolation
      _clearPendingData();
      _currentUserData = null;
      _updateAuthState(AuthState.unauthenticated());
      return AuthResult.success('Signed out successfully');
    } catch (e) {
      _logError('Sign out failed', e);
      return AuthResult.error(_getErrorMessage(e));
    }
  }

  /// Sign in with Google/Gmail - Isolated to prevent phone auth conflicts
  /// Implements account linking to unify phone and Gmail authentication
  Future<AuthResult> signInWithGmail() async {
    try {
      _log('Starting Gmail sign-in process');

      // Step 1: Sign in with Google (lazy initialization)
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        return AuthResult.error('Gmail sign-in was cancelled by user');
      }

      // Step 2: Get authentication details from Google
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Step 3: Check if user exists in Firestore by email
      final email = googleUser.email;
      final existingUserUid = await _getUserUidByEmail(email);

      if (existingUserUid != null) {
        // Check if Gmail was previously unlinked
        final isGmailUnlinked = await _checkGmailUnlinkedStatus(existingUserUid);
        if (isGmailUnlinked) {
          _log('Gmail $email was previously unlinked, preventing sign-in');
          return AuthResult.error(
            'This Gmail account was previously unlinked. Please sign in with your phone number first.',
            errorCode: 'GMAIL_PREVIOUSLY_UNLINKED',
          );
        }
        
        // Scenario B: User has phone auth, wants to link Gmail
        _log('Found existing user with email $email, attempting account linking');
        return await _linkGmailToExistingAccount(credential, existingUserUid, email);
      } else {
        // Scenario A: New user or user with only Gmail auth
        _log('No existing user found, proceeding with direct Gmail sign-in');
        return await _signInWithGmailCredential(credential, email);
      }
    } on FirebaseAuthException catch (e) {
      _logError('Gmail sign-in failed with Firebase error', e);
      return AuthResult.error(_getErrorMessage(e));
    } catch (e) {
      _logError('Gmail sign-in failed', e);
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
      _log('Linking Gmail to existing account with UID: $existingUserUid');

      // Check if current user is already signed in
      final currentUser = _firebaseAuth.currentUser;
      
      if (currentUser != null && currentUser.uid == existingUserUid) {
        // User is already signed in with the correct account
        _log('User already signed in with correct account, updating email');
        
        // Update email in Firestore if needed
        final firestoreResult = await _updateUserEmail(existingUserUid, email);
        
        if (firestoreResult['success']) {
          // Clear the "unlinked" flag since Gmail is now linked again
          await _clearGmailUnlinkedFlag(existingUserUid);
          
          _currentUserData = await _firestoreService.getCompleteUserData(existingUserUid);
          _updateAuthState(AuthState.authenticated(currentUser));
          return AuthResult.success('Gmail linked successfully');
        } else {
          return AuthResult.error(firestoreResult['message']);
        }
      } else {
        // Need to sign in with the existing account first
        _log('Signing in with existing phone account for linking');
        
        // Sign in with Gmail credential first
        final userCredential = await _firebaseAuth.signInWithCredential(gmailCredential);
        final gmailUser = userCredential.user;
        
        if (gmailUser == null) {
          return AuthResult.error('Failed to sign in with Gmail');
        }

        // Check if this is a different account that needs linking
        if (gmailUser.uid != existingUserUid) {
          _log('Attempting to link different UID accounts');
          
          // Sign out the Gmail user
          await _firebaseAuth.signOut();
          
          // This is a complex scenario - user has separate Gmail and phone accounts
          return await _handleAccountLinkingConflict(existingUserUid, email, gmailCredential);
        } else {
          // Same UID - just update Firestore
          final firestoreResult = await _updateUserEmail(existingUserUid, email);
          if (firestoreResult['success']) {
            _currentUserData = await _firestoreService.getCompleteUserData(existingUserUid);
            _updateAuthState(AuthState.authenticated(gmailUser));
            return AuthResult.success('Gmail linked successfully');
          } else {
            return AuthResult.error(firestoreResult['message']);
          }
        }
      }
    } catch (e) {
      _logError('Failed to link Gmail to existing account', e);
      return AuthResult.error('Failed to link Gmail account. Please try again.');
    }
  }

  /// Sign in with Gmail credential for new users
  Future<AuthResult> _signInWithGmailCredential(
    AuthCredential gmailCredential,
    String email,
  ) async {
    try {
      _log('Signing in with Gmail credential for new user');

      // Sign in with Gmail
      final userCredential = await _firebaseAuth.signInWithCredential(gmailCredential);
      final user = userCredential.user;

      if (user == null) {
        return AuthResult.error('Failed to sign in with Gmail');
      }

      // Check if user exists in Firestore
      final canLogin = await _firestoreService.canUserLogin(user.uid);
      if (canLogin) {
        // User exists in Firestore
        _currentUserData = await _firestoreService.getCompleteUserData(user.uid);
        _updateAuthState(AuthState.authenticated(user));
        return AuthResult.success('Signed in successfully with Gmail');
      } else {
        // New user - they need to complete registration
        _log('New Gmail user, requiring registration completion');
        await _firebaseAuth.signOut();
        return AuthResult.error(
          'Gmail account not registered. Please complete registration first.',
          errorCode: 'ACCOUNT_NOT_REGISTERED',
        );
      }
    } catch (e) {
      _logError('Gmail credential sign-in failed', e);
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
      _log('Handling account linking conflict for UID: $existingUserUid');

      // For now, we'll prevent linking and ask user to use phone login
      // In a production app, you might want to implement more sophisticated
      // account merging logic here
      
      return AuthResult.error(
        'This Gmail account is not linked to your registered account. '
        'Please sign in with your phone number first, then link your Gmail account.',
        errorCode: 'ACCOUNT_NOT_LINKED',
      );
    } catch (e) {
      _logError('Account linking conflict resolution failed', e);
      return AuthResult.error('Account linking failed. Please contact support.');
    }
  }

  /// Link Gmail to current authenticated user - Isolated to prevent conflicts
  /// Used when user is already signed in with phone and wants to add Gmail
  Future<AuthResult> linkGmailToCurrentUser() async {
    try {
      final currentUser = _firebaseAuth.currentUser;
      if (currentUser == null) {
        return AuthResult.error('No user is currently signed in');
      }

      _log('Linking Gmail to current user: ${currentUser.uid}');

      // Sign in with Google (lazy initialization)
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        return AuthResult.error('Gmail sign-in was cancelled by user');
      }

      // Get authentication details
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Link the credential to current user
      await currentUser.linkWithCredential(credential);
      
      // Update email in Firestore
      final firestoreResult = await _updateUserEmail(currentUser.uid, googleUser.email);

      if (firestoreResult['success']) {
        _currentUserData = await _firestoreService.getCompleteUserData(currentUser.uid);
        return AuthResult.success('Gmail linked successfully to your account');
      } else {
        return AuthResult.error(firestoreResult['message']);
      }
    } on FirebaseAuthException catch (e) {
      _logError('Gmail linking failed with Firebase error', e);
      return AuthResult.error(_getErrorMessage(e));
    } catch (e) {
      _logError('Gmail linking failed', e);
      return AuthResult.error('Failed to link Gmail account. Please try again.');
    }
  }

  /// Unlink Gmail from current user account
  Future<AuthResult> unlinkGmailFromCurrentUser() async {
    try {
      final currentUser = _firebaseAuth.currentUser;
      if (currentUser == null) {
        return AuthResult.error('No user is currently signed in');
      }

      _log('Unlinking Gmail from current user: ${currentUser.uid}');

      // Check if user has Gmail provider
      final providers = currentUser.providerData
          .where((provider) => provider.providerId == 'google.com')
          .toList();

      if (providers.isEmpty) {
        return AuthResult.error('Gmail is not linked to this account');
      }

      // Unlink Gmail provider
      await currentUser.unlink('google.com');
      
      // Mark Gmail as unlinked in Firestore to prevent future Gmail sign-ins
      try {
        // Clear profile picture from Gmail by updating directly
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .update({
          'profilePictureUrl': null,
          'updatedAt': Timestamp.now(),
        });
        
        // Also mark the Gmail as unlinked in the user document
        await _markGmailUnlinked(currentUser.uid);
      } catch (e) {
        _log('Warning: Failed to update Firestore after unlinking Gmail: $e');
        // Continue anyway since the unlinking was successful
      }
      
      // Sync user data (with error handling)
      try {
        _currentUserData = await _firestoreService.getCompleteUserData(currentUser.uid);
      } catch (e) {
        _log('Warning: Failed to sync user data after unlinking Gmail: $e');
        // Continue anyway since the unlinking was successful
      }
      
      return AuthResult.success('Gmail unlinked successfully');
    } on FirebaseAuthException catch (e) {
      _logError('Gmail unlinking failed with Firebase error', e);
      return AuthResult.error(_getErrorMessage(e));
    } catch (e) {
      _logError('Gmail unlinking failed', e);
      return AuthResult.error('Failed to unlink Gmail account. Please try again.');
    }
  }

  /// Check if current user has Gmail linked
  bool get hasGmailLinked {
    final currentUser = _firebaseAuth.currentUser;
    if (currentUser == null) return false;
    
    return currentUser.providerData
        .any((provider) => provider.providerId == 'google.com');
  }

  /// Sign out from Google Sign-In - Isolated to prevent conflicts
  Future<void> signOutFromGoogle() async {
    try {
      if (_googleSignIn != null) {
        await _googleSignIn!.signOut();
        _log('Signed out from Google Sign-In');
      }
    } catch (e) {
      _logError('Failed to sign out from Google', e);
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
  Future<Map<String, dynamic>> _updateUserEmail(String userId, String email) async {
    try {
      final firestore = FirebaseFirestore.instance;
      await firestore.collection('users').doc(userId).update({
        'email': email,
        'updatedAt': Timestamp.now(),
      });
      return {
        'success': true,
        'message': 'Email updated successfully',
      };
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
        _log('User signed in successfully: ${user.uid}');

        if (_pendingUserProfile != null) {
          final profile = _pendingUserProfile!;
          await user.updateDisplayName(
            '${profile.firstName} ${profile.lastName}',
          );
          _log('User profile updated');
        }

        _updateAuthState(AuthState.authenticated(user));
        return AuthResult.authenticated(user, 'Authentication successful');
      } else {
        const error = 'Authentication failed - no user returned';
        _updateAuthState(AuthState.error(error));
        return AuthResult.error(error);
      }
    } catch (e) {
      _logError('Credential sign-in failed', e);
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

  void _log(String message) {
    if (kDebugMode) {
      print('🔐 AuthService: $message');
    }
  }

  void _logError(String message, dynamic error) {
    if (kDebugMode) {
      print('❌ AuthService Error: $message - $error');
    }
  }

  /// Start phone number update verification
  Future<AuthResult> startPhoneNumberUpdate({
    required String newPhoneNumber,
  }) async {
    try {
      _log('Starting phone number update verification for: $newPhoneNumber');

      await _firebaseAuth.verifyPhoneNumber(
        phoneNumber: newPhoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          _log('Phone verification completed automatically for update.');
          // Auto-verification completed, update phone number
          await _updatePhoneNumberWithCredential(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          _log(
            'Phone verification failed for update: ${e.code} - ${e.message}',
          );
          _updateAuthState(AuthState.error(_getErrorMessage(e)));
        },
        codeSent: (String verificationId, int? resendToken) {
          _verificationId = verificationId;
          _resendToken = resendToken;
          _log(
            'OTP code sent for phone update. Verification ID: $verificationId',
          );
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
          _log(
            'Code auto-retrieval timeout for phone update. Verification ID: $verificationId',
          );
        },
        timeout: const Duration(seconds: 60),
      );

      return AuthResult.otpSent(
        'OTP sent successfully for phone number update.',
        _verificationId ?? '',
      );
    } on FirebaseAuthException catch (e) {
      _log(
        'FirebaseAuthException in startPhoneNumberUpdate: ${e.code} - ${e.message}',
      );
      return AuthResult.error(_getErrorMessage(e));
    } catch (e) {
      _log('Unexpected error in startPhoneNumberUpdate: $e');
      return AuthResult.error(
        'Failed to send OTP for phone number update. Please try again.',
      );
    }
  }

  /// Verify OTP for phone number update
  Future<AuthResult> verifyPhoneNumberUpdateOtp(String otp) async {
    try {
      _log('Attempting to verify OTP for phone number update: $otp');

      if (_verificationId == null) {
        _log('Verification ID is null. Cannot verify OTP for phone update.');
        return AuthResult.error(
          'Verification session expired. Please resend OTP.',
        );
      }

      final PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: otp,
      );

      await _updatePhoneNumberWithCredential(credential);

      _log('Phone number update verified successfully.');
      return AuthResult.success('Phone number updated successfully!');
    } on FirebaseAuthException catch (e) {
      _log(
        'FirebaseAuthException in verifyPhoneNumberUpdateOtp: ${e.code} - ${e.message}',
      );
      return AuthResult.error(_getErrorMessage(e));
    } catch (e) {
      _log('Unexpected error in verifyPhoneNumberUpdateOtp: $e');
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
      // Re-authenticate with the credential to update phone number
      await user.reauthenticateWithCredential(credential);

      // Update phone number in Firestore
      final newPhoneNumber = user.phoneNumber ?? '';
      await _firestoreService.updatePhoneNumber(newPhoneNumber);

      _log(
        'Phone number updated successfully in both Firebase Auth and Firestore',
      );
    }
  }

  /// Register user in Firestore after successful authentication
  Future<AuthResult> registerUserInFirestore({
    required String firstName,
    required String lastName,
    required String email,
  }) async {
    try {
      final user = currentUser;
      if (user == null) {
        const error = 'No authenticated user found';
        _log('Registration failed: $error');
        return AuthResult.error(error);
      }

      _log('Registering user in Firestore: ${user.uid}');

      final result = await _firestoreService.registerUser(
        firstName: firstName,
        lastName: lastName,
        email: email,
      );

      if (result['success']) {
        // Update local user data
        _currentUserData = await _firestoreService.getCompleteUserData(
          user.uid,
        );

        // Update Firebase Auth display name
        await user.updateDisplayName('$firstName $lastName');

        _log('User registered successfully in Firestore');
        return AuthResult.success('Registration completed successfully');
      } else {
        _log('Firestore registration failed: ${result['message']}');
        return AuthResult.error(result['message']);
      }
    } catch (e) {
      _logError('Registration failed', e);
      return AuthResult.error('Failed to register user. Please try again.');
    }
  }

  /// Update user profile information in both Firebase Auth and Firestore
  Future<AuthResult> updateProfile({
    String? displayName,
    String? photoURL,
    String? firstName,
    String? lastName,
    String? email,
    String? profilePictureUrl,
  }) async {
    try {
      final user = currentUser;
      if (user == null) {
        const error = 'No authenticated user found';
        _log('Profile update failed: $error');
        return AuthResult.error(error);
      }

      _log('Updating user profile for user: ${user.uid}');

      // Update Firebase Auth profile
      if (displayName != null && displayName.trim().isNotEmpty) {
        await user.updateDisplayName(displayName.trim());
        _log('Display name updated to: $displayName');
      }

      if (photoURL != null && photoURL.trim().isNotEmpty) {
        await user.updatePhotoURL(photoURL.trim());
        _log('Photo URL updated');
      }

      // Update Firestore profile
      final firestoreResult = await _firestoreService.updateUserProfile(
        firstName: firstName,
        lastName: lastName,
        email: email,
      );

      // Update profile picture separately if provided
      if (profilePictureUrl != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
          'profilePictureUrl': profilePictureUrl,
          'updatedAt': Timestamp.now(),
        });
      }

      if (!firestoreResult['success']) {
        _log('Firestore profile update failed: ${firestoreResult['message']}');
        return AuthResult.error(firestoreResult['message']);
      }

      // Reload user data
      _currentUserData = await _firestoreService.getCompleteUserData(user.uid);
      await user.reload();

      _log('Profile updated successfully');
      return AuthResult.success('Profile updated successfully');
    } on FirebaseAuthException catch (e) {
      _logError('Firebase profile update failed', e);
      return AuthResult.error(_getErrorMessage(e));
    } catch (e) {
      _logError('Profile update failed', e);
      return AuthResult.error('Failed to update profile. Please try again.');
    }
  }

  /// Update phone number in Firestore
  Future<AuthResult> updatePhoneNumberInFirestore(String newPhoneNumber) async {
    try {
      final result = await _firestoreService.updatePhoneNumber(newPhoneNumber);

      if (result['success']) {
        _log('Phone number updated in Firestore');
        return AuthResult.success('Phone number updated successfully');
      } else {
        _log('Firestore phone update failed: ${result['message']}');
        return AuthResult.error(result['message']);
      }
    } catch (e) {
      _logError('Phone number update failed', e);
      return AuthResult.error(
        'Failed to update phone number. Please try again.',
      );
    }
  }

  /// Check if phone number exists in Firestore
  Future<bool> checkPhoneNumberExists(String phoneNumber) async {
    try {
      _log('Checking if phone number exists: $phoneNumber');

      final result = await _firestoreService.checkPhoneNumberExists(
        phoneNumber,
      );

      _log('Phone number check result: $result');
      return result;
    } catch (e) {
      _logError('Failed to check phone number existence', e);
      return false;
    }
  }

  /// Check if email exists in Firestore
  Future<bool> checkEmailExists(String email) async {
    try {
      _log('Checking if email exists: $email');

      final result = await _firestoreService.checkEmailExists(email);

      _log('Email check result: $result');
      return result;
    } catch (e) {
      _logError('Failed to check email existence', e);
      return false;
    }
  }

  /// Sync user data with Firestore
  Future<void> syncUserWithFirestore() async {
    try {
      final user = currentUser;
      if (user != null) {
        _currentUserData = await _firestoreService.getCompleteUserData(
          user.uid,
        );
        _log('User data synced with Firestore');
      }
    } catch (e) {
      _logError('Failed to sync user data', e);
    }
  }

  void dispose() {
    _authStateController.close();
    _userController.close();
  }

  // Helper method to check if Gmail was previously unlinked
  Future<bool> _checkGmailUnlinkedStatus(String userId) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      
      if (!userDoc.exists) return false;
      
      final data = userDoc.data();
      return data?['gmailUnlinked'] == true;
    } catch (e) {
      _logError('Failed to check Gmail unlinked status', e);
      return false;
    }
  }

  // Helper method to mark Gmail as unlinked
  Future<void> _markGmailUnlinked(String userId) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({
        'gmailUnlinked': true,
        'gmailUnlinkedAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      });
      _log('Gmail marked as unlinked for user: $userId');
    } catch (e) {
      _logError('Failed to mark Gmail as unlinked', e);
    }
  }

  // Helper method to clear Gmail unlinked flag
  Future<void> _clearGmailUnlinkedFlag(String userId) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({
        'gmailUnlinked': FieldValue.delete(),
        'gmailUnlinkedAt': FieldValue.delete(),
        'updatedAt': Timestamp.now(),
      });
      _log('Gmail unlinked flag cleared for user: $userId');
    } catch (e) {
      _logError('Failed to clear Gmail unlinked flag', e);
    }
  }
}

/// User profile data model
class UserProfile {
  final String firstName;
  final String lastName;
  final String email;
  final String phoneNumber;

  const UserProfile({
    required this.firstName,
    required this.lastName,
    required this.email,
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
    return AuthResult._(isSuccess: false, message: message, errorCode: errorCode);
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
