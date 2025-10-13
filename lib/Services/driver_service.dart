import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/driver_model.dart';

/// Service for managing driver-related operations
class DriverService {
  static final DriverService _instance = DriverService._internal();
  factory DriverService() => _instance;
  DriverService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Collection names
  static const String _driversCollection = 'drivers';
  static const String _usersCollection = 'users';

  /// Get driver information by driver ID
  Future<Driver?> getDriverById(String driverId) async {
    try {
      final doc = await _firestore
          .collection(_driversCollection)
          .doc(driverId)
          .get();

      if (doc.exists) {
        var driver = Driver.fromFirestore(doc);
        
        // Fetch user information (profile picture and phone number)
        final userDoc = await _firestore
            .collection(_usersCollection)
            .doc(driverId)
            .get();
        
        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          driver = driver.copyWith(
            profilePictureUrl: userData['profilePictureUrl'],
            phoneNum: userData['phoneNum'],
          );
        }
        
        return driver;
      }
      return null;
    } catch (e) {
      print('Error fetching driver: $e');
      return null;
    }
  }

  /// Get multiple drivers by their IDs
  Future<List<Driver>> getDriversByIds(List<String> driverIds) async {
    try {
      if (driverIds.isEmpty) return [];
      
      final docs = await _firestore
          .collection(_driversCollection)
          .where(FieldPath.documentId, whereIn: driverIds)
          .get();

      return docs.docs
          .map((doc) => Driver.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error fetching drivers: $e');
      return [];
    }
  }

  /// Get all active drivers
  Future<List<Driver>> getActiveDrivers() async {
    try {
      final snapshot = await _firestore
          .collection(_driversCollection)
          .where('isActive', isEqualTo: true)
          .get();

      return snapshot.docs
          .map((doc) => Driver.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error fetching active drivers: $e');
      return [];
    }
  }

  /// Get online drivers
  Future<List<Driver>> getOnlineDrivers() async {
    try {
      final snapshot = await _firestore
          .collection(_driversCollection)
          .where('isActive', isEqualTo: true)
          .where('isOnline', isEqualTo: true)
          .get();

      return snapshot.docs
          .map((doc) => Driver.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error fetching online drivers: $e');
      return [];
    }
  }
}
