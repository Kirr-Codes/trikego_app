import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../Services/location_service.dart';
import '../Services/address_service.dart';
import '../Services/places_service.dart';
import '../Services/route_service.dart';
import '../Services/booking_service.dart';
import '../models/fare_config_model.dart';
import '../models/booking_model.dart';
import '../widgets/profile_drawer.dart';
import '../widgets/circle_icon_button_widget.dart';
import '../widgets/search_panel_widget.dart';
import '../utils/snackbar_utils.dart';
import '../utils/dialog_utils.dart';
import '../main.dart' show AppColors;
import 'destination_search_screen.dart';
import 'service_unavailable_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final LocationService _locationService = LocationService();
  final AddressService _addressService = AddressService();
  final BookingService _bookingService = BookingService();
  GoogleMapController? _mapController;

  LatLng? _currentPosition;
  LocationState _locationState = LocationState.initial;
  String _currentAddress = 'Getting your location...';
  StreamSubscription<LatLng>? _locationSubscription;
  StreamSubscription<LocationState>? _stateSubscription;

  // Destination and route state
  PlaceSearchResult? _selectedDestination;
  RouteResult? _currentRoute;
  Set<Polyline> _polylines = {};
  Set<Marker> _destinationMarkers = {};
  bool _isCalculatingRoute = false;

  // Service availability state
  bool _isServiceAvailable = true;
  String _serviceUnavailableReason = '';

  // Booking state
  bool _showBookingInformation = false;
  int _passengerCount = 1;
  EnhancedFareCalculation? _currentFareCalculation;
  Booking? _activeBooking;
  StreamSubscription<Booking?>? _bookingSubscription;

  static const LatLng _defaultLocation = LatLng(
    14.8312,
    120.7895,
  ); // Paombong Bulacan Municipal Hall
  static const double _serviceRadiusKm = 2.0; // 2km service radius

  @override
  void initState() {
    super.initState();
    _initializeLocation();
    _initializeBookingService();
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _stateSubscription?.cancel();
    _bookingSubscription?.cancel();
    _locationService.stopTracking();
    super.dispose();
  }

  /// Initialize booking service and set up listeners
  void _initializeBookingService() {
    // Listen to active booking updates
    _bookingSubscription = _bookingService.activeBookingStream.listen((
      booking,
    ) {
      if (mounted) {
        setState(() {
          _activeBooking = booking;
          // If there's an active booking, hide booking information UI
          if (booking != null && booking.isActive) {
            _showBookingInformation = false;
          }
        });
      }
    });
  }

  /// Initialize location service and set up listeners
  Future<void> _initializeLocation() async {
    // Listen to location updates
    _locationSubscription = _locationService.locationStream.listen((
      location,
    ) async {
      if (mounted) {
        setState(() => _currentPosition = location);
        _updateMapCamera(location);

        // Check service availability
        _checkServiceAvailability(location);

        // Get address for this location
        _updateAddress(location);
      }
    });

    // Listen to state changes
    _stateSubscription = _locationService.stateStream.listen((state) {
      if (mounted) {
        setState(() => _locationState = state);
        _handleLocationState(state);
      }
    });

    // Initialize service
    final success = await _locationService.initialize();
    if (!success && mounted) {
      setState(() {
        _currentPosition = _defaultLocation;
        _currentAddress = 'Paombong, Bulacan (Default)';
      });
      _updateMapCamera(_defaultLocation);
    }
  }

  /// Update address from coordinates
  Future<void> _updateAddress(LatLng location) async {
    try {
      final address = await _addressService.getAddressFromCoordinates(location);
      if (mounted) {
        setState(() => _currentAddress = address);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _currentAddress = 'Unable to get address');
      }
    }
  }

  /// Check if user is within service area
  void _checkServiceAvailability(LatLng userLocation) {
    final distance = RouteService.calculateDistance(
      _defaultLocation,
      userLocation,
    );
    final distanceKm = distance / 1000;

    if (distanceKm > _serviceRadiusKm) {
      setState(() {
        _isServiceAvailable = false;
        _serviceUnavailableReason =
            'You are ${distanceKm.toStringAsFixed(1)}km away from our service area';
      });
    } else {
      setState(() {
        _isServiceAvailable = true;
        _serviceUnavailableReason = '';
      });
    }
  }

  /// Handle location state changes
  void _handleLocationState(LocationState state) {
    switch (state) {
      case LocationState.serviceDisabled:
        context.showError(state.message);
        DialogUtils.showLocationDialog(
          context,
          title: 'Location Services Disabled',
          message: 'Please enable location services in settings.',
          actionText: 'Open Settings',
          onAction: () => _locationService.openLocationSettings(),
        );
        break;
      case LocationState.permissionDenied:
        context.showWarning(state.message);
        DialogUtils.showLocationDialog(
          context,
          title: 'Location Permission Required',
          message: 'Please allow location access to use this feature.',
          actionText: 'App Settings',
          onAction: () => _locationService.openAppSettings(),
        );
        break;
      case LocationState.error:
        context.showError('Failed to get location');
        break;
      default:
        break;
    }
  }

  /// Update map camera
  void _updateMapCamera(LatLng position) {
    _mapController?.animateCamera(CameraUpdate.newLatLng(position));
  }

  /// Open destination search screen
  Future<void> _openDestinationSearch() async {
    if (_currentPosition == null) {
      context.showError('Please wait for your location to be detected.');
      return;
    }

    // Check if service is available
    if (!_isServiceAvailable) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ServiceUnavailablePage(
            userLocation: _currentAddress,
            reason: _serviceUnavailableReason,
          ),
        ),
      );
      return;
    }

    final result = await Navigator.push<PlaceSearchResult>(
      context,
      MaterialPageRoute(
        builder: (context) => DestinationSearchScreen(
          currentLatitude: _currentPosition!.latitude,
          currentLongitude: _currentPosition!.longitude,
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _selectedDestination = result;
      });
      await _calculateRoute();
    }
  }

  /// Calculate route to selected destination
  Future<void> _calculateRoute() async {
    if (_currentPosition == null || _selectedDestination == null) return;

    // Check distance limit before calculating route
    final distance = RouteService.calculateDistance(
      _currentPosition!,
      LatLng(_selectedDestination!.latitude, _selectedDestination!.longitude),
    );

    const double maxDistanceKm = 20.0; // 20km limit
    const double maxDistanceMeters = maxDistanceKm * 1000;

    if (distance > maxDistanceMeters) {
      DialogUtils.showDistanceLimitDialog(context, distance, _clearDestination);
      return;
    }

    setState(() => _isCalculatingRoute = true);

    try {
      final route = await RouteService.getRoute(
        startLatitude: _currentPosition!.latitude,
        startLongitude: _currentPosition!.longitude,
        endLatitude: _selectedDestination!.latitude,
        endLongitude: _selectedDestination!.longitude,
        avoidHighways: false, // Allow highways for tricycle/car
        avoidTolls: false, // Allow tolls
      );

      if (route != null && mounted) {
        // Calculate enhanced fare for current passenger count
        final fareCalculation = await _bookingService.calculateEnhancedFare(
          pickupLatitude: _currentPosition!.latitude,
          pickupLongitude: _currentPosition!.longitude,
          route: route,
          passengerCount: _passengerCount,
          vehicleType: 'tricycle',
        );

        setState(() {
          _currentRoute = route;
          _currentFareCalculation = fareCalculation;
          _polylines = {
            Polyline(
              polylineId: const PolylineId('route'),
              points: route.points,
              color: AppColors.primary,
              width: 5,
              patterns: [],
            ),
          };
          _destinationMarkers = {
            Marker(
              markerId: const MarkerId('destination'),
              position: LatLng(
                _selectedDestination!.latitude,
                _selectedDestination!.longitude,
              ),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueRed,
              ),
              infoWindow: InfoWindow(
                title: _selectedDestination!.name,
                snippet: '${route.distanceText} • ${route.durationText}',
              ),
            ),
          };
        });

        // Fit camera to show both start and end points
        _fitCameraToRoute(route.points);
      } else {
        if (mounted) {
          context.showError('Unable to calculate route. Please try again.');
        }
      }
    } catch (e) {
      if (mounted) {
        context.showError(
          'Failed to calculate route. Please check your internet connection.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCalculatingRoute = false);
      }
    }
  }

  /// Fit camera to show the entire route
  void _fitCameraToRoute(List<LatLng> points) {
    if (points.isEmpty) return;

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final point in points) {
      minLat = minLat < point.latitude ? minLat : point.latitude;
      maxLat = maxLat > point.latitude ? maxLat : point.latitude;
      minLng = minLng < point.longitude ? minLng : point.longitude;
      maxLng = maxLng > point.longitude ? maxLng : point.longitude;
    }

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    _mapController?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100.0));
  }

  /// Clear destination and route
  void _clearDestination() {
    setState(() {
      _selectedDestination = null;
      _currentRoute = null;
      _polylines = {};
      _destinationMarkers = {};
      _showBookingInformation = false;
      _passengerCount = 1;
    });
  }

  /// Show booking information UI
  Future<void> _openBookingInformation() async {
    if (_selectedDestination == null || _currentPosition == null) return;

    // Calculate route if not already calculated
    if (_currentRoute == null) {
      await _calculateRoute();
    }

    if (_currentRoute != null) {
      setState(() {
        _showBookingInformation = true;
      });
    }
  }

  /// Decrease passenger count
  void _decreasePassengers() {
    if (_passengerCount > 1) {
      setState(() {
        _passengerCount--;
      });
      _recalculateFare();
    }
  }

  /// Increase passenger count
  void _increasePassengers() {
    if (_passengerCount < 4) {
      // Max 4 passengers for tricycle
      setState(() {
        _passengerCount++;
      });
      _recalculateFare();
    }
  }

  /// Recalculate fare when passenger count changes
  Future<void> _recalculateFare() async {
    if (_currentRoute != null && _currentPosition != null) {
      final fareCalculation = await _bookingService.calculateEnhancedFare(
        pickupLatitude: _currentPosition!.latitude,
        pickupLongitude: _currentPosition!.longitude,
        route: _currentRoute!,
        passengerCount: _passengerCount,
        vehicleType: 'tricycle',
      );
      if (mounted) {
        setState(() {
          _currentFareCalculation = fareCalculation;
        });
      }
    }
  }

  /// Confirm booking
  Future<void> _confirmBooking() async {
    if (_currentPosition == null ||
        _selectedDestination == null ||
        _currentRoute == null) {
      context.showError('Unable to create booking. Please try again.');
      return;
    }

    // Check if user already has an active booking
    if (_bookingService.hasActiveBooking) {
      context.showError('You already have an active booking.');
      return;
    }

    try {
      // Create booking locations
      final pickupLocation = BookingLocation(
        latitude: _currentPosition!.latitude,
        longitude: _currentPosition!.longitude,
        address: _currentAddress,
      );

      final destination = BookingLocation(
        latitude: _selectedDestination!.latitude,
        longitude: _selectedDestination!.longitude,
        address: _selectedDestination!.name,
      );

      // Create booking
      final result = await _bookingService.createBooking(
        pickupLocation: pickupLocation,
        destination: destination,
        route: _currentRoute!,
        passengerCount: _passengerCount,
        paymentMethod: 'cash',
      );

      if (result.success) {
        if (mounted) {
          context.showSuccess(
            'Booking created successfully! Looking for drivers...',
          );
          setState(() {
            _showBookingInformation = false;
          });
        }
      } else {
        if (mounted) {
          context.showError(result.message);
        }
      }
    } catch (e) {
      if (mounted) {
        context.showError('Failed to create booking. Please try again.');
      }
    }
  }

  /// Cancel active booking
  Future<void> _cancelBooking() async {
    if (_activeBooking == null) return;

    final result = await _bookingService.cancelBooking();
    if (result.success) {
      if (mounted) {
        context.showSuccess('Booking cancelled successfully');
      }
    } else {
      if (mounted) {
        context.showError(result.message);
      }
    }
  }

  /// Build map markers
  Set<Marker> _buildMarkers() {
    final markers = <Marker>{};

    // Add user location marker
    if (_currentPosition != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('user_location'),
          position: _currentPosition!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: const InfoWindow(
            title: 'Your Location',
            snippet: 'Current position',
          ),
        ),
      );
    }

    // Add destination markers
    markers.addAll(_destinationMarkers);

    return markers;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const ProfileDrawer(),
      body: Stack(
        children: [
          // Base map
          GoogleMap(
            onMapCreated: (GoogleMapController controller) {
              _mapController = controller;
            },
            initialCameraPosition: CameraPosition(
              target: _currentPosition ?? _defaultLocation,
              zoom: 15,
            ),
            myLocationEnabled: _locationState.isActive,
            myLocationButtonEnabled: false,
            markers: _buildMarkers(),
            polylines: _polylines,
          ),

          // Top overlay controls (menu + notifications)
          Positioned(
            left: 16,
            right: 16,
            top: 16,
            child: SafeArea(
              bottom: false,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Builder(
                    builder: (context) => CircleIconButtonWidget(
                      icon: Icons.menu,
                      onTap: () => Scaffold.of(context).openDrawer(),
                    ),
                  ),
                  CircleIconButtonWidget(
                    icon: Icons.notifications_none_rounded,
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ),

          // Bottom search panel
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: SafeArea(
              top: false,
              child: SearchPanelWidget(
                currentAddress: _currentAddress,
                serviceUnavailableReason: _serviceUnavailableReason,
                isServiceAvailable: _isServiceAvailable,
                selectedDestination: _selectedDestination,
                currentRoute: _currentRoute,
                isCalculatingRoute: _isCalculatingRoute,
                showBookingInformation: _showBookingInformation,
                passengerCount: _passengerCount,
                fareCalculation: _currentFareCalculation,
                activeBooking: _activeBooking,
                onDestinationSearch: _openDestinationSearch,
                onNext: _openBookingInformation,
                onClear: _clearDestination,
                onCloseBooking: () =>
                    setState(() => _showBookingInformation = false),
                onDecreasePassengers: _decreasePassengers,
                onIncreasePassengers: _increasePassengers,
                onCashPayment: () {
                  // Handle cash payment - could show payment options
                },
                onConfirm: _confirmBooking,
                onCancelBooking: _cancelBooking,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
