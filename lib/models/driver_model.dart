import 'package:cloud_firestore/cloud_firestore.dart';

/// Driver model for Firestore DRIVER collection
class Driver {
  final String userId;
  final String firstName;
  final String lastName;
  final String bodyNum;
  final String plateNum;
  final String? profilePictureUrl;
  final String? phoneNum;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isActive;
  final bool isOnline;

  Driver({
    required this.userId,
    required this.firstName,
    required this.lastName,
    required this.bodyNum,
    required this.plateNum,
    this.profilePictureUrl,
    this.phoneNum,
    required this.createdAt,
    required this.updatedAt,
    this.isActive = true,
    this.isOnline = false,
  });

  /// Create Driver from Firestore document
  factory Driver.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Driver(
      userId: doc.id,
      firstName: data['firstName'] ?? '',
      lastName: data['lastName'] ?? '',
      bodyNum: data['bodyNum'] ?? '',
      plateNum: data['plateNum'] ?? '',
      profilePictureUrl: null, // Will be fetched from users collection
      phoneNum: null, // Will be fetched from users collection
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      isActive: data['isActive'] ?? true,
      isOnline: data['isOnline'] ?? false,
    );
  }

  /// Convert Driver to Map for Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'firstName': firstName,
      'lastName': lastName,
      'bodyNum': bodyNum,
      'plateNum': plateNum,
      'profilePictureUrl': profilePictureUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'isActive': isActive,
      'isOnline': isOnline,
    };
  }

  /// Get full name
  String get fullName => '$firstName $lastName';

  /// Copy with method for updates
  Driver copyWith({
    String? userId,
    String? firstName,
    String? lastName,
    String? bodyNum,
    String? plateNum,
    String? profilePictureUrl,
    String? phoneNum,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
    bool? isOnline,
  }) {
    return Driver(
      userId: userId ?? this.userId,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      bodyNum: bodyNum ?? this.bodyNum,
      plateNum: plateNum ?? this.plateNum,
      profilePictureUrl: profilePictureUrl ?? this.profilePictureUrl,
      phoneNum: phoneNum ?? this.phoneNum,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
      isOnline: isOnline ?? this.isOnline,
    );
  }

  @override
  String toString() {
    return 'Driver(userId: $userId, name: $fullName, bodyNum: $bodyNum, plateNum: $plateNum, isActive: $isActive, isOnline: $isOnline)';
  }
}
