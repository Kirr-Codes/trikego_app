import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Professional location service for handling all location operations
class LocationService {
  LocationService._();
  static final LocationService _instance = LocationService._();
  factory LocationService() => _instance;

  // Stream controllers
  StreamSubscription<Position>? _positionStream;
  final StreamController<LatLng> _locationController =
      StreamController<LatLng>.broadcast();
  final StreamController<LocationState> _stateController =
      StreamController<LocationState>.broadcast();

  // Current state
  LatLng? _currentLocation;
  LocationState _currentState = LocationState.initial;

  // Getters
  Stream<LatLng> get locationStream => _locationController.stream;
  Stream<LocationState> get stateStream => _stateController.stream;
  LatLng? get currentLocation => _currentLocation;
  LocationState get currentState => _currentState;

  /// Initialize location service
  Future<bool> initialize() async {
    try {
      _updateState(LocationState.initializing);

      // Check location services
      if (!await Geolocator.isLocationServiceEnabled()) {
        _updateState(LocationState.serviceDisabled);
        return false;
      }

      // Handle permissions
      final permission = await _checkPermissions();
      if (!_isPermissionGranted(permission)) {
        _updateState(LocationState.permissionDenied);
        return false;
      }

      // Get initial position and start tracking
      await _getCurrentPosition();
      _startTracking();

      _updateState(LocationState.tracking);
      return true;
    } catch (e) {
      if (kDebugMode) print('LocationService error: $e');
      _updateState(LocationState.error);
      return false;
    }
  }

  /// Check and request permissions
  Future<LocationPermission> _checkPermissions() async {
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    return permission;
  }

  /// Check if permission is granted
  bool _isPermissionGranted(LocationPermission permission) {
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  /// Get current position
  Future<void> _getCurrentPosition() async {
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    );

    final latLng = LatLng(position.latitude, position.longitude);
    _currentLocation = latLng;
    _locationController.add(latLng);
  }

  /// Start location tracking
  void _startTracking() {
    _positionStream =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.bestForNavigation,
            distanceFilter: 10,
          ),
        ).listen(
          (position) {
            final latLng = LatLng(position.latitude, position.longitude);
            _currentLocation = latLng;
            _locationController.add(latLng);
          },
          onError: (error) {
            if (kDebugMode) print('Location stream error: $error');
            _updateState(LocationState.error);
          },
        );
  }

  /// Update state
  void _updateState(LocationState state) {
    _currentState = state;
    _stateController.add(state);
  }

  /// Stop tracking
  void stopTracking() {
    _positionStream?.cancel();
    _positionStream = null;
    _updateState(LocationState.stopped);
  }

  /// Open location settings
  Future<void> openLocationSettings() async {
    await Geolocator.openLocationSettings();
  }

  /// Open app settings
  Future<void> openAppSettings() async {
    await Geolocator.openAppSettings();
  }

  /// Dispose resources
  void dispose() {
    _positionStream?.cancel();
    _locationController.close();
    _stateController.close();
  }
}

/// Location service states
enum LocationState {
  initial,
  initializing,
  tracking,
  serviceDisabled,
  permissionDenied,
  stopped,
  error,
}

/// Extension for state messages
extension LocationStateExt on LocationState {
  String get message {
    switch (this) {
      case LocationState.serviceDisabled:
        return 'Location services are disabled';
      case LocationState.permissionDenied:
        return 'Location permission denied';
      case LocationState.error:
        return 'Location error occurred';
      default:
        return '';
    }
  }

  bool get isActive => this == LocationState.tracking;
}
