import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_models.dart';

/// Firestore Service for TrikeGO App
/// Handles all Firestore operations for user and passenger data
class FirestoreService {
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  FirestoreService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Collection names
  static const String _usersCollection = 'users';
  static const String _passengersCollection = 'passengers';

  /// Register a new user in Firestore
  /// Creates both USER and PASSENGER documents
  Future<Map<String, dynamic>> registerUser({
    required String firstName,
    required String lastName,
    required String email,
  }) async {
    try {
      await _auth.authStateChanges().first;

      final user = _auth.currentUser;
      if (user == null) {
        return {
          'success': false,
          'message': 'No authenticated user found',
          'error': 'NO_AUTH_USER',
        };
      }

      print('Current user UID: ${user.uid}');
      print('Phone number: ${user.phoneNumber}');
      print('Is anonymous: ${user.isAnonymous}');

      // Check if user already exists
      final userExists = await checkUserExists(user.uid);
      if (userExists) {
        return {
          'success': false,
          'message': 'User already registered',
          'error': 'USER_ALREADY_EXISTS',
        };
      }

      // Create user document
      final appUser = AppUser.fromFirebaseUser(
        userId: user.uid,
        phoneNumber: user.phoneNumber ?? '',
        email: email,
        userType: 1, // Passenger for mobile app
      );

      // Create passenger document
      final passenger = Passenger.fromUserInput(
        userId: user.uid,
        firstName: firstName,
        lastName: lastName,
      );

      // Use batch write for atomic operation
      final batch = _firestore.batch();

      // Add user document
      batch.set(
        _firestore.collection(_usersCollection).doc(user.uid),
        appUser.toFirestore(),
      );

      // Add passenger document
      batch.set(
        _firestore.collection(_passengersCollection).doc(user.uid),
        passenger.toFirestore(),
      );

      // Commit the batch with timeout and retry logic
      try {
        await batch.commit().timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            throw Exception('Firestore batch commit timeout');
          },
        );
      } catch (e) {
        // If it's a permission error, provide specific guidance
        if (e.toString().contains('permission-denied')) {
          throw Exception(
            'Permission denied: Please check Firestore security rules. Make sure authenticated users can write to Firestore.',
          );
        }

        try {
          await _firestore
              .collection(_usersCollection)
              .doc(user.uid)
              .set(appUser.toFirestore());
          await _firestore
              .collection(_passengersCollection)
              .doc(user.uid)
              .set(passenger.toFirestore());
        } catch (individualError) {
          rethrow;
        }
      }

      return {
        'success': true,
        'message': 'User registered successfully',
        'data': {'user': appUser, 'passenger': passenger},
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to register user: ${e.toString()}',
        'error': 'REGISTRATION_ERROR',
      };
    }
  }

  /// Check if user exists in Firestore
  Future<bool> checkUserExists(String userId) async {
    try {
      final doc = await _firestore
          .collection(_usersCollection)
          .doc(userId)
          .get();
      return doc.exists;
    } catch (e) {
      return false;
    }
  }

  /// Check if phone number exists in Firestore
  Future<bool> checkPhoneNumberExists(String phoneNumber) async {
    try {
      final querySnapshot = await _firestore
          .collection(_usersCollection)
          .where('phoneNum', isEqualTo: phoneNumber)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Check if email exists in Firestore
  Future<bool> checkEmailExists(String email) async {
    try {
      final querySnapshot = await _firestore
          .collection(_usersCollection)
          .where('email', isEqualTo: email)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Get user data from Firestore
  Future<AppUser?> getUser(String userId) async {
    try {
      final doc = await _firestore
          .collection(_usersCollection)
          .doc(userId)
          .get();

      if (doc.exists) {
        return AppUser.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Get passenger data from Firestore
  Future<Passenger?> getPassenger(String userId) async {
    try {
      final doc = await _firestore
          .collection(_passengersCollection)
          .doc(userId)
          .get();

      if (doc.exists) {
        return Passenger.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Get complete user data (user + passenger)
  Future<UserWithPassenger?> getCompleteUserData(String userId) async {
    try {
      final user = await getUser(userId);
      if (user == null) return null;

      final passenger = await getPassenger(userId);
      return UserWithPassenger(user: user, passenger: passenger);
    } catch (e) {
      return null;
    }
  }

  /// Update user profile
  Future<Map<String, dynamic>> updateUserProfile({
    String? firstName,
    String? lastName,
    String? email,
    String? profilePictureUrl,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return {
          'success': false,
          'message': 'No authenticated user found',
          'error': 'NO_AUTH_USER',
        };
      }

      final batch = _firestore.batch();
      bool hasUpdates = false;

      // Update user document if email is provided
      if (email != null || profilePictureUrl != null) {
        {
          final userDocRef = _firestore
              .collection(_usersCollection)
              .doc(user.uid);
          final updateData = <String, dynamic>{'updatedAt': Timestamp.now()};

          if (email != null) updateData['email'] = email;
          if (profilePictureUrl != null) {
            updateData['profilePictureUrl'] = profilePictureUrl;
          }

          batch.update(userDocRef, updateData);
          hasUpdates = true;
        }
      }
      // Update passenger document if name fields are provided
      if (firstName != null || lastName != null) {
        final passengerDocRef = _firestore
            .collection(_passengersCollection)
            .doc(user.uid);
        final updateData = <String, dynamic>{'updatedAt': Timestamp.now()};

        if (firstName != null) updateData['firstName'] = firstName;
        if (lastName != null) updateData['lastName'] = lastName;

        batch.update(passengerDocRef, updateData);
        hasUpdates = true;
      }

      if (!hasUpdates) {
        return {
          'success': false,
          'message': 'No fields provided for update',
          'error': 'NO_UPDATES',
        };
      }

      await batch.commit();

      return {'success': true, 'message': 'Profile updated successfully'};
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to update profile: ${e.toString()}',
        'error': 'UPDATE_ERROR',
      };
    }
  }

  /// Update phone number (requires re-authentication)
  Future<Map<String, dynamic>> updatePhoneNumber(String newPhoneNumber) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return {
          'success': false,
          'message': 'No authenticated user found',
          'error': 'NO_AUTH_USER',
        };
      }

      // Update phone number in Firestore
      await _firestore.collection(_usersCollection).doc(user.uid).update({
        'phoneNum': newPhoneNumber,
        'updatedAt': Timestamp.now(),
      });

      return {'success': true, 'message': 'Phone number updated successfully'};
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to update phone number: ${e.toString()}',
        'error': 'PHONE_UPDATE_ERROR',
      };
    }
  }

  /// Soft delete user (mark as inactive)
  Future<Map<String, dynamic>> deleteUser() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return {
          'success': false,
          'message': 'No authenticated user found',
          'error': 'NO_AUTH_USER',
        };
      }

      final batch = _firestore.batch();
      final now = Timestamp.now();

      // Mark user as inactive
      batch.update(_firestore.collection(_usersCollection).doc(user.uid), {
        'isActive': false,
        'deletedAt': now,
        'updatedAt': now,
      });

      // Mark passenger as inactive
      batch.update(_firestore.collection(_passengersCollection).doc(user.uid), {
        'isActive': false,
        'deletedAt': now,
        'updatedAt': now,
      });

      await batch.commit();

      return {'success': true, 'message': 'User deleted successfully'};
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to delete user: ${e.toString()}',
        'error': 'DELETE_ERROR',
      };
    }
  }

  /// Get user statistics (for admin purposes)
  Future<Map<String, dynamic>> getUserStats() async {
    try {
      final usersSnapshot = await _firestore.collection(_usersCollection).get();

      int totalUsers = 0;
      int activeUsers = 0;
      int passengers = 0;

      for (var doc in usersSnapshot.docs) {
        final data = doc.data();
        totalUsers++;
        if (data['isActive'] == true) {
          activeUsers++;
          if (data['userType'] == 1) {
            // Passenger
            passengers++;
          }
        }
      }

      return {
        'success': true,
        'data': {
          'totalUsers': totalUsers,
          'activeUsers': activeUsers,
          'passengers': passengers,
          'drivers': activeUsers - passengers,
        },
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to get user statistics: ${e.toString()}',
        'error': 'STATS_ERROR',
      };
    }
  }

  /// Check if user can login (exists and is active)
  Future<bool> canUserLogin(String userId) async {
    try {
      final user = await getUser(userId);
      return user != null && user.isActive;
    } catch (e) {
      return false;
    }
  }

  /// Get current user's complete data
  Future<UserWithPassenger?> getCurrentUserData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      return await getCompleteUserData(user.uid);
    } catch (e) {
      return null;
    }
  }
}
