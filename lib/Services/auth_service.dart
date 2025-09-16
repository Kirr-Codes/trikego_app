import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../services/firestore_service.dart';
import '../models/user_models.dart';

/// Professional Firebase Authentication Service
class AuthService {
  // Singleton pattern
  AuthService._internal();
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;

  // Firebase Auth instance
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

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
      _clearPendingData();
      _currentUserData = null;
      _updateAuthState(AuthState.unauthenticated());
      return AuthResult.success('Signed out successfully');
    } catch (e) {
      _logError('Sign out failed', e);
      return AuthResult.error(_getErrorMessage(e));
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

  const AuthResult._({
    required this.isSuccess,
    required this.message,
    this.user,
    this.verificationId,
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

  factory AuthResult.error(String message) {
    return AuthResult._(isSuccess: false, message: message);
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
