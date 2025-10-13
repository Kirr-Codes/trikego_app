import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';

/// Model for place search results
class PlaceSearchResult {
  final String placeId;
  final String name;
  final String formattedAddress;
  final double latitude;
  final double longitude;
  final String? photoReference;
  final double? rating;
  final String? vicinity;

  const PlaceSearchResult({
    required this.placeId,
    required this.name,
    required this.formattedAddress,
    required this.latitude,
    required this.longitude,
    this.photoReference,
    this.rating,
    this.vicinity,
  });

  factory PlaceSearchResult.fromJson(Map<String, dynamic> json) {
    final geometry = json['geometry'] as Map<String, dynamic>;
    final location = geometry['location'] as Map<String, dynamic>;

    return PlaceSearchResult(
      placeId: json['place_id'] as String,
      name: json['name'] as String,
      formattedAddress: json['formatted_address'] as String? ?? '',
      latitude: (location['lat'] as num).toDouble(),
      longitude: (location['lng'] as num).toDouble(),
      photoReference:
          json['photos'] != null && (json['photos'] as List).isNotEmpty
          ? (json['photos'] as List).first['photo_reference'] as String?
          : null,
      rating: json['rating'] != null
          ? (json['rating'] as num).toDouble()
          : null,
      vicinity: json['vicinity'] as String?,
    );
  }
}

/// Model for place details
class PlaceDetails {
  final String placeId;
  final String name;
  final String formattedAddress;
  final double latitude;
  final double longitude;
  final String? phoneNumber;
  final String? website;
  final List<String> types;
  final double? rating;
  final int? userRatingsTotal;

  const PlaceDetails({
    required this.placeId,
    required this.name,
    required this.formattedAddress,
    required this.latitude,
    required this.longitude,
    this.phoneNumber,
    this.website,
    required this.types,
    this.rating,
    this.userRatingsTotal,
  });

  factory PlaceDetails.fromJson(Map<String, dynamic> json) {
    final geometry = json['geometry'] as Map<String, dynamic>;
    final location = geometry['location'] as Map<String, dynamic>;

    return PlaceDetails(
      placeId: json['place_id'] as String,
      name: json['name'] as String,
      formattedAddress: json['formatted_address'] as String? ?? '',
      latitude: (location['lat'] as num).toDouble(),
      longitude: (location['lng'] as num).toDouble(),
      phoneNumber: json['formatted_phone_number'] as String?,
      website: json['website'] as String?,
      types: (json['types'] as List<dynamic>?)?.cast<String>() ?? [],
      rating: json['rating'] != null
          ? (json['rating'] as num).toDouble()
          : null,
      userRatingsTotal: json['user_ratings_total'] as int?,
    );
  }
}

/// Service for Google Places API integration
class PlacesService {
  static const String _baseUrl = 'https://maps.googleapis.com/maps/api/place';
  static String get _apiKey {
    final key = dotenv.env['GOOGLE_API_KEY'];
    if (key == null || key.isEmpty) {
      throw Exception('GOOGLE_API_KEY not found in environment variables');
    }
    return key;
  }
  // Replace with your actual API key

  /// Search for places using text query
  static Future<List<PlaceSearchResult>> searchPlaces({
    required String query,
    required double latitude,
    required double longitude,
    int radius = 20000, // 20km radius default
    String? region, // e.g., 'ph' to bias to a country
  }) async {
    try {
      final url = Uri.parse(
        '$_baseUrl/textsearch/json'
        '?query=${Uri.encodeComponent(query)}'
        '&location=$latitude,$longitude'
        '&radius=$radius'
        '${region != null ? '&region=$region' : ''}'
        '&key=$_apiKey',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;

        if (data['status'] == 'OK') {
          final results = data['results'] as List<dynamic>;
          // Map to models
          final places = results
              .map((json) =>
                  PlaceSearchResult.fromJson(json as Map<String, dynamic>))
              .toList();

          // Filter to within radius and sort by distance ascending (local first)
          final filteredAndSorted = places
              .where((p) => _distanceBetweenMeters(
                        latitude,
                        longitude,
                        p.latitude,
                        p.longitude,
                      ) <=
                      radius)
              .toList()
            ..sort((a, b) {
              final da = _distanceBetweenMeters(
                latitude,
                longitude,
                a.latitude,
                a.longitude,
              );
              final db = _distanceBetweenMeters(
                latitude,
                longitude,
                b.latitude,
                b.longitude,
              );
              return da.compareTo(db);
            });

          return filteredAndSorted;
        } else {
          _log(
            'Places API error: ${data['status']} - ${data['error_message']}',
          );
          return [];
        }
      } else {
        _log('HTTP error: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      _log('Error searching places: $e');
      return [];
    }
  }

  /// Get place details by place ID
  static Future<PlaceDetails?> getPlaceDetails(String placeId) async {
    try {
      final url = Uri.parse(
        '$_baseUrl/details/json'
        '?place_id=$placeId'
        '&fields=place_id,name,formatted_address,geometry,formatted_phone_number,website,types,rating,user_ratings_total'
        '&key=$_apiKey',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;

        if (data['status'] == 'OK') {
          final result = data['result'] as Map<String, dynamic>;
          return PlaceDetails.fromJson(result);
        } else {
          _log(
            'Place details API error: ${data['status']} - ${data['error_message']}',
          );
          return null;
        }
      } else {
        _log('HTTP error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      _log('Error getting place details: $e');
      return null;
    }
  }

  /// Search for nearby places
  static Future<List<PlaceSearchResult>> searchNearbyPlaces({
    required double latitude,
    required double longitude,
    String type = 'establishment',
    int radius = 5000, // 5km radius
  }) async {
    try {
      final url = Uri.parse(
        '$_baseUrl/nearbysearch/json'
        '?location=$latitude,$longitude'
        '&radius=$radius'
        '&type=$type'
        '&key=$_apiKey',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;

        if (data['status'] == 'OK') {
          final results = data['results'] as List<dynamic>;
          return results
              .map(
                (json) =>
                    PlaceSearchResult.fromJson(json as Map<String, dynamic>),
              )
              .toList();
        } else {
          _log(
            'Nearby places API error: ${data['status']} - ${data['error_message']}',
          );
          return [];
        }
      } else {
        _log('HTTP error: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      _log('Error searching nearby places: $e');
      return [];
    }
  }

  static void _log(String message) {
    if (kDebugMode) {
      print('🗺️ PlacesService: $message');
    }
  }

  /// Haversine distance in meters between two coordinates
  static double _distanceBetweenMeters(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadiusMeters = 6371000; // mean Earth radius
    final double dLat = _degToRad(lat2 - lat1);
    final double dLon = _degToRad(lon2 - lon1);
    final double a =
        (math.sin(dLat / 2) * math.sin(dLat / 2)) +
            math.cos(_degToRad(lat1)) *
                math.cos(_degToRad(lat2)) *
                (math.sin(dLon / 2) * math.sin(dLon / 2));
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusMeters * c;
  }

  static double _degToRad(double deg) => deg * (3.141592653589793 / 180.0);
}
