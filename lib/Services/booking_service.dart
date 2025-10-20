import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/booking_model.dart';
import '../models/user_models.dart';
import '../Services/backend_fare_calculation_service.dart';
import '../Services/route_service.dart';
import '../Services/driver_service.dart';
import '../models/fare_config_model.dart';

/// Service result for booking operations
class BookingServiceResult {
  final bool success;
  final String message;
  final Booking? booking;
  final String? errorCode;

  const BookingServiceResult({
    required this.success,
    required this.message,
    this.booking,
    this.errorCode,
  });

  factory BookingServiceResult.success({
    required String message,
    Booking? booking,
  }) {
    return BookingServiceResult(
      success: true,
      message: message,
      booking: booking,
    );
  }

  factory BookingServiceResult.error({
    required String message,
    String? errorCode,
  }) {
    return BookingServiceResult(
      success: false,
      message: message,
      errorCode: errorCode,
    );
  }
}

/// Service for managing bookings and ride requests
class BookingService {
  static final BookingService _instance = BookingService._internal();
  factory BookingService() => _instance;
  BookingService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final BackendFareCalculationService _fareService = BackendFareCalculationService();
  final DriverService _driverService = DriverService();

  // Collection names
  static const String _bookingsCollection = 'bookings';
  static const String _passengersCollection = 'passengers';

  // Stream controllers for real-time updates
  final StreamController<Booking?> _activeBookingController = 
      StreamController<Booking?>.broadcast();
  final StreamController<List<Booking>> _bookingHistoryController = 
      StreamController<List<Booking>>.broadcast();
  
  // Throttling for location updates
  Timer? _locationThrottleTimer;
  Booking? _pendingBookingUpdate;
  DateTime? _lastLocationUpdate;
  
  // Throttle interval for UI updates (60 seconds)
  static const Duration _locationThrottleInterval = Duration(seconds: 60);
  
  // Firestore snapshot subscription
  StreamSubscription<DocumentSnapshot>? _bookingSubscription;

  /// Stream of active booking updates
  Stream<Booking?> get activeBookingStream => _activeBookingController.stream;

  /// Stream of booking history updates
  Stream<List<Booking>> get bookingHistoryStream => _bookingHistoryController.stream;

  /// Current active booking
  Booking? _activeBooking;
  Booking? get activeBooking => _activeBooking;

  /// Initialize and check for existing active bookings
  Future<void> initialize() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final snapshot = await _firestore
          .collection(_bookingsCollection)
          .where('passengerId', isEqualTo: user.uid)
          .where('status', whereIn: [
            'pending',
            'accepted',
            'driver_arriving',
            'driver_arrived',
            'in_progress',
          ])
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final booking = Booking.fromFirestore(snapshot.docs.first);
        
        if (booking.driverId != null && booking.driver == null) {
          final driver = await _driverService.getDriverById(booking.driverId!);
          if (driver != null) {
            final updatedBooking = booking.copyWith(driver: driver);
            _activeBooking = updatedBooking;
            _activeBookingController.add(updatedBooking);
            _listenToBookingUpdates(updatedBooking.id);
            return;
          }
        }
        
        _activeBooking = booking;
        _activeBookingController.add(booking);
        _listenToBookingUpdates(booking.id);
      }
    } catch (e) {}
  }

  /// Create a new booking
  Future<BookingServiceResult> createBooking({
    required BookingLocation pickupLocation,
    required BookingLocation destination,
    required RouteResult route,
    required int passengerCount,
    String paymentMethod = 'cash',
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return BookingServiceResult.error(
          message: 'User not authenticated',
          errorCode: 'NO_AUTH_USER',
        );
      }

      // Check if user has an active booking
      if (_activeBooking != null && _activeBooking!.isActive) {
        return BookingServiceResult.error(
          message: 'You already have an active booking',
          errorCode: 'ACTIVE_BOOKING_EXISTS',
        );
      }

      // Get passenger information
      final passengerDoc = await _firestore
          .collection(_passengersCollection)
          .doc(user.uid)
          .get();

      if (!passengerDoc.exists) {
        return BookingServiceResult.error(
          message: 'Passenger profile not found',
          errorCode: 'PASSENGER_NOT_FOUND',
        );
      }

      final passenger = Passenger.fromFirestore(passengerDoc);
      final passengerName = '${passenger.firstName} ${passenger.lastName}';

      // Calculate fare
      final fareCalculation = await _fareService.calculateEnhancedFare(
        pickupLatitude: pickupLocation.latitude,
        pickupLongitude: pickupLocation.longitude,
        pickupToDestinationRoute: route,
        passengerCount: passengerCount,
        vehicleType: 'tricycle',
      );

      // Create booking fare
      final bookingFare = BookingFare(
        baseFare: fareCalculation.baseFare,
        distanceFare: fareCalculation.driverToPickupFare + fareCalculation.pickupToDestinationFare,
        passengerFare: fareCalculation.passengerFare,
        timeMultiplier: fareCalculation.timeMultiplier,
        totalFare: fareCalculation.totalFare,
      );

      // Create booking route
      final bookingRoute = BookingRoute(
        distance: route.distance,
        duration: route.duration,
        distanceText: route.distanceText,
        durationText: route.durationText,
        points: route.points,
      );

      // Create booking
      final booking = Booking(
        id: '', // Will be set by Firestore
        passengerId: user.uid,
        passengerName: passengerName,
        passengerPhone: user.phoneNumber ?? '',
        pickupLocation: pickupLocation,
        destination: destination,
        route: bookingRoute,
        fare: bookingFare,
        passengerCount: passengerCount,
        status: BookingStatus.pending,
        createdAt: DateTime.now(),
        paymentMethod: paymentMethod,
      );

      // Save to Firestore
      final docRef = await _firestore
          .collection(_bookingsCollection)
          .add(booking.toFirestore());

      // Update booking with ID
      final createdBooking = booking.copyWith(id: docRef.id);
      
      // Update active booking
      _activeBooking = createdBooking;
      _activeBookingController.add(createdBooking);

      // Start listening to booking updates
      _listenToBookingUpdates(docRef.id);

      return BookingServiceResult.success(
        message: 'Booking created successfully',
        booking: createdBooking,
      );
    } catch (e) {
      return BookingServiceResult.error(
        message: 'Failed to create booking: ${e.toString()}',
        errorCode: 'BOOKING_CREATION_FAILED',
      );
    }
  }

  /// Cancel an active booking
  Future<BookingServiceResult> cancelBooking({
    String? reason,
  }) async {
    try {
      if (_activeBooking == null) {
        return BookingServiceResult.error(
          message: 'No active booking to cancel',
          errorCode: 'NO_ACTIVE_BOOKING',
        );
      }

      await _firestore
          .collection(_bookingsCollection)
          .doc(_activeBooking!.id)
          .update({
        'status': BookingStatus.cancelled.name,
        'cancelledBy': 'passenger',
      });

      return BookingServiceResult.success(
        message: 'Booking cancelled successfully',
      );
    } catch (e) {
      return BookingServiceResult.error(
        message: 'Failed to cancel booking: ${e.toString()}',
        errorCode: 'BOOKING_CANCELLATION_FAILED',
      );
    }
  }

  /// Get booking history for current user
  Future<List<Booking>> getBookingHistory({
    int limit = 20,
    DateTime? startAfter,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return [];

      // Try ordered query first, fallback to simple query if index is missing
      Query query = _firestore
          .collection(_bookingsCollection)
          .where('passengerId', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .limit(limit);

      if (startAfter != null) {
        query = query.startAfter([Timestamp.fromDate(startAfter)]);
      }

      try {
        final snapshot = await query.get();
        final bookings = snapshot.docs
            .map((doc) => Booking.fromFirestore(doc))
            .toList();

        _bookingHistoryController.add(bookings);
        return bookings;
      } catch (e) {
        // Fallback to simple query without orderBy if index is missing
        final simpleQuery = _firestore
            .collection(_bookingsCollection)
            .where('passengerId', isEqualTo: user.uid)
            .limit(limit);
        
        final snapshot = await simpleQuery.get();
        final bookings = snapshot.docs
            .map((doc) => Booking.fromFirestore(doc))
            .toList();

        // Sort manually by createdAt descending
        bookings.sort((a, b) => b.createdAt.compareTo(a.createdAt));

        _bookingHistoryController.add(bookings);
        return bookings;
      }
    } catch (e) {
      return [];
    }
  }

  /// Get a specific booking by ID
  Future<Booking?> getBooking(String bookingId) async {
    try {
      final doc = await _firestore
          .collection(_bookingsCollection)
          .doc(bookingId)
          .get();

      if (doc.exists) {
        return Booking.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Listen to booking updates with real-time snapshots and throttled location updates
  void _listenToBookingUpdates(String bookingId) {
    // Cancel any existing subscription and timer
    _bookingSubscription?.cancel();
    _locationThrottleTimer?.cancel();
    
    // Set up real-time Firestore snapshot listener
    _bookingSubscription = _firestore
        .collection(_bookingsCollection)
        .doc(bookingId)
        .snapshots()
        .listen((snapshot) async {
      if (snapshot.exists) {
        var booking = Booking.fromFirestore(snapshot);
        
        // Fetch driver info if needed
        if (booking.driverId != null && 
            booking.driver == null &&
            (booking.status == BookingStatus.accepted ||
             booking.status == BookingStatus.driverEnRoute ||
             booking.status == BookingStatus.arrived ||
             booking.status == BookingStatus.pickedUp ||
             booking.status == BookingStatus.inProgress)) {
          final driver = await _driverService.getDriverById(booking.driverId!);
          if (driver != null) {
            booking = booking.copyWith(driver: driver);
          }
        }
        
        // Handle different types of updates
        _handleBookingUpdate(booking);

        // Clean up if booking is no longer active
        if (!booking.isActive) {
          _activeBooking = null;
          _activeBookingController.add(null);
          _bookingSubscription?.cancel();
          _locationThrottleTimer?.cancel();
          _lastLocationUpdate = null;
          _pendingBookingUpdate = null;
        }
      }
    });
  }
  
  /// Handle booking updates with smart throttling
  void _handleBookingUpdate(Booking booking) {
    final previousBooking = _activeBooking;
    
    // Check if this is a status change (always update immediately)
    final isStatusChange = previousBooking == null || 
                          previousBooking.status != booking.status;
    
    // Check if this is only a location update
    final isLocationUpdate = previousBooking != null &&
                            previousBooking.status == booking.status &&
                            previousBooking.driverLocation != booking.driverLocation;
    
    if (isStatusChange) {
      // Status changes are always immediate (accepted, arrived, picked up, etc.)
      _activeBooking = booking;
      _activeBookingController.add(booking);
      _lastLocationUpdate = DateTime.now();
    } else if (isLocationUpdate) {
      // Location updates are throttled
      _handleThrottledLocationUpdate(booking);
    } else {
      // Other updates (no change or first update)
      _activeBooking = booking;
      _activeBookingController.add(booking);
    }
  }
  
  /// Handle throttled location updates
  void _handleThrottledLocationUpdate(Booking booking) {
    final now = DateTime.now();
    final timeSinceLastUpdate = _lastLocationUpdate != null
        ? now.difference(_lastLocationUpdate!)
        : Duration.zero;
    
    if (timeSinceLastUpdate >= _locationThrottleInterval) {
      // Enough time has passed, update immediately
      _activeBooking = booking;
      _activeBookingController.add(booking);
      _lastLocationUpdate = now;
      _pendingBookingUpdate = null;
      _locationThrottleTimer?.cancel();
    } else {
      // Store pending update and schedule it
      _pendingBookingUpdate = booking;
      
      // Cancel existing timer if any
      _locationThrottleTimer?.cancel();
      
      // Schedule update for when throttle period expires
      final remainingTime = _locationThrottleInterval - timeSinceLastUpdate;
      _locationThrottleTimer = Timer(remainingTime, () {
        if (_pendingBookingUpdate != null) {
          _activeBooking = _pendingBookingUpdate;
          _activeBookingController.add(_pendingBookingUpdate!);
          _lastLocationUpdate = DateTime.now();
          _pendingBookingUpdate = null;
        }
      });
    }
  }


  /// Calculate enhanced fare for a route without creating a booking
  Future<EnhancedFareCalculation> calculateEnhancedFare({
    required double pickupLatitude,
    required double pickupLongitude,
    required RouteResult route,
    required int passengerCount,
    String vehicleType = 'tricycle',
    DateTime? requestTime,
  }) async {
    try {
      final result = await _fareService.calculateEnhancedFare(
        pickupLatitude: pickupLatitude,
        pickupLongitude: pickupLongitude,
        pickupToDestinationRoute: route,
        passengerCount: passengerCount,
        vehicleType: vehicleType,
        requestTime: requestTime,
      );
      return result;
    } catch (e) {
      rethrow;
    }
  }

  /// Calculate fare from distance
  Future<EnhancedFareCalculation> calculateFareFromDistance({
    required double pickupLatitude,
    required double pickupLongitude,
    required double pickupToDestinationDistanceKm,
    required int passengerCount,
    String vehicleType = 'tricycle',
    DateTime? requestTime,
  }) async {
    return await _fareService.calculateFareFromDistance(
      pickupLatitude: pickupLatitude,
      pickupLongitude: pickupLongitude,
      pickupToDestinationDistanceKm: pickupToDestinationDistanceKm,
      passengerCount: passengerCount,
      vehicleType: vehicleType,
      requestTime: requestTime,
    );
  }

  /// Check if user has an active booking
  bool get hasActiveBooking => _activeBooking != null && _activeBooking!.isActive;

  /// Get estimated wait time for booking
  Duration? getEstimatedWaitTime() {
    if (_activeBooking == null) return null;
    
    // Simple estimation based on time of day and area
    final now = DateTime.now();
    final hour = now.hour;
    
    // Rush hours: 15-20 minutes
    if ((hour >= 7 && hour < 9) || (hour >= 17 && hour < 19)) {
      return const Duration(minutes: 15);
    }
    
    // Night time: 20-25 minutes
    if (hour >= 22 || hour < 6) {
      return const Duration(minutes: 20);
    }
    
    // Regular hours: 10-15 minutes
    return const Duration(minutes: 10);
  }

  /// Clear cache (useful for testing or when config changes)
  void clearFareCache() {
    _fareService.clearCache();
  }

  /// Dispose resources
  void dispose() {
    _bookingSubscription?.cancel();
    _locationThrottleTimer?.cancel();
    _activeBookingController.close();
    _bookingHistoryController.close();
  }
}
