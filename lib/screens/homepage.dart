import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/location_service.dart';
import '../services/address_service.dart';
import '../widgets/profile_drawer.dart';
import '../utils/snackbar_utils.dart';
import '../main.dart' show AppColors;

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
    _locationSubscription = _locationService.locationStream.listen((location) async {
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
        _showLocationDialog(
          'Location Services Disabled',
          'Please enable location services in settings.',
          'Open Settings',
          () => _locationService.openLocationSettings(),
        );
        break;
      case LocationState.permissionDenied:
        context.showWarning(state.message);
        _showLocationDialog(
          'Location Permission Required',
          'Please allow location access to use this feature.',
          'App Settings',
          () => _locationService.openAppSettings(),
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

  /// Show location permission dialog
  void _showLocationDialog(
    String title,
    String message,
    String actionText,
    VoidCallback onAction,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onAction();
            },
            child: Text(actionText),
          ),
        ],
      ),
    );
  }

  /// Build map markers
  Set<Marker> _buildMarkers() {
    if (_currentPosition == null) return {};

    return {
      Marker(
        markerId: const MarkerId('user_location'),
        position: _currentPosition!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        infoWindow: const InfoWindow(
          title: 'Your Location',
          snippet: 'Current position',
        ),
      ),
    };
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
          const Text(
            'Where are you going?',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
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
            icon: Icons.location_on_outlined,
            iconColor: Colors.redAccent,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: 300,
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 2,
              ),
              child: const Text(
                'Choose this destination',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Show full address dialog when location field is tapped
  void _showFullAddressDialog(String? fullAddress) {
    if (fullAddress == null) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(
              Icons.location_pin,
              color: Colors.green.shade600,
              size: 24,
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Your Current Location',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Live Location',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    fullAddress,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'This is your real-time GPS location. It updates automatically as you move.',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
                height: 1.3,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Close',
              style: TextStyle(
                color: Colors.green.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
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
  }) {
    return GestureDetector(
      onTap: isCurrentLocation && displayText != null 
        ? () => _showFullAddressDialog(displayText)
        : null,
      child: Container(
        decoration: BoxDecoration(
          color: isCurrentLocation ? Colors.green.shade50 : const Color(0xFFF2F2F4),
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
            Icon(
              icon, 
              color: iconColor,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                displayText ?? hintText,
                style: TextStyle(
                  fontSize: 14,
                  color: displayText != null 
                    ? Colors.black87 
                    : Colors.black.withOpacity(0.4),
                  fontWeight: displayText != null ? FontWeight.w500 : FontWeight.w400,
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
