import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/location_service.dart';
import '../services/address_service.dart';
import '../services/places_service.dart';
import '../services/route_service.dart';
import '../widgets/profile_drawer.dart';
import '../utils/snackbar_utils.dart';
import '../utils/dialog_utils.dart';
import '../main.dart' show AppColors;
import 'destination_search_screen.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final LocationService _locationService = LocationService();
  final AddressService _addressService = AddressService();
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

  static const LatLng _defaultLocation = LatLng(14.5995, 120.9842); // Manila

  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _stateSubscription?.cancel();
    _locationService.stopTracking();
    super.dispose();
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
        _currentAddress = 'Manila, Philippines (Default)';
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
        setState(() {
          _currentRoute = route;
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

        context.showSuccess('Route calculated successfully!');
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
    });
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
                    builder: (context) => _circleIconButton(
                      icon: Icons.menu,
                      onTap: () => Scaffold.of(context).openDrawer(),
                    ),
                  ),
                  _circleIconButton(
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
            child: SafeArea(top: false, child: _buildSearchPanel(context)),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchPanel(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Where are you going?',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.speed, size: 14, color: Colors.blue.shade600),
                    const SizedBox(width: 4),
                    Text(
                      '20km limit',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'From',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 6),
          _locationField(
            hintText: 'Your location now',
            displayText: _currentAddress,
            icon: Icons.location_pin,
            iconColor: Colors.green,
            isCurrentLocation: true,
          ),
          const SizedBox(height: 12),
          const Text(
            'Where to?',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 6),
          _locationField(
            hintText: 'Enter your destination',
            displayText: _selectedDestination?.name,
            icon: Icons.location_on_outlined,
            iconColor: Colors.redAccent,
            onTap: _openDestinationSearch,
          ),
          const SizedBox(height: 12),
          if (_selectedDestination != null && _currentRoute != null) ...[
            // Route information
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.route, color: Colors.blue.shade600, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Route to ${_selectedDestination!.name}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_currentRoute!.distanceText} • ${_currentRoute!.durationText}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Clear destination button
            SizedBox(
              width: 300,
              child: ElevatedButton(
                onPressed: _clearDestination,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 2,
                ),
                child: const Text(
                  'Clear Destination',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ] else ...[
            // Choose destination button
            SizedBox(
              width: 300,
              child: ElevatedButton(
                onPressed: _isCalculatingRoute ? null : _openDestinationSearch,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 2,
                ),
                child: _isCalculatingRoute
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Choose Destination',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }


  Widget _locationField({
    required String hintText,
    String? displayText,
    required IconData icon,
    required Color iconColor,
    bool isCurrentLocation = false,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap:
          onTap ??
          (isCurrentLocation && displayText != null
              ? () => DialogUtils.showFullAddressDialog(context, displayText)
              : null),
      child: Container(
        decoration: BoxDecoration(
          color: isCurrentLocation
              ? Colors.green.shade50
              : const Color(0xFFF2F2F4),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isCurrentLocation
                ? Colors.green.shade200
                : Colors.black.withOpacity(0.08),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                displayText ?? hintText,
                style: TextStyle(
                  fontSize: 14,
                  color: displayText != null
                      ? Colors.black87
                      : Colors.black.withOpacity(0.4),
                  fontWeight: displayText != null
                      ? FontWeight.w500
                      : FontWeight.w400,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            if (isCurrentLocation && displayText != null)
              Icon(
                Icons.visibility_outlined,
                size: 16,
                color: Colors.green.shade600,
              ),
          ],
                ),
              ),
            );
          }

  Widget _circleIconButton({required IconData icon, VoidCallback? onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: Colors.black87, size: 22),
        ),
      ),
    );
  }
}
