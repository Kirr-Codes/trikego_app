import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/terminal_model.dart';
import '../Services/route_service.dart';

/// Service for managing terminal-related operations
class TerminalService {
  static final TerminalService _instance = TerminalService._internal();
  factory TerminalService() => _instance;
  TerminalService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Collection name
  static const String _terminalsCollection = 'terminals';

  /// Get all active terminals
  Future<List<Terminal>> getActiveTerminals() async {
    try {
      final snapshot = await _firestore
          .collection(_terminalsCollection)
          .where('isActive', isEqualTo: true)
          .get();

      return snapshot.docs
          .map((doc) => Terminal.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error fetching terminals: $e');
      return [];
    }
  }

  /// Get the nearest terminal to a given location
  Future<Terminal?> getNearestTerminal(LatLng location) async {
    try {
      final terminals = await getActiveTerminals();
      if (terminals.isEmpty) return null;

      Terminal? nearestTerminal;
      double shortestDistance = double.infinity;

      for (final terminal in terminals) {
        final distance = RouteService.calculateDistance(
          location,
          terminal.latLng,
        );

        if (distance < shortestDistance) {
          shortestDistance = distance;
          nearestTerminal = terminal;
        }
      }

      return nearestTerminal;
    } catch (e) {
      print('Error finding nearest terminal: $e');
      return null;
    }
  }

  /// Calculate distance from terminal to pickup location
  Future<double?> getDistanceFromTerminalToPickup({
    required LatLng pickupLocation,
  }) async {
    try {
      final nearestTerminal = await getNearestTerminal(pickupLocation);
      if (nearestTerminal == null) return null;

      final distance = RouteService.calculateDistance(
        nearestTerminal.latLng,
        pickupLocation,
      );

      return distance; // Returns distance in meters
    } catch (e) {
      print('Error calculating terminal to pickup distance: $e');
      return null;
    }
  }
}
