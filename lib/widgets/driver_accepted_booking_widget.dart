import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/booking_model.dart';
import '../Services/route_service.dart';

class DriverAcceptedBookingWidget extends StatelessWidget {
  final Booking activeBooking;
  final VoidCallback onCancelBooking;

  const DriverAcceptedBookingWidget({
    super.key,
    required this.activeBooking,
    required this.onCancelBooking,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Driver Information Section
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Driver Information',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    // Driver Avatar
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.blue.shade100,
                        border: Border.all(
                          color: Colors.blue.shade200,
                          width: 2,
                        ),
                      ),
                      child: ClipOval(
                        child: activeBooking.driver?.profilePictureUrl != null
                            ? Image.network(
                                activeBooking.driver!.profilePictureUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Icon(
                                    Icons.person,
                                    size: 30,
                                    color: Colors.blue.shade600,
                                  );
                                },
                              )
                            : Icon(
                                Icons.person,
                                size: 30,
                                color: Colors.blue.shade600,
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Driver Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            activeBooking.driver?.fullName ?? 'Driver Name',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (activeBooking.driver?.bodyNum != null) ...[
                            Text(
                              'Body No: ${activeBooking.driver!.bodyNum}',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 2),
                          ],
                          if (activeBooking.driver?.phoneNum != null) ...[
                            Text(
                              'Contact: ${activeBooking.driver!.phoneNum}',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 2),
                          ],
                          if (activeBooking.driver?.plateNum != null) ...[
                            Text(
                              'Plate: ${activeBooking.driver!.plateNum}',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Trip Details Section
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with ETA
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'Trip Details',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                    _buildCompactETASection(),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Pick-Up Location
                _buildLocationSection(
                  'Pick-Up Location',
                  activeBooking.pickupLocation.address,
                  Colors.blue.shade600,
                ),
                
                const SizedBox(height: 12),
                
                // Destination
                _buildLocationSection(
                  'Destination',
                  activeBooking.destination.address,
                  Colors.blue.shade600,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationSection(String label, String address, Color iconColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: Colors.grey.shade500,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: iconColor,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.location_on,
                color: Colors.white,
                size: 12,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                address,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.black,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCompactETASection() {
    return FutureBuilder<String>(
      future: _calculateETA(),
      builder: (context, snapshot) {
        final etaText = snapshot.data ?? '...';
        
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green.shade200),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.access_time,
                color: Colors.green.shade600,
                size: 14,
              ),
              const SizedBox(width: 4),
              Text(
                'ETA: $etaText',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.green.shade700,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<String> _calculateETA() async {
    if (activeBooking.acceptedAt == null) return '...';
    
    try {
      final now = DateTime.now();
      
      // Priority 1: Use real-time driver location if available
      if (activeBooking.driverLocation != null) {
        final driverLatLng = activeBooking.driverLocation!.latLng;
        final pickupLatLng = activeBooking.pickupLocation.latLng;
        
        // Calculate direct distance from driver's current location to pickup
        final directDistance = RouteService.calculateDistance(driverLatLng, pickupLatLng);
        final distanceKm = directDistance / 1000.0;
        
        // Use real-time calculation
        final baseSpeedKmh = 22.0;
        final trafficFactor = 1.2;
        final effectiveSpeedKmh = baseSpeedKmh / trafficFactor;
        
        final travelTimeHours = distanceKm / effectiveSpeedKmh;
        final travelTimeMinutes = (travelTimeHours * 60).round();
        final preparationMinutes = 1; // Less prep time since driver is already moving
        final totalMinutes = travelTimeMinutes + preparationMinutes;
        
        final estimatedArrival = now.add(Duration(minutes: totalMinutes));
        return _formatTimeDifference(estimatedArrival.difference(now));
      }
      
      // Fallback: Use route distance if real-time location is not available
      final distanceKm = activeBooking.route.distance / 1000.0;
      final estimatedTravelTimeMinutes = (distanceKm / 0.4).round(); // ~24 km/h
      final bufferMinutes = 3;
      final totalEstimatedMinutes = estimatedTravelTimeMinutes + bufferMinutes;
      
      final estimatedArrival = activeBooking.acceptedAt!.add(
        Duration(minutes: totalEstimatedMinutes),
      );
      
      return _formatTimeDifference(estimatedArrival.difference(now));
      
    } catch (e) {
      print('Error calculating ETA: $e');
      return 'Soon';
    }
  }

  String _formatTimeDifference(Duration difference) {
    if (difference.isNegative) {
      return 'Soon';
    }
    
    final minutes = difference.inMinutes;
    if (minutes < 1) {
      return '<1 min';
    } else if (minutes <= 60) {
      return '${minutes}m';
    } else {
      final hours = (minutes / 60).floor();
      final remainingMinutes = minutes % 60;
      return '${hours}h ${remainingMinutes}m';
    }
  }
}
