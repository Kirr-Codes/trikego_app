import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'driver_model.dart';

/// Booking status enumeration
enum BookingStatus {
  pending,
  accepted,
  driverEnRoute,
  arrived,
  pickedUp,  // When driver picks up passenger (matches 'picked_up' in Firestore)
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
    return {'latitude': latitude, 'longitude': longitude, 'address': address};
  }
}

/// Driver's current location (updated in real-time)
class DriverLocation {
  final double latitude;
  final double longitude;
  final DateTime timestamp;

  const DriverLocation({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
  });

  LatLng get latLng => LatLng(latitude, longitude);

  factory DriverLocation.fromMap(Map<String, dynamic> map) {
    return DriverLocation(
      latitude: map['latitude']?.toDouble() ?? 0.0,
      longitude: map['longitude']?.toDouble() ?? 0.0,
      timestamp: map['timestamp'] != null
          ? (map['timestamp'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
}

class BookingRoute {
  final int distance;
  final int duration;
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
    final pointsList =
        (map['points'] as List<dynamic>?)
            ?.map(
              (point) => LatLng(
                point['latitude']?.toDouble() ?? 0.0,
                point['longitude']?.toDouble() ?? 0.0,
              ),
            )
            .toList() ??
        [];

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
      'points': points
          .map(
            (point) => {
              'latitude': point.latitude,
              'longitude': point.longitude,
            },
          )
          .toList(),
    };
  }
}

class BookingFare {
  final double baseFare;
  final double distanceFare;
  final double passengerFare;
  final double timeMultiplier;
  final double totalFare;
  final String currency;

  const BookingFare({
    required this.baseFare,
    required this.distanceFare,
    required this.passengerFare,
    this.timeMultiplier = 1.0,
    required this.totalFare,
    this.currency = 'PHP',
  });

  factory BookingFare.fromMap(Map<String, dynamic> map) {
    return BookingFare(
      baseFare: map['baseFare']?.toDouble() ?? 0.0,
      distanceFare: map['distanceFare']?.toDouble() ?? 0.0,
      passengerFare: map['passengerFare']?.toDouble() ?? 0.0,
      timeMultiplier: map['timeMultiplier']?.toDouble() ?? 1.0,
      totalFare: map['totalFare']?.toDouble() ?? 0.0,
      currency: map['currency'] ?? 'PHP',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'baseFare': baseFare,
      'distanceFare': distanceFare,
      'passengerFare': passengerFare,
      'timeMultiplier': timeMultiplier,
      'totalFare': totalFare,
      'currency': currency,
    };
  }

  String get formattedTotal => '₱${totalFare.toStringAsFixed(2)}';
}

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
  final Driver? driver;
  final DriverLocation? driverLocation; // NEW: Driver's real-time location
  final DateTime createdAt;
  final DateTime? acceptedAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final String paymentMethod; // 'cash' or 'digital'
  final String? cancelledBy; // 'passenger' or 'driver'

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
    this.driver,
    this.driverLocation,
    required this.createdAt,
    this.acceptedAt,
    this.startedAt,
    this.completedAt,
    this.paymentMethod = 'cash',
    this.cancelledBy,
  });

  static BookingStatus _parseBookingStatus(String? status) {
    if (status == null) return BookingStatus.pending;
    
    switch (status) {
      case 'picked_up':
        return BookingStatus.pickedUp;
      case 'driver_en_route':
        return BookingStatus.driverEnRoute;
      case 'in_progress':
        return BookingStatus.inProgress;
      default:
        return BookingStatus.values.firstWhere(
          (s) => s.name == status,
          orElse: () => BookingStatus.pending,
        );
    }
  }

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
      status: _parseBookingStatus(data['status']),
      driverId: data['driverId'],
      driver: null,
      driverLocation: data['driverLocation'] != null
          ? DriverLocation.fromMap(data['driverLocation'])
          : null,
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
      cancelledBy: data['cancelledBy'],
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
      'driverLocation': driverLocation?.toMap(), // NEW
      'createdAt': Timestamp.fromDate(createdAt),
      'acceptedAt': acceptedAt != null ? Timestamp.fromDate(acceptedAt!) : null,
      'startedAt': startedAt != null ? Timestamp.fromDate(startedAt!) : null,
      'completedAt': completedAt != null
          ? Timestamp.fromDate(completedAt!)
          : null,
      'paymentMethod': paymentMethod,
      'cancelledBy': cancelledBy,
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
    Driver? driver,
    DriverLocation? driverLocation, // NEW
    DateTime? createdAt,
    DateTime? acceptedAt,
    DateTime? startedAt,
    DateTime? completedAt,
    String? paymentMethod,
    String? cancelledBy,
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
      driver: driver ?? this.driver,
      driverLocation: driverLocation ?? this.driverLocation,
      createdAt: createdAt ?? this.createdAt,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      cancelledBy: cancelledBy ?? this.cancelledBy,
    );
  }

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
      case BookingStatus.pickedUp:
        return 'Passenger picked up';
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

  bool get isActive {
    return status != BookingStatus.completed &&
        status != BookingStatus.cancelled &&
        status != BookingStatus.expired;
  }

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
