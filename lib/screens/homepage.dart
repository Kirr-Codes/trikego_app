import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../Services/location_service.dart';
import '../Services/address_service.dart';
import '../Services/places_service.dart';
import '../Services/route_service.dart';
import '../Services/booking_service.dart';
import '../Services/notification_service.dart';
import '../Services/connectivity_service.dart';
import '../models/fare_config_model.dart';
import '../models/booking_model.dart';
import '../widgets/profile_drawer.dart';
import '../widgets/circle_icon_button_widget.dart';
import '../widgets/search_panel_widget.dart';
import '../widgets/driver_cancelled_dialog.dart';
import '../widgets/connectivity_banner_widget.dart';
import '../utils/snackbar_utils.dart';
import '../utils/dialog_utils.dart';
import '../main.dart' show AppColors;
import 'destination_search_screen.dart';
import 'service_unavailable_page.dart';
import 'payment_method_screen.dart';
import 'notifications_screen.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final LocationService _locationService = LocationService();
  final AddressService _addressService = AddressService();
  final BookingService _bookingService = BookingService();
  final NotificationService _notificationService = NotificationService();
  final ConnectivityService _connectivityService = ConnectivityService();
  GoogleMapController? _mapController;

  LatLng? _currentPosition;
  LocationState _locationState = LocationState.initial;
  String _currentAddress = 'Getting your location...';
  StreamSubscription<LatLng>? _locationSubscription;
  StreamSubscription<LocationState>? _stateSubscription;
  StreamSubscription<bool>? _connectivitySubscription;
  bool _isConnected = true;

  PlaceSearchResult? _selectedDestination;
  RouteResult? _currentRoute;
  Set<Polyline> _polylines = {};
  Set<Marker> _destinationMarkers = {};
  bool _isCalculatingRoute = false;

  bool _isServiceAvailable = true;
  String _serviceUnavailableReason = '';

  bool _showBookingInformation = false;
  int _passengerCount = 1;
  String? _selectedPaymentMethod;
  EnhancedFareCalculation? _currentFareCalculation;
  Booking? _activeBooking;
  StreamSubscription<Booking?>? _bookingSubscription;
  bool _isCreatingBooking = false;

  Set<Polyline> _driverRoutePolylines = {};
  Set<Marker> _driverMarkers = {};
  BitmapDescriptor? _driverIcon;

  static const LatLng _defaultLocation = LatLng(
    14.8312,
    120.7895,
  );
  static const double _serviceRadiusKm = 10.0;

  @override
  void initState() {
    super.initState();
    _loadDriverMarker();
    _initializeLocation();
    _initializeBookingService();
    _initializeConnectivity();
    _notificationService.initialize();
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _stateSubscription?.cancel();
    _bookingSubscription?.cancel();
    _connectivitySubscription?.cancel();
    _locationService.stopTracking();
    super.dispose();
  }

  /// Load custom driver marker icon
  Future<void> _loadDriverMarker() async {
    try {
      final ByteData data = await rootBundle.load('assets/images/driver_marker.png');
      final ui.Codec codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(),
        targetWidth: 35,
      );
      final ui.FrameInfo frameInfo = await codec.getNextFrame();
      final ByteData? byteData = await frameInfo.image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      final Uint8List resizedBytes = byteData!.buffer.asUint8List();
      
      setState(() {
        _driverIcon = BitmapDescriptor.bytes(resizedBytes);
      });
    } catch (e) {}
  }

  void _initializeConnectivity() {
    _connectivityService.initialize();
    _connectivitySubscription = _connectivityService.connectivityStream.listen((isConnected) {
      if (mounted) {
        setState(() {
          _isConnected = isConnected;
        });
        
      }
    });
  }

  void _initializeBookingService() {
    _bookingService.initialize();
    _bookingSubscription = _bookingService.activeBookingStream.listen((
      booking,
    ) {
      if (mounted) {
        if (_activeBooking != null &&
            booking != null &&
            _activeBooking!.status != BookingStatus.cancelled &&
            booking.status == BookingStatus.cancelled &&
            booking.cancelledBy == 'driver') {
          _showDriverCancelledDialog();
        }

        setState(() {
          _activeBooking = booking;
          if (booking != null && booking.isActive) {
            _showBookingInformation = false;
          }
        });

        _handleBookingUpdate(booking);
      }
    });
  }

  /// Show dialog when driver cancels the booking
  void _showDriverCancelledDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => DriverCancelledDialog(
        onContinue: () async {
          Navigator.of(context).pop();
          if (_selectedDestination != null && _currentRoute != null) {
            await _confirmBooking();
          }
        },
        onCancel: () {
          Navigator.of(context).pop();
          setState(() {
            _selectedDestination = null;
            _currentRoute = null;
            _polylines.clear();
            _destinationMarkers.clear();
            _showBookingInformation = false;
          });
        },
      ),
    );
  }

  /// Handle booking updates and driver location display
  Future<void> _handleBookingUpdate(Booking? booking) async {
    if (booking == null || !booking.isActive) {
      setState(() {
        _driverMarkers.clear();
        _driverRoutePolylines.clear();
        _polylines.clear();
        _destinationMarkers.clear();
      });
      return;
    }

    if (booking.status == BookingStatus.accepted) {
      if (booking.driverLocation != null) {
        await _updateDriverLocationOnMap(booking);
      } else {
        await _showPickupToDestinationRoute(booking);
      }
    } else if (booking.status == BookingStatus.pickedUp || booking.status == BookingStatus.inProgress) {
      if (booking.driverLocation != null) {
        await _updateDriverToDestinationOnMap(booking);
      } else {
        await _showPickupToDestinationRoute(booking);
      }
    }
  }

  Future<void> _updateDriverLocationOnMap(Booking booking) async {
    if (booking.driverLocation == null || _currentPosition == null) return;

    try {
      final driverLatLng = booking.driverLocation!.latLng;
      final pickupLatLng = booking.pickupLocation.latLng;

      final driverMarker = Marker(
        markerId: const MarkerId('driver_location'),
        position: driverLatLng,
        icon: _driverIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        anchor: const Offset(0.5, 0.5),
        infoWindow: InfoWindow(
          title: 'Your Driver',
          snippet: booking.driver?.fullName ?? 'Driver approaching',
        ),
      );

      final driverToPickupRoute = await RouteService.getRoute(
        startLatitude: driverLatLng.latitude,
        startLongitude: driverLatLng.longitude,
        endLatitude: pickupLatLng.latitude,
        endLongitude: pickupLatLng.longitude,
      );

      setState(() {
        _driverMarkers.clear();
        _driverMarkers.add(driverMarker);

        _polylines.clear();
        _destinationMarkers.clear();

        _driverRoutePolylines.clear();
        if (driverToPickupRoute != null) {
          _driverRoutePolylines.add(
            Polyline(
              polylineId: const PolylineId('driver_to_pickup'),
              points: driverToPickupRoute.points,
              color: AppColors.primary,
              width: 5,
            ),
          );
        }
      });

      // Always update camera to follow driver and show pickup location
      _fitCameraToShowDriverAndPickup(driverLatLng, pickupLatLng);
    } catch (e) {}
  }

  /// Fit camera to show both driver and pickup locations
  void _fitCameraToShowDriverAndPickup(
    LatLng driverLocation,
    LatLng pickupLocation,
  ) {
    if (_mapController == null) return;

    final bounds = LatLngBounds(
      southwest: LatLng(
        driverLocation.latitude < pickupLocation.latitude
            ? driverLocation.latitude
            : pickupLocation.latitude,
        driverLocation.longitude < pickupLocation.longitude
            ? driverLocation.longitude
            : pickupLocation.longitude,
      ),
      northeast: LatLng(
        driverLocation.latitude > pickupLocation.latitude
            ? driverLocation.latitude
            : pickupLocation.latitude,
        driverLocation.longitude > pickupLocation.longitude
            ? driverLocation.longitude
            : pickupLocation.longitude,
      ),
    );

    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100.0));
  }

  Future<void> _updateDriverToDestinationOnMap(Booking booking) async {
    if (booking.driverLocation == null) return;

    try {
      final driverLatLng = booking.driverLocation!.latLng;
      final destinationLatLng = booking.destination.latLng;

      final driverMarker = Marker(
        markerId: const MarkerId('driver_location'),
        position: driverLatLng,
        icon: _driverIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        anchor: const Offset(0.5, 0.5),
        infoWindow: InfoWindow(
          title: 'Your Driver',
          snippet: booking.driver?.fullName ?? 'En route to destination',
        ),
      );

      final destinationMarker = Marker(
        markerId: const MarkerId('destination'),
        position: destinationLatLng,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(
          title: 'Destination',
          snippet: booking.destination.address,
        ),
      );

      final driverToDestinationRoute = await RouteService.getRoute(
        startLatitude: driverLatLng.latitude,
        startLongitude: driverLatLng.longitude,
        endLatitude: destinationLatLng.latitude,
        endLongitude: destinationLatLng.longitude,
      );

      setState(() {
        _driverMarkers.clear();
        _driverMarkers.add(driverMarker);
        _destinationMarkers = {destinationMarker};
        _polylines.clear();
        _driverRoutePolylines.clear();
        if (driverToDestinationRoute != null) {
          _driverRoutePolylines.add(
            Polyline(
              polylineId: const PolylineId('driver_to_destination'),
              points: driverToDestinationRoute.points,
              color: AppColors.primary,
              width: 5,
            ),
          );
        }
      });

      // Always update camera to follow driver and show destination
      _fitCameraToShowDriverAndDestination(driverLatLng, destinationLatLng);
    } catch (e) {}
  }

  void _fitCameraToShowDriverAndDestination(
    LatLng driverLocation,
    LatLng destinationLocation,
  ) {
    if (_mapController == null) return;

    final bounds = LatLngBounds(
      southwest: LatLng(
        driverLocation.latitude < destinationLocation.latitude
            ? driverLocation.latitude
            : destinationLocation.latitude,
        driverLocation.longitude < destinationLocation.longitude
            ? driverLocation.longitude
            : destinationLocation.longitude,
      ),
      northeast: LatLng(
        driverLocation.latitude > destinationLocation.latitude
            ? driverLocation.latitude
            : destinationLocation.latitude,
        driverLocation.longitude > destinationLocation.longitude
            ? driverLocation.longitude
            : destinationLocation.longitude,
      ),
    );

    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100.0));
  }

  /// Show pickup to destination route when ride is in progress
  Future<void> _showPickupToDestinationRoute(Booking booking) async {
    try {
      setState(() {
        _driverRoutePolylines.clear();
      });

      final destinationMarker = Marker(
        markerId: const MarkerId('destination'),
        position: booking.destination.latLng,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(
          title: 'Destination',
          snippet: booking.destination.address,
        ),
      );

      setState(() {
        _destinationMarkers = {destinationMarker};
        _polylines = {
          Polyline(
            polylineId: const PolylineId('pickup_to_destination'),
            points: booking.route.points,
            color: AppColors.primary,
            width: 5,
          ),
        };
      });

      if (booking.route.points.isNotEmpty) {
        _fitCameraToRoute(booking.route.points);
      }
    } catch (e) {}
  }
  Future<void> _initializeLocation() async {
    _locationSubscription = _locationService.locationStream.listen((
      location,
    ) async {
      if (mounted) {
        setState(() => _currentPosition = location);
        _updateMapCamera(location);

        _checkServiceAvailability(location);
        _updateAddress(location);
      }
    });

    _stateSubscription = _locationService.stateStream.listen((state) {
      if (mounted) {
        setState(() => _locationState = state);
        _handleLocationState(state);
      }
    });

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
    // Check if location services are enabled
    if (!await Geolocator.isLocationServiceEnabled()) {
      if (mounted) {
        DialogUtils.showLocationDialog(
          context,
          title: 'Location Access Required',
          message: 'Please enable location services to search for destinations and book rides.',
          actionText: 'Open Settings',
          onAction: () => _locationService.openLocationSettings(),
        );
      }
      return;
    }

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
      _selectedPaymentMethod = null;
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
    // Prevent duplicate booking creation
    if (_isCreatingBooking) {
      return;
    }

    // Check internet connectivity
    if (!_connectivityService.isConnected) {
      if (mounted) {
        context.showError('No internet connection. Please check your connection and try again.');
      }
      return;
    }

    // Check if location services are enabled before creating booking
    if (!await Geolocator.isLocationServiceEnabled()) {
      if (mounted) {
        context.showError('Cannot create booking. Location services are disabled.');
        DialogUtils.showLocationDialog(
          context,
          title: 'Location Services Required',
          message: 'Please enable location services to create a booking. This is required to track your ride.',
          actionText: 'Open Settings',
          onAction: () => _locationService.openLocationSettings(),
        );
      }
      return;
    }

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

    // Set processing state to prevent duplicate submissions
    setState(() {
      _isCreatingBooking = true;
    });

    // Default to cash payment if no payment method selected
    String selectedPaymentMethod = 'cash';

    try {
      // Double-check connectivity before making Firestore call
      final hasConnection = await _connectivityService.checkConnectivity();
      if (!hasConnection) {
        if (mounted) {
          context.showError('Lost internet connection. Please try again.');
          setState(() {
            _isCreatingBooking = false;
          });
        }
        return;
      }
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
        paymentMethod: selectedPaymentMethod,
      );

      if (result.success) {
        if (mounted) {
          setState(() {
            _showBookingInformation = false;
            _isCreatingBooking = false;
          });
        }
      } else {
        if (mounted) {
          context.showError(result.message);
          setState(() {
            _isCreatingBooking = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        context.showError('Failed to create booking. Please try again.');
        setState(() {
          _isCreatingBooking = false;
        });
      }
    }
  }

  /// Cancel active booking
  Future<void> _cancelBooking() async {
    if (_activeBooking == null) return;

    // Show confirmation dialog
    final confirmed = await _showCancelConfirmationDialog();
    if (!confirmed) return;

    final result = await _bookingService.cancelBooking();
    if (result.success) {
      if (mounted) {
        // Reset UI state to show search panel again
        setState(() {
          _showBookingInformation = false;
          _selectedDestination = null;
          _currentRoute = null;
          _selectedPaymentMethod = null;
          // Clear driver markers and routes
          _driverMarkers.clear();
          _driverRoutePolylines.clear();
        });
      }
    } else {
      if (mounted) {
        context.showError(result.message);
      }
    }
  }

  /// Show cancel booking confirmation dialog
  Future<bool> _showCancelConfirmationDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              Icons.cancel_outlined,
              color: Colors.red.shade600,
              size: 24,
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Cancel Booking',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        content: const Text(
          'Are you sure you want to cancel this booking? This action cannot be undone.',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey,
          ),
        ),
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  'Keep Booking',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Yes, Cancel',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// Build map markers
  Set<Marker> _buildMarkers() {
    final markers = <Marker>{};

    // Add user location marker ONLY if passenger has not been picked up
    // When passenger is picked up, the driver marker represents the passenger's location
    final isPassengerPickedUp = _activeBooking?.status == BookingStatus.pickedUp ||
                                 _activeBooking?.status == BookingStatus.inProgress;
    
    if (_currentPosition != null && !isPassengerPickedUp) {
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

    // Add driver markers (when booking is accepted)
    markers.addAll(_driverMarkers);

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
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
            markers: _buildMarkers(),
            polylines: {..._polylines, ..._driverRoutePolylines},
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
                  StreamBuilder<int>(
                    stream: _notificationService.unreadCountStream,
                    builder: (context, snapshot) {
                      final unreadCount = snapshot.data ?? 0;
                      return Stack(
                        children: [
                          CircleIconButtonWidget(
                            icon: Icons.notifications_none_rounded,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const NotificationsScreen(),
                                ),
                              );
                            },
                          ),
                          if (unreadCount > 0)
                            Positioned(
                              right: 4,
                              top: 4,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 18,
                                  minHeight: 18,
                                ),
                                child: Center(
                                  child: Text(
                                    unreadCount > 99
                                        ? '99+'
                                        : unreadCount.toString(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // Connectivity banner at top (below menu bar)
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: AnimatedSlide(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              offset: _isConnected ? const Offset(0, -1) : const Offset(0, 0),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: _isConnected ? 0 : 1,
                child: const ConnectivityBanner(),
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
                isProcessing: _isCreatingBooking,
                onDestinationSearch: _openDestinationSearch,
                onNext: _openBookingInformation,
                onClear: _clearDestination,
                onCloseBooking: _clearDestination,
                onDecreasePassengers: _decreasePassengers,
                onIncreasePassengers: _increasePassengers,
                onCashPayment: () async {
                  // Show payment method selection
                  final selectedPaymentMethod = await Navigator.push<String>(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PaymentMethodScreen(),
                    ),
                  );

                  if (selectedPaymentMethod != null && mounted) {
                    setState(() {
                      _selectedPaymentMethod = selectedPaymentMethod;
                    });
                  }
                },
                selectedPaymentMethod: _selectedPaymentMethod,
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
