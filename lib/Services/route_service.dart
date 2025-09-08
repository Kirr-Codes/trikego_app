import 'dart:convert';
import 'dart:math';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:google_polyline_algorithm/google_polyline_algorithm.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Model for route results
class RouteResult {
  final List<LatLng> points;
  final int distance; // in meters
  final int duration; // in seconds
  final String distanceText;
  final String durationText;
  final String? summary;

  const RouteResult({
    required this.points,
    required this.distance,
    required this.duration,
    required this.distanceText,
    required this.durationText,
    this.summary,
  });
}

/// Service for Google Directions API integration
class RouteService {
  static const String _baseUrl =
      'https://maps.googleapis.com/maps/api/directions';
  static String get _apiKey {
    final key = dotenv.env['GOOGLE_API_KEY'];
    if (key == null || key.isEmpty) {
      throw Exception('GOOGLE_API_KEY not found in environment variables');
    }
    return key;
  } // Replace with your actual API key

  /// Get route between two points optimized for driving (car/tricycle)
  static Future<RouteResult?> getRoute({
    required double startLatitude,
    required double startLongitude,
    required double endLatitude,
    required double endLongitude,
    bool avoidHighways = true,
    bool avoidTolls = true,
  }) async {
    try {
      final origin = '$startLatitude,$startLongitude';
      final destination = '$endLatitude,$endLongitude';

      String url =
          '$_baseUrl/json'
          '?origin=$origin'
          '&destination=$destination'
          '&mode=driving' // Use driving mode for car/tricycle
          '&key=$_apiKey';

      // Add avoidance parameters
      if (avoidHighways || avoidTolls) {
        final avoidances = <String>[];
        if (avoidHighways) avoidances.add('highways');
        if (avoidTolls) avoidances.add('tolls');
        url += '&avoid=${avoidances.join('|')}';
      }

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;

        if (data['status'] == 'OK') {
          final routes = data['routes'] as List<dynamic>;
          if (routes.isNotEmpty) {
            final route = routes.first as Map<String, dynamic>;
            return _parseRoute(route);
          }
        } else {
          _log(
            'Directions API error: ${data['status']} - ${data['error_message']}',
          );
          return null;
        }
      } else {
        _log('HTTP error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      _log('Error getting route: $e');
      return null;
    }

    return null;
  }

  /// Parse route data from Google Directions API response
  static RouteResult _parseRoute(Map<String, dynamic> route) {
    final legs = route['legs'] as List<dynamic>;
    final leg = legs.first as Map<String, dynamic>;

    final distance = leg['distance'] as Map<String, dynamic>;
    final duration = leg['duration'] as Map<String, dynamic>;

    // Decode polyline
    final overviewPolyline = route['overview_polyline'] as Map<String, dynamic>;
    final polylineString = overviewPolyline['points'] as String;
    final decodedPoints = decodePolyline(polylineString);

    // Convert to LatLng list
    final points = decodedPoints
        .map((point) => LatLng(point[0].toDouble(), point[1].toDouble()))
        .toList();

    return RouteResult(
      points: points,
      distance: distance['value'] as int,
      duration: duration['value'] as int,
      distanceText: distance['text'] as String,
      durationText: duration['text'] as String,
      summary: route['summary'] as String?,
    );
  }

  /// Get alternative routes between two points
  static Future<List<RouteResult>> getAlternativeRoutes({
    required double startLatitude,
    required double startLongitude,
    required double endLatitude,
    required double endLongitude,
    bool avoidHighways = false,
    bool avoidTolls = false,
  }) async {
    try {
      final origin = '$startLatitude,$startLongitude';
      final destination = '$endLatitude,$endLongitude';

      String url =
          '$_baseUrl/json'
          '?origin=$origin'
          '&destination=$destination'
          '&mode=driving'
          '&alternatives=true' // Request alternative routes
          '&key=$_apiKey';

      // Add avoidance parameters
      if (avoidHighways || avoidTolls) {
        final avoidances = <String>[];
        if (avoidHighways) avoidances.add('highways');
        if (avoidTolls) avoidances.add('tolls');
        url += '&avoid=${avoidances.join('|')}';
      }

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;

        if (data['status'] == 'OK') {
          final routes = data['routes'] as List<dynamic>;
          return routes
              .map((route) => _parseRoute(route as Map<String, dynamic>))
              .toList();
        } else {
          _log(
            'Directions API error: ${data['status']} - ${data['error_message']}',
          );
          return [];
        }
      } else {
        _log('HTTP error: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      _log('Error getting alternative routes: $e');
      return [];
    }
  }

  /// Calculate distance between two points (Haversine formula)
  static double calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371000; // Earth's radius in meters

    final lat1Rad = point1.latitude * (3.14159265359 / 180);
    final lat2Rad = point2.latitude * (3.14159265359 / 180);
    final deltaLatRad =
        (point2.latitude - point1.latitude) * (3.14159265359 / 180);
    final deltaLngRad =
        (point2.longitude - point1.longitude) * (3.14159265359 / 180);

    final a =
        sin(deltaLatRad / 2) * sin(deltaLatRad / 2) +
        cos(lat1Rad) *
            cos(lat2Rad) *
            sin(deltaLngRad / 2) *
            sin(deltaLngRad / 2);
    final c = 2 * asin(sqrt(a));

    return earthRadius * c;
  }

  /// Format distance for display
  static String formatDistance(double distanceInMeters) {
    if (distanceInMeters < 1000) {
      return '${distanceInMeters.round()} m';
    } else {
      final km = distanceInMeters / 1000;
      return '${km.toStringAsFixed(1)} km';
    }
  }

  /// Format duration for display
  static String formatDuration(int durationInSeconds) {
    final hours = durationInSeconds ~/ 3600;
    final minutes = (durationInSeconds % 3600) ~/ 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  static void _log(String message) {
    if (kDebugMode) {
      print('🛣️ RouteService: $message');
    }
  }
}
