import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/booking_model.dart';

class ActiveBookingWidget extends StatelessWidget {
  final Booking activeBooking;
  final VoidCallback onCancelBooking;

  const ActiveBookingWidget({
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
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              'Active Booking',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
            ),
          ),

          // Status message
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              _getStatusMessage(activeBooking.status),
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: Colors.black87,
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Pick-up Location
          _buildLocationSection(
            'Pick-Up Location',
            activeBooking.pickupLocation.address,
          ),

          const SizedBox(height: 8),

          // Destination
          _buildLocationSection(
            'Destination',
            activeBooking.destination.address,
          ),

          const SizedBox(height: 12),

          // Divider
          Container(
            height: 1,
            color: Colors.grey.shade300,
            margin: const EdgeInsets.symmetric(horizontal: 16),
          ),

          const SizedBox(height: 8),

          // Fare Summary
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Fare Summary:',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                _buildFareRow('Base Fare:', activeBooking.fare.baseFare),
                _buildFareRow('Distance:', activeBooking.fare.distanceFare),
                _buildFareRow(
                  'TOTAL FARE:',
                  activeBooking.fare.totalFare,
                  isTotal: true,
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Cancel Button
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Center(
              child: SizedBox(
                width: 180,
                child: ElevatedButton(
                  onPressed: onCancelBooking,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade400,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Cancel Booking',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationSection(String label, String address) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w400,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Icon(Icons.location_on, color: Colors.blue.shade600, size: 14),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  address,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: Colors.black,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFareRow(String label, double amount, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: isTotal ? FontWeight.w600 : FontWeight.w400,
              color: isTotal ? Colors.black : Colors.grey.shade600,
            ),
          ),
          Text(
            isTotal
                ? '₱${amount.toStringAsFixed(2)}'
                : '₱${amount.toStringAsFixed(2)}',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: isTotal ? FontWeight.w600 : FontWeight.w400,
              color: isTotal ? Colors.black : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusMessage(BookingStatus status) {
    switch (status) {
      case BookingStatus.pending:
        return 'Waiting for driver confirmation';
      case BookingStatus.accepted:
        return 'Driver accepted your booking';
      case BookingStatus.driverEnRoute:
        return 'Driver is on the way';
      case BookingStatus.arrived:
        return 'Driver has arrived';
      case BookingStatus.inProgress:
        return 'Ride in progress';
      case BookingStatus.completed:
        return 'Ride completed';
      case BookingStatus.cancelled:
        return 'Booking cancelled';
      case BookingStatus.expired:
        return 'Booking expired';
    }
  }
}
