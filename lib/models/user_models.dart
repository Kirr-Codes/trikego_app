import 'package:cloud_firestore/cloud_firestore.dart';

/// User model for Firestore USER collection
class AppUser {
  final String userId;
  final String phoneNum;
  final String email;
  final int userType; // 1=passenger, 2=driver, 3=admin
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isActive;

  AppUser({
    required this.userId,
    required this.phoneNum,
    required this.email,
    required this.userType,
    required this.createdAt,
    required this.updatedAt,
    this.isActive = true,
  });

  /// Create AppUser from Firestore document
  factory AppUser.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AppUser(
      userId: doc.id,
      phoneNum: data['phoneNum'] ?? '',
      email: data['email'] ?? '',
      userType: data['userType'] ?? 1,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      isActive: data['isActive'] ?? true,
    );
  }

  /// Convert AppUser to Map for Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'phoneNum': phoneNum,
      'email': email,
      'userType': userType,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'isActive': isActive,
    };
  }

  /// Create AppUser from Firebase User
  factory AppUser.fromFirebaseUser({
    required String userId,
    required String phoneNumber,
    required String email,
    int userType = 1, // Default to passenger for mobile app
  }) {
    final now = DateTime.now();
    return AppUser(
      userId: userId,
      phoneNum: phoneNumber,
      email: email,
      userType: userType,
      createdAt: now,
      updatedAt: now,
      isActive: true,
    );
  }

  /// Copy with method for updates
  AppUser copyWith({
    String? userId,
    String? phoneNum,
    String? email,
    int? userType,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
  }) {
    return AppUser(
      userId: userId ?? this.userId,
      phoneNum: phoneNum ?? this.phoneNum,
      email: email ?? this.email,
      userType: userType ?? this.userType,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  String toString() {
    return 'AppUser(userId: $userId, phoneNum: $phoneNum, email: $email, userType: $userType, isActive: $isActive)';
  }
}

/// Passenger model for Firestore PASSENGER collection
class Passenger {
  final String userId;
  final String firstName;
  final String lastName;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isActive;

  Passenger({
    required this.userId,
    required this.firstName,
    required this.lastName,
    required this.createdAt,
    required this.updatedAt,
    this.isActive = true,
  });

  /// Create Passenger from Firestore document
  factory Passenger.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Passenger(
      userId: doc.id,
      firstName: data['fname'] ?? '',
      lastName: data['name'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      isActive: data['isActive'] ?? true,
    );
  }

  /// Convert Passenger to Map for Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'firstName': firstName,
      'lastName': lastName,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'isActive': isActive,
    };
  }

  /// Create Passenger from user input
  factory Passenger.fromUserInput({
    required String userId,
    required String firstName,
    required String lastName,
  }) {
    final now = DateTime.now();
    return Passenger(
      userId: userId,
      firstName: firstName,
      lastName: lastName,
      createdAt: now,
      updatedAt: now,
      isActive: true,
    );
  }

  /// Copy with method for updates
  Passenger copyWith({
    String? userId,
    String? firstName,
    String? lastName,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
  }) {
    return Passenger(
      userId: userId ?? this.userId,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  String toString() {
    return 'Passenger(userId: $userId, fname: $firstName, name: $lastName, isActive: $isActive)';
  }
}

/// Combined model for user with passenger data
class UserWithPassenger {
  final AppUser user;
  final Passenger? passenger;

  UserWithPassenger({required this.user, this.passenger});

  /// Check if user has complete profile
  bool get hasCompleteProfile => passenger != null;

  /// Get display name
  String get displayName {
    if (passenger != null) {
      return '${passenger!.firstName} ${passenger!.lastName}';
    }
    return user.email;
  }

  @override
  String toString() {
    return 'UserWithPassenger(user: $user, passenger: $passenger)';
  }
}
