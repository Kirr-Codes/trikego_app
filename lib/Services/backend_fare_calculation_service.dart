import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../Services/route_service.dart';
import '../models/fare_config_model.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Service for backend-based fare calculation with driver distance
class BackendFareCalculationService {
  static final BackendFareCalculationService _instance = BackendFareCalculationService._internal();
  factory BackendFareCalculationService() => _instance;
  BackendFareCalculationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Collection names
  static const String _fareConfigCollection = 'fare_configs';
  static const String _terminalCollection = 'terminals';

  // Cache for fare configuration
  FareConfigModel? _cachedFareConfig;
  TerminalLocation? _cachedTerminal;
  DateTime? _lastConfigFetch;
  DateTime? _lastTerminalFetch;

  // Cache duration (5 minutes)
  static const Duration _cacheDuration = Duration(minutes: 5);

  /// Get current fare configuration from backend
  Future<FareConfigModel> getFareConfig() async {
    // Return cached config if still valid
    if (_cachedFareConfig != null && 
        _lastConfigFetch != null && 
        DateTime.now().difference(_lastConfigFetch!) < _cacheDuration) {
      return _cachedFareConfig!;
    }

    try {
      // Fetch active fare configuration
      final snapshot = await _firestore
          .collection(_fareConfigCollection)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        _cachedFareConfig = FareConfigModel.fromFirestore(snapshot.docs.first);
        _lastConfigFetch = DateTime.now();
        return _cachedFareConfig!;
      } else {
        // Create default configuration if none exists
        final defaultConfig = FareConfigModel.createDefault();
        await _createDefaultFareConfig(defaultConfig);
        _cachedFareConfig = defaultConfig;
        _lastConfigFetch = DateTime.now();
        return defaultConfig;
      }
    } catch (e) {
      // Fallback to default configuration - TEMPORARILY RE-ENABLED FOR TESTING
      _cachedFareConfig ??= FareConfigModel.createDefault();
      return _cachedFareConfig!;
      
    }
  }

  /// Get terminal location from backend
  Future<TerminalLocation> getTerminalLocation() async {
    // Return cached terminal if still valid
    if (_cachedTerminal != null && 
        _lastTerminalFetch != null && 
        DateTime.now().difference(_lastTerminalFetch!) < _cacheDuration) {
      return _cachedTerminal!;
    }

    try {
      // Fetch active terminal
      final snapshot = await _firestore
          .collection(_terminalCollection)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        _cachedTerminal = TerminalLocation.fromFirestore(snapshot.docs.first);
        _lastTerminalFetch = DateTime.now();
        return _cachedTerminal!;
      } else {
        // Create default terminal if none exists
        final defaultTerminal = TerminalLocation.createDefault();
        await _createDefaultTerminal(defaultTerminal);
        _cachedTerminal = defaultTerminal;
        _lastTerminalFetch = DateTime.now();
        return defaultTerminal;
      }
    } catch (e) {
      // Fallback to default terminal - TEMPORARILY RE-ENABLED FOR TESTING
      _cachedTerminal ??= TerminalLocation.createDefault();
      return _cachedTerminal!;
      
    }
  }

  /// Calculate enhanced fare including driver distance
  Future<EnhancedFareCalculation> calculateEnhancedFare({
    required double pickupLatitude,
    required double pickupLongitude,
    required RouteResult pickupToDestinationRoute,
    required int passengerCount,
    String vehicleType = 'tricycle',
    DateTime? requestTime,
    String? zone,
  }) async {
    try {
      // Get configuration and terminal
      final fareConfig = await getFareConfig();
      final terminal = await getTerminalLocation();


      // Calculate driver to pickup distance
      final driverToPickupDistanceKm = RouteService.calculateDistance(
        LatLng(terminal.latitude, terminal.longitude),
        LatLng(pickupLatitude, pickupLongitude),
      ) / 1000.0;

      // Get pickup to destination distance
      final pickupToDestinationDistanceKm = pickupToDestinationRoute.distance / 1000.0;


      // Calculate base components
      final baseFare = fareConfig.baseFare;
      final driverToPickupFare = driverToPickupDistanceKm * fareConfig.perKilometerRate;
      final pickupToDestinationFare = pickupToDestinationDistanceKm * fareConfig.perKilometerRate;
      
      // Calculate passenger fare (additional passengers only)
      final extraPassengers = max(0, passengerCount - 1);
      final passengerFare = extraPassengers * fareConfig.perPassengerRate;
      
      // Calculate multipliers
      final now = requestTime ?? DateTime.now();
      final timeMultiplier = _getTimeMultiplier(now, fareConfig.timeMultipliers);
      final vehicleTypeMultiplier = fareConfig.vehicleTypeMultipliers[vehicleType] ?? 1.0;
      
      // Calculate subtotal before multipliers
      final subtotal = baseFare + driverToPickupFare + pickupToDestinationFare + passengerFare;
      
      // Apply multipliers
      final totalFare = subtotal * timeMultiplier * vehicleTypeMultiplier;
      
      // Apply minimum and maximum fare limits
      final finalFare = max(fareConfig.minimumFare, min(totalFare, fareConfig.maximumFare));
      
      
      // Generate breakdown text
      final breakdown = _generateBreakdown(
        baseFare: baseFare,
        driverToPickupFare: driverToPickupFare,
        pickupToDestinationFare: pickupToDestinationFare,
        passengerFare: passengerFare,
        timeMultiplier: timeMultiplier,
        vehicleTypeMultiplier: vehicleTypeMultiplier,
        driverToPickupDistanceKm: driverToPickupDistanceKm,
        pickupToDestinationDistanceKm: pickupToDestinationDistanceKm,
        extraPassengers: extraPassengers,
      );

      return EnhancedFareCalculation(
        baseFare: baseFare,
        driverToPickupFare: driverToPickupFare,
        pickupToDestinationFare: pickupToDestinationFare,
        passengerFare: passengerFare,
        timeMultiplier: timeMultiplier,
        zoneMultiplier: 1.0, // No zone multiplier
        vehicleTypeMultiplier: vehicleTypeMultiplier,
        subtotal: subtotal,
        totalFare: finalFare,
        breakdown: breakdown,
        driverToPickupDistanceKm: driverToPickupDistanceKm,
        pickupToDestinationDistanceKm: pickupToDestinationDistanceKm,
      );
    } catch (e) {
      // Fallback calculation if backend fails - TEMPORARILY RE-ENABLED FOR TESTING
      return _calculateFallbackFare(
        pickupToDestinationRoute: pickupToDestinationRoute,
        passengerCount: passengerCount,
        vehicleType: vehicleType,
        requestTime: requestTime,
        zone: zone,
      );
      
    }
  }

  /// Calculate fare from distance (simplified version)
  Future<EnhancedFareCalculation> calculateFareFromDistance({
    required double pickupLatitude,
    required double pickupLongitude,
    required double pickupToDestinationDistanceKm,
    required int passengerCount,
    String vehicleType = 'tricycle',
    DateTime? requestTime,
    String? zone,
  }) async {
    try {
      final fareConfig = await getFareConfig();
      final terminal = await getTerminalLocation();

      // Calculate driver to pickup distance
      final driverToPickupDistanceKm = RouteService.calculateDistance(
        LatLng(terminal.latitude, terminal.longitude),
        LatLng(pickupLatitude, pickupLongitude),
      ) / 1000.0;

      // Calculate base components
      final baseFare = fareConfig.baseFare;
      final driverToPickupFare = driverToPickupDistanceKm * fareConfig.perKilometerRate;
      final pickupToDestinationFare = pickupToDestinationDistanceKm * fareConfig.perKilometerRate;
      
      // Calculate passenger fare
      final extraPassengers = max(0, passengerCount - 1);
      final passengerFare = extraPassengers * fareConfig.perPassengerRate;
      
      // Calculate multipliers
      final now = requestTime ?? DateTime.now();
      final timeMultiplier = _getTimeMultiplier(now, fareConfig.timeMultipliers);
      final vehicleTypeMultiplier = fareConfig.vehicleTypeMultipliers[vehicleType] ?? 1.0;
      
      // Calculate total
      final subtotal = baseFare + driverToPickupFare + pickupToDestinationFare + passengerFare;
      final totalFare = subtotal * timeMultiplier * vehicleTypeMultiplier;
      final finalFare = max(fareConfig.minimumFare, min(totalFare, fareConfig.maximumFare));
      
      // Generate breakdown
      final breakdown = _generateBreakdown(
        baseFare: baseFare,
        driverToPickupFare: driverToPickupFare,
        pickupToDestinationFare: pickupToDestinationFare,
        passengerFare: passengerFare,
        timeMultiplier: timeMultiplier,
        vehicleTypeMultiplier: vehicleTypeMultiplier,
        driverToPickupDistanceKm: driverToPickupDistanceKm,
        pickupToDestinationDistanceKm: pickupToDestinationDistanceKm,
        extraPassengers: extraPassengers,
      );

      return EnhancedFareCalculation(
        baseFare: baseFare,
        driverToPickupFare: driverToPickupFare,
        pickupToDestinationFare: pickupToDestinationFare,
        passengerFare: passengerFare,
        timeMultiplier: timeMultiplier,
        zoneMultiplier: 1.0, // No zone multiplier
        vehicleTypeMultiplier: vehicleTypeMultiplier,
        subtotal: subtotal,
        totalFare: finalFare,
        breakdown: breakdown,
        driverToPickupDistanceKm: driverToPickupDistanceKm,
        pickupToDestinationDistanceKm: pickupToDestinationDistanceKm,
      );
    } catch (e) {
      // Fallback calculation - TEMPORARILY RE-ENABLED FOR TESTING
      return _calculateFallbackFareFromDistance(
        pickupToDestinationDistanceKm: pickupToDestinationDistanceKm,
        passengerCount: passengerCount,
        vehicleType: vehicleType,
        requestTime: requestTime,
        zone: zone,
      );
      
    }
  }

  /// Get time-based multiplier
  double _getTimeMultiplier(DateTime time, Map<String, double> timeMultipliers) {
    final hour = time.hour;
    final weekday = time.weekday;
    
    // Weekend multiplier
    if (weekday == DateTime.saturday || weekday == DateTime.sunday) {
      return timeMultipliers['weekend'] ?? 1.0;
    }
    
    // Rush hour morning (7-9 AM)
    if (hour >= 7 && hour < 9) {
      return timeMultipliers['rush_morning'] ?? 1.0;
    }
    
    // Rush hour evening (5-7 PM)
    if (hour >= 17 && hour < 19) {
      return timeMultipliers['rush_evening'] ?? 1.0;
    }
    
    // Night time (10 PM - 6 AM)
    if (hour >= 22 || hour < 6) {
      return timeMultipliers['night'] ?? 1.0;
    }
    
    return 1.0; // Regular hours
  }

  /// Generate fare breakdown text
  String _generateBreakdown({
    required double baseFare,
    required double driverToPickupFare,
    required double pickupToDestinationFare,
    required double passengerFare,
    required double timeMultiplier,
    required double vehicleTypeMultiplier,
    required double driverToPickupDistanceKm,
    required double pickupToDestinationDistanceKm,
    required int extraPassengers,
  }) {
    final buffer = StringBuffer();
    
    buffer.writeln('Base fare: ₱${baseFare.toStringAsFixed(2)}');
    buffer.writeln('Driver to pickup (${driverToPickupDistanceKm.toStringAsFixed(1)} km): ₱${driverToPickupFare.toStringAsFixed(2)}');
    buffer.writeln('Pickup to destination (${pickupToDestinationDistanceKm.toStringAsFixed(1)} km): ₱${pickupToDestinationFare.toStringAsFixed(2)}');
    
    if (extraPassengers > 0) {
      buffer.writeln('Extra passengers ($extraPassengers): ₱${passengerFare.toStringAsFixed(2)}');
    }
    
    if (timeMultiplier != 1.0) {
      buffer.writeln('Time multiplier (${(timeMultiplier * 100).toStringAsFixed(0)}%): ${timeMultiplier > 1.0 ? '+' : ''}${((timeMultiplier - 1) * 100).toStringAsFixed(0)}%');
    }
    
    if (vehicleTypeMultiplier != 1.0) {
      buffer.writeln('Vehicle type multiplier (${(vehicleTypeMultiplier * 100).toStringAsFixed(0)}%): ${vehicleTypeMultiplier > 1.0 ? '+' : ''}${((vehicleTypeMultiplier - 1) * 100).toStringAsFixed(0)}%');
    }
    
    return buffer.toString();
  }

  /// Fallback calculation when backend is unavailable
  EnhancedFareCalculation _calculateFallbackFare({
    required RouteResult pickupToDestinationRoute,
    required int passengerCount,
    String vehicleType = 'tricycle',
    DateTime? requestTime,
    String? zone,
  }) {
    
    // Use default values for fallback
    const baseFare = 25.0;
    const perKmRate = 12.0;
    const perPassengerRate = 5.0;
    
    // Estimate driver distance (assume average 2km)
    const estimatedDriverDistanceKm = 2.0;
    final pickupToDestinationDistanceKm = pickupToDestinationRoute.distance / 1000.0;
    
    final driverToPickupFare = estimatedDriverDistanceKm * perKmRate;
    final pickupToDestinationFare = pickupToDestinationDistanceKm * perKmRate;
    final extraPassengers = max(0, passengerCount - 1);
    final passengerFare = extraPassengers * perPassengerRate;
    
    final subtotal = baseFare + driverToPickupFare + pickupToDestinationFare + passengerFare;
    final totalFare = max(25.0, min(subtotal, 500.0));
    
    
    return EnhancedFareCalculation(
      baseFare: baseFare,
      driverToPickupFare: driverToPickupFare,
      pickupToDestinationFare: pickupToDestinationFare,
      passengerFare: passengerFare,
      timeMultiplier: 1.0,
      zoneMultiplier: 1.0,
      vehicleTypeMultiplier: 1.0,
      subtotal: subtotal,
      totalFare: totalFare,
      breakdown: 'Fallback calculation (offline mode)',
      driverToPickupDistanceKm: estimatedDriverDistanceKm,
      pickupToDestinationDistanceKm: pickupToDestinationDistanceKm,
    );
  }

  /// Fallback calculation from distance
  EnhancedFareCalculation _calculateFallbackFareFromDistance({
    required double pickupToDestinationDistanceKm,
    required int passengerCount,
    String vehicleType = 'tricycle',
    DateTime? requestTime,
    String? zone,
  }) {
    const baseFare = 25.0;
    const perKmRate = 12.0;
    const perPassengerRate = 5.0;
    const estimatedDriverDistanceKm = 2.0;
    
    final driverToPickupFare = estimatedDriverDistanceKm * perKmRate;
    final pickupToDestinationFare = pickupToDestinationDistanceKm * perKmRate;
    final extraPassengers = max(0, passengerCount - 1);
    final passengerFare = extraPassengers * perPassengerRate;
    
    final subtotal = baseFare + driverToPickupFare + pickupToDestinationFare + passengerFare;
    final totalFare = max(25.0, min(subtotal, 500.0));
    
    return EnhancedFareCalculation(
      baseFare: baseFare,
      driverToPickupFare: driverToPickupFare,
      pickupToDestinationFare: pickupToDestinationFare,
      passengerFare: passengerFare,
      timeMultiplier: 1.0,
      zoneMultiplier: 1.0,
      vehicleTypeMultiplier: 1.0,
      subtotal: subtotal,
      totalFare: totalFare,
      breakdown: 'Fallback calculation (offline mode)',
      driverToPickupDistanceKm: estimatedDriverDistanceKm,
      pickupToDestinationDistanceKm: pickupToDestinationDistanceKm,
    );
  }

  /// Create default fare configuration in Firestore
  Future<void> _createDefaultFareConfig(FareConfigModel config) async {
    try {
      await _firestore
          .collection(_fareConfigCollection)
          .doc(config.id)
          .set(config.toFirestore());
    } catch (e) {
      // Ignore errors - this is just for initialization
    }
  }

  /// Create default terminal in Firestore
  Future<void> _createDefaultTerminal(TerminalLocation terminal) async {
    try {
      await _firestore
          .collection(_terminalCollection)
          .doc(terminal.id)
          .set(terminal.toFirestore());
    } catch (e) {
      // Ignore errors - this is just for initialization
    }
  }

  /// Clear cache (useful for testing or when config changes)
  void clearCache() {
    _cachedFareConfig = null;
    _cachedTerminal = null;
    _lastConfigFetch = null;
    _lastTerminalFetch = null;
  }
}
