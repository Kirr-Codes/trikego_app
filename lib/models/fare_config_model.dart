import 'package:cloud_firestore/cloud_firestore.dart';

/// Fare configuration model for backend pricing
class FareConfigModel {
  final String id;
  final double baseFare;
  final double perKilometerRate;
  final double perPassengerRate;
  final double minimumFare;
  final double maximumFare;
  final Map<String, double> timeMultipliers;
  final Map<String, double> vehicleTypeMultipliers;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const FareConfigModel({
    required this.id,
    required this.baseFare,
    required this.perKilometerRate,
    required this.perPassengerRate,
    required this.minimumFare,
    required this.maximumFare,
    required this.timeMultipliers,
    required this.vehicleTypeMultipliers,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Create from Firestore document
  factory FareConfigModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return FareConfigModel(
      id: doc.id,
      baseFare: data['baseFare']?.toDouble() ?? 25.0,
      perKilometerRate: data['perKilometerRate']?.toDouble() ?? 12.0,
      perPassengerRate: data['perPassengerRate']?.toDouble() ?? 5.0,
      minimumFare: data['minimumFare']?.toDouble() ?? 25.0,
      maximumFare: data['maximumFare']?.toDouble() ?? 500.0,
      timeMultipliers: Map<String, double>.from(data['timeMultipliers'] ?? {}),
      vehicleTypeMultipliers: Map<String, double>.from(
        data['vehicleTypeMultipliers'] ?? {},
      ),
      isActive: data['isActive'] ?? true,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'baseFare': baseFare,
      'perKilometerRate': perKilometerRate,
      'perPassengerRate': perPassengerRate,
      'minimumFare': minimumFare,
      'maximumFare': maximumFare,
      'timeMultipliers': timeMultipliers,
      'vehicleTypeMultipliers': vehicleTypeMultipliers,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// Create default configuration
  factory FareConfigModel.createDefault() {
    final now = DateTime.now();
    return FareConfigModel(
      id: 'default',
      baseFare: 25.0,
      perKilometerRate: 15.0, // Updated to match Firestore
      perPassengerRate: 10.0,
      minimumFare: 25.0,
      maximumFare: 500.0,
      timeMultipliers: {
        'rush_morning': 1.2, // 7-9 AM
        'rush_evening': 1.2, // 5-7 PM - Updated to match Firestore
        'night': 1.3, // 10 PM - 6 AM - Updated to match Firestore
        'weekend': 1.1, // Weekend multiplier
      },
      vehicleTypeMultipliers: {'tricycle': 1.0},
      isActive: true,
      createdAt: now,
      updatedAt: now,
    );
  }
}

/// Terminal location model
class TerminalLocation {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final String address;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TerminalLocation({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Create from Firestore document
  factory TerminalLocation.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return TerminalLocation(
      id: doc.id,
      name: data['name'] ?? '',
      latitude: data['latitude']?.toDouble() ?? 0.0,
      longitude: data['longitude']?.toDouble() ?? 0.0,
      address: data['address'] ?? '',
      isActive: data['isActive'] ?? true,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// Create default terminal (Paombong Municipal Hall)
  factory TerminalLocation.createDefault() {
    final now = DateTime.now();
    return TerminalLocation(
      id: 'paombong_terminal',
      name: 'Paombong Terminal',
      latitude: 14.8312,
      longitude: 120.7895,
      address: 'Paombong Municipal Hall, Bulacan',
      isActive: true,
      createdAt: now,
      updatedAt: now,
    );
  }
}

/// Enhanced fare calculation result
class EnhancedFareCalculation {
  final double baseFare;
  final double driverToPickupFare;
  final double pickupToDestinationFare;
  final double passengerFare;
  final double timeMultiplier;
  final double vehicleTypeMultiplier;
  final double subtotal;
  final double totalFare;
  final String breakdown;
  final double driverToPickupDistanceKm;
  final double pickupToDestinationDistanceKm;

  const EnhancedFareCalculation({
    required this.baseFare,
    required this.driverToPickupFare,
    required this.pickupToDestinationFare,
    required this.passengerFare,
    required this.timeMultiplier,
    required this.vehicleTypeMultiplier,
    required this.subtotal,
    required this.totalFare,
    required this.breakdown,
    required this.driverToPickupDistanceKm,
    required this.pickupToDestinationDistanceKm,
  });

  String get formattedTotal => '₱${totalFare.toStringAsFixed(2)}';
}
