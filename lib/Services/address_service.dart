import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Service for handling address-related operations
/// 
/// Features:
/// - Reverse geocoding (coordinates to address)
/// - Formatted address strings for Philippines
/// - Error handling for geocoding failures
/// - Caching for performance optimization
class AddressService {
  AddressService._();
  static final AddressService _instance = AddressService._();
  factory AddressService() => _instance;

  // Cache for addresses to avoid repeated API calls
  final Map<String, String> _addressCache = {};

  /// Convert coordinates to readable address
  /// 
  /// Returns formatted address like "123 Main St, Barangay Sample, Quezon City"
  /// Falls back to coordinates if geocoding fails
  Future<String> getAddressFromCoordinates(LatLng coordinates) async {
    final cacheKey = '${coordinates.latitude.toStringAsFixed(4)},${coordinates.longitude.toStringAsFixed(4)}';
    
    // Return cached address if available
    if (_addressCache.containsKey(cacheKey)) {
      return _addressCache[cacheKey]!;
    }

    try {
      final placemarks = await placemarkFromCoordinates(
        coordinates.latitude,
        coordinates.longitude,
      );

      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        final formattedAddress = _formatPhilippinesAddress(placemark);
        
        // Cache the result
        _addressCache[cacheKey] = formattedAddress;
        
        if (kDebugMode) {
          print('📍 Address found: $formattedAddress');
        }
        
        return formattedAddress;
      } else {
        return _fallbackAddress(coordinates);
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Geocoding error: $e');
      }
      return _fallbackAddress(coordinates);
    }
  }

  /// Format address specifically for Philippines locations
  String _formatPhilippinesAddress(Placemark placemark) {
    final parts = <String>[];

    // Street number and name
    if (placemark.street?.isNotEmpty == true) {
      parts.add(placemark.street!);
    } else if (placemark.name?.isNotEmpty == true) {
      parts.add(placemark.name!);
    }

    // Barangay (subLocality in Philippines)
    if (placemark.subLocality?.isNotEmpty == true) {
      parts.add('Brgy. ${placemark.subLocality}');
    }

    // City/Municipality
    if (placemark.locality?.isNotEmpty == true) {
      parts.add(placemark.locality!);
    } else if (placemark.subAdministrativeArea?.isNotEmpty == true) {
      parts.add(placemark.subAdministrativeArea!);
    }

    // Province (administrativeArea in Philippines)
    if (placemark.administrativeArea?.isNotEmpty == true && 
        placemark.administrativeArea != placemark.locality) {
      parts.add(placemark.administrativeArea!);
    }

    // If we have parts, join them
    if (parts.isNotEmpty) {
      return parts.join(', ');
    }

    // Fallback to any available information
    return _buildFallbackFromPlacemark(placemark);
  }

  /// Build fallback address from available placemark data
  String _buildFallbackFromPlacemark(Placemark placemark) {
    final parts = <String>[];

    if (placemark.name?.isNotEmpty == true) parts.add(placemark.name!);
    if (placemark.locality?.isNotEmpty == true) parts.add(placemark.locality!);
    if (placemark.administrativeArea?.isNotEmpty == true) parts.add(placemark.administrativeArea!);
    if (placemark.country?.isNotEmpty == true) parts.add(placemark.country!);

    return parts.isNotEmpty ? parts.join(', ') : 'Unknown location';
  }

  /// Fallback when geocoding completely fails
  String _fallbackAddress(LatLng coordinates) {
    return 'Lat: ${coordinates.latitude.toStringAsFixed(4)}, '
           'Lng: ${coordinates.longitude.toStringAsFixed(4)}';
  }

  /// Get short address (street + barangay only)
  Future<String> getShortAddress(LatLng coordinates) async {
    try {
      final placemarks = await placemarkFromCoordinates(
        coordinates.latitude,
        coordinates.longitude,
      );

      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        final parts = <String>[];

        // Street
        if (placemark.street?.isNotEmpty == true) {
          parts.add(placemark.street!);
        } else if (placemark.name?.isNotEmpty == true) {
          parts.add(placemark.name!);
        }

        // Barangay
        if (placemark.subLocality?.isNotEmpty == true) {
          parts.add('Brgy. ${placemark.subLocality}');
        }

        return parts.isNotEmpty ? parts.join(', ') : 'Current location';
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Short address geocoding error: $e');
      }
    }

    return 'Current location';
  }

  /// Clear address cache (useful for memory management)
  void clearCache() {
    _addressCache.clear();
    if (kDebugMode) {
      print('🗑️ Address cache cleared');
    }
  }

  /// Get cache size for debugging
  int get cacheSize => _addressCache.length;
}

/// Extension to provide easy address formatting
extension LatLngAddress on LatLng {
  /// Get formatted address for this coordinate
  Future<String> toAddress() async {
    return AddressService().getAddressFromCoordinates(this);
  }

  /// Get short address for this coordinate
  Future<String> toShortAddress() async {
    return AddressService().getShortAddress(this);
  }
}
