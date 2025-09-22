import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Booking status enumeration
enum BookingStatus {
  pending,
  accepted,
  driverEnRoute,
  arrived,
  inProgress,
  completed,
  cancelled,
  expired,
}

/// Location data for booking
class BookingLocation {
  final double latitude;
  final double longitude;
  final String address;

  const BookingLocation({
    required this.latitude,
    required this.longitude,
    required this.address,
  });

  LatLng get latLng => LatLng(latitude, longitude);

  factory BookingLocation.fromMap(Map<String, dynamic> map) {
    return BookingLocation(
      latitude: map['latitude']?.toDouble() ?? 0.0,
      longitude: map['longitude']?.toDouble() ?? 0.0,
      address: map['address'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
    };
  }
}

/// Route information for booking
class BookingRoute {
  final int distance; // in meters
  final int duration; // in seconds
  final String distanceText;
  final String durationText;
  final List<LatLng> points;

  const BookingRoute({
    required this.distance,
    required this.duration,
    required this.distanceText,
    required this.durationText,
    required this.points,
  });

  factory BookingRoute.fromMap(Map<String, dynamic> map) {
    final pointsList = (map['points'] as List<dynamic>?)
        ?.map((point) => LatLng(
              point['latitude']?.toDouble() ?? 0.0,
              point['longitude']?.toDouble() ?? 0.0,
            ))
        .toList() ?? [];

    return BookingRoute(
      distance: map['distance'] ?? 0,
      duration: map['duration'] ?? 0,
      distanceText: map['distanceText'] ?? '',
      durationText: map['durationText'] ?? '',
      points: pointsList,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'distance': distance,
      'duration': duration,
      'distanceText': distanceText,
      'durationText': durationText,
      'points': points.map((point) => {
        'latitude': point.latitude,
        'longitude': point.longitude,
      }).toList(),
    };
  }
}

/// Fare breakdown for booking
class BookingFare {
  final double baseFare;
  final double distanceFare;
  final double passengerFare;
  final double totalFare;
  final String currency;

  const BookingFare({
    required this.baseFare,
    required this.distanceFare,
    required this.passengerFare,
    required this.totalFare,
    this.currency = 'PHP',
  });

  factory BookingFare.fromMap(Map<String, dynamic> map) {
    return BookingFare(
      baseFare: map['baseFare']?.toDouble() ?? 0.0,
      distanceFare: map['distanceFare']?.toDouble() ?? 0.0,
      passengerFare: map['passengerFare']?.toDouble() ?? 0.0,
      totalFare: map['totalFare']?.toDouble() ?? 0.0,
      currency: map['currency'] ?? 'PHP',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'baseFare': baseFare,
      'distanceFare': distanceFare,
      'passengerFare': passengerFare,
      'totalFare': totalFare,
      'currency': currency,
    };
  }

  String get formattedTotal => '₱${totalFare.toStringAsFixed(2)}';
}

/// Main booking model
class Booking {
  final String id;
  final String passengerId;
  final String passengerName;
  final String passengerPhone;
  final BookingLocation pickupLocation;
  final BookingLocation destination;
  final BookingRoute route;
  final BookingFare fare;
  final int passengerCount;
  final BookingStatus status;
  final String? driverId;
  final DateTime createdAt;
  final DateTime? acceptedAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final String paymentMethod; // 'cash' or 'digital'

  const Booking({
    required this.id,
    required this.passengerId,
    required this.passengerName,
    required this.passengerPhone,
    required this.pickupLocation,
    required this.destination,
    required this.route,
    required this.fare,
    required this.passengerCount,
    required this.status,
    this.driverId,
    required this.createdAt,
    this.acceptedAt,
    this.startedAt,
    this.completedAt,
    this.paymentMethod = 'cash',
  });

  /// Create booking from Firestore document
  factory Booking.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return Booking(
      id: doc.id,
      passengerId: data['passengerId'] ?? '',
      passengerName: data['passengerName'] ?? '',
      passengerPhone: data['passengerPhone'] ?? '',
      pickupLocation: BookingLocation.fromMap(data['pickupLocation'] ?? {}),
      destination: BookingLocation.fromMap(data['destination'] ?? {}),
      route: BookingRoute.fromMap(data['route'] ?? {}),
      fare: BookingFare.fromMap(data['fare'] ?? {}),
      passengerCount: data['passengerCount'] ?? 1,
      status: BookingStatus.values.firstWhere(
        (status) => status.name == data['status'],
        orElse: () => BookingStatus.pending,
      ),
      driverId: data['driverId'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      acceptedAt: data['acceptedAt'] != null 
          ? (data['acceptedAt'] as Timestamp).toDate() 
          : null,
      startedAt: data['startedAt'] != null 
          ? (data['startedAt'] as Timestamp).toDate() 
          : null,
      completedAt: data['completedAt'] != null 
          ? (data['completedAt'] as Timestamp).toDate() 
          : null,
      paymentMethod: data['paymentMethod'] ?? 'cash',
    );
  }

  /// Convert booking to Map for Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'passengerId': passengerId,
      'passengerName': passengerName,
      'passengerPhone': passengerPhone,
      'pickupLocation': pickupLocation.toMap(),
      'destination': destination.toMap(),
      'route': route.toMap(),
      'fare': fare.toMap(),
      'passengerCount': passengerCount,
      'status': status.name,
      'driverId': driverId,
      'createdAt': Timestamp.fromDate(createdAt),
      'acceptedAt': acceptedAt != null ? Timestamp.fromDate(acceptedAt!) : null,
      'startedAt': startedAt != null ? Timestamp.fromDate(startedAt!) : null,
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'paymentMethod': paymentMethod,
    };
  }

  /// Create a new booking with updated fields
  Booking copyWith({
    String? id,
    String? passengerId,
    String? passengerName,
    String? passengerPhone,
    BookingLocation? pickupLocation,
    BookingLocation? destination,
    BookingRoute? route,
    BookingFare? fare,
    int? passengerCount,
    BookingStatus? status,
    String? driverId,
    DateTime? createdAt,
    DateTime? acceptedAt,
    DateTime? startedAt,
    DateTime? completedAt,
    String? paymentMethod,
  }) {
    return Booking(
      id: id ?? this.id,
      passengerId: passengerId ?? this.passengerId,
      passengerName: passengerName ?? this.passengerName,
      passengerPhone: passengerPhone ?? this.passengerPhone,
      pickupLocation: pickupLocation ?? this.pickupLocation,
      destination: destination ?? this.destination,
      route: route ?? this.route,
      fare: fare ?? this.fare,
      passengerCount: passengerCount ?? this.passengerCount,
      status: status ?? this.status,
      driverId: driverId ?? this.driverId,
      createdAt: createdAt ?? this.createdAt,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      paymentMethod: paymentMethod ?? this.paymentMethod,
    );
  }

  /// Get formatted status text
  String get statusText {
    switch (status) {
      case BookingStatus.pending:
        return 'Waiting for driver';
      case BookingStatus.accepted:
        return 'Driver accepted';
      case BookingStatus.driverEnRoute:
        return 'Driver on the way';
      case BookingStatus.arrived:
        return 'Driver arrived';
      case BookingStatus.inProgress:
        return 'Ride in progress';
      case BookingStatus.completed:
        return 'Ride completed';
      case BookingStatus.cancelled:
        return 'Ride cancelled';
      case BookingStatus.expired:
        return 'Ride expired';
    }
  }

  /// Check if booking is active (not completed or cancelled)
  bool get isActive {
    return status != BookingStatus.completed && 
           status != BookingStatus.cancelled && 
           status != BookingStatus.expired;
  }

  /// Get estimated arrival time
  DateTime? get estimatedArrival {
    if (acceptedAt != null) {
      return acceptedAt!.add(Duration(seconds: route.duration));
    }
    return null;
  }

  @override
  String toString() {
    return 'Booking(id: $id, passengerId: $passengerId, status: $status, fare: ${fare.formattedTotal})';
  }
}
