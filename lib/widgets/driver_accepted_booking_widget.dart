import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/booking_model.dart';
import '../Services/route_service.dart';
import '../main.dart' show AppColors;

class DriverAcceptedBookingWidget extends StatefulWidget {
  final Booking activeBooking;
  final VoidCallback onCancelBooking;

  const DriverAcceptedBookingWidget({
    super.key,
    required this.activeBooking,
    required this.onCancelBooking,
  });

  @override
  State<DriverAcceptedBookingWidget> createState() => _DriverAcceptedBookingWidgetState();
}

class _DriverAcceptedBookingWidgetState extends State<DriverAcceptedBookingWidget> {
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    final isEnRoute = widget.activeBooking.status == BookingStatus.accepted;
    final isPickedUp = widget.activeBooking.status == BookingStatus.pickedUp;
    final isInProgress = widget.activeBooking.status == BookingStatus.inProgress;
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with Driver Info (Always Visible)
          GestureDetector(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  // Driver Avatar (Compact)
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary.withValues(alpha: 0.1),
                      border: Border.all(
                        color: AppColors.primary,
                        width: 2,
                      ),
                    ),
                    child: ClipOval(
                      child: widget.activeBooking.driver?.profilePictureUrl != null
                          ? Image.network(
                              widget.activeBooking.driver!.profilePictureUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Icon(
                                  Icons.person,
                                  size: 24,
                                  color: AppColors.primary,
                                );
                              },
                            )
                          : Icon(
                              Icons.person,
                              size: 24,
                              color: AppColors.primary,
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Driver Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.activeBooking.driver?.fullName ?? 'Driver',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Body: ${widget.activeBooking.driver?.bodyNum ?? 'N/A'}',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        Text(
                          'Plate: ${widget.activeBooking.driver?.plateNum ?? 'N/A'}',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // ETA Badge
                  _buildCompactETABadge(),
                  const SizedBox(width: 8),
                  // Expand/Collapse Icon
                  Icon(
                    _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: AppColors.primary,
                    size: 22,
                  ),
                ],
              ),
            ),
          ),

          // Expandable Content
          if (_isExpanded) ...[
            const SizedBox(height: 10),
            
            // Trip Details
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Trip Details',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // Show different locations based on status
                  if (isEnRoute) ...[
                    // Pick-Up location when driver is en route
                    _buildCompactLocationRow(
                      Icons.location_on,
                      'Pick-Up',
                      widget.activeBooking.pickupLocation.address,
                      AppColors.primary,
                    ),
                  ] else if (isPickedUp || isInProgress) ...[
                    // Destination when passenger is picked up or ride is in progress
                    _buildCompactLocationRow(
                      Icons.flag,
                      'Destination',
                      widget.activeBooking.destination.address,
                      Colors.red.shade600,
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 10),

            // Divider
            Container(
              height: 1,
              color: Colors.grey.shade200,
              margin: const EdgeInsets.symmetric(horizontal: 14),
            ),

            const SizedBox(height: 10),

            // Fare Summary (Compact)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Fare Summary',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildCompactFareRow('Base Fare', widget.activeBooking.fare.baseFare),
                  _buildCompactFareRow('Distance', widget.activeBooking.fare.distanceFare),
                  if (widget.activeBooking.fare.passengerFare > 0)
                    _buildCompactFareRow('Passenger', widget.activeBooking.fare.passengerFare),
                  if (widget.activeBooking.fare.timeMultiplier != 1.0)
                    _buildCompactMultiplierRow('Time', widget.activeBooking.fare.timeMultiplier),
                  const SizedBox(height: 8),
                  Container(height: 1, color: Colors.grey.shade200),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Fare',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                      ),
                      Text(
                        widget.activeBooking.fare.formattedTotal,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }

  Widget _buildCompactLocationRow(IconData icon, String label, String address, Color color) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                address,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.black,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCompactETABadge() {
    return FutureBuilder<String>(
      future: _calculateETA(),
      builder: (context, snapshot) {
        final etaText = snapshot.data ?? '...';
        
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.green.shade200, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.access_time,
                color: Colors.green.shade700,
                size: 12,
              ),
              const SizedBox(width: 4),
              Text(
                etaText,
                style: TextStyle(
                  fontSize: 11,
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
    if (widget.activeBooking.acceptedAt == null) return '...';
    
    try {
      final now = DateTime.now();
      
      // Priority 1: Use real-time driver location if available
      if (widget.activeBooking.driverLocation != null) {
        final driverLatLng = widget.activeBooking.driverLocation!.latLng;
        final pickupLatLng = widget.activeBooking.pickupLocation.latLng;
        
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
      final distanceKm = widget.activeBooking.route.distance / 1000.0;
      final estimatedTravelTimeMinutes = (distanceKm / 0.4).round(); // ~24 km/h
      final bufferMinutes = 3;
      final totalEstimatedMinutes = estimatedTravelTimeMinutes + bufferMinutes;
      
      final estimatedArrival = widget.activeBooking.acceptedAt!.add(
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

  Widget _buildCompactFareRow(String label, double amount) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w400,
              color: Colors.grey.shade600,
            ),
          ),
          Text(
            '₱${amount.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactMultiplierRow(String label, double multiplier) {
    final percentage = ((multiplier - 1.0) * 100).toStringAsFixed(0);
    final isIncrease = multiplier > 1.0;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w400,
              color: Colors.grey.shade600,
            ),
          ),
          Text(
            '${isIncrease ? '+' : ''}$percentage%',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isIncrease ? Colors.orange.shade700 : Colors.green.shade700,
            ),
          ),
        ],
      ),
    );
  }
}
