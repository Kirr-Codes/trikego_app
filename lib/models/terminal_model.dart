import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Terminal model for Firestore terminals collection
class Terminal {
  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  Terminal({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Get LatLng for map usage
  LatLng get latLng => LatLng(latitude, longitude);

  /// Create Terminal from Firestore document
  factory Terminal.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Terminal(
      id: doc.id,
      name: data['name'] ?? '',
      address: data['address'] ?? '',
      latitude: data['latitude']?.toDouble() ?? 0.0,
      longitude: data['longitude']?.toDouble() ?? 0.0,
      isActive: data['isActive'] ?? true,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  /// Convert Terminal to Map for Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  @override
  String toString() {
    return 'Terminal(id: $id, name: $name, address: $address, isActive: $isActive)';
  }
}
