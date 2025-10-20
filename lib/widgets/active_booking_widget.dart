import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/booking_model.dart';
import '../main.dart' show AppColors;

class ActiveBookingWidget extends StatefulWidget {
  final Booking activeBooking;
  final VoidCallback onCancelBooking;

  const ActiveBookingWidget({
    super.key,
    required this.activeBooking,
    required this.onCancelBooking,
  });

  @override
  State<ActiveBookingWidget> createState() => _ActiveBookingWidgetState();
}

class _ActiveBookingWidgetState extends State<ActiveBookingWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _dotsController;
  int _dotCount = 0;
  bool _isExpanded = true;

  @override
  void initState() {
    super.initState();

    // Dots animation for "waiting" text
    _dotsController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();

    _dotsController.addListener(() {
      if (_dotsController.value < 0.33) {
        if (_dotCount != 1) setState(() => _dotCount = 1);
      } else if (_dotsController.value < 0.66) {
        if (_dotCount != 2) setState(() => _dotCount = 2);
      } else {
        if (_dotCount != 3) setState(() => _dotCount = 3);
      }
    });
  }

  @override
  void dispose() {
    _dotsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isPending = widget.activeBooking.status == BookingStatus.pending;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
            spreadRadius: -2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Modern Status Card (Collapsible Header)
          GestureDetector(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isPending
                      ? [
                          AppColors.primary.withValues(alpha: 0.08),
                          AppColors.primary.withValues(alpha: 0.03),
                        ]
                      : [
                          Colors.green.shade50,
                          Colors.green.shade50.withValues(alpha: 0.5),
                        ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  // Status Icon
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: isPending
                          ? AppColors.primary.withValues(alpha: 0.15)
                          : Colors.green.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isPending ? Icons.schedule : Icons.check_circle_outline,
                      color: isPending
                          ? AppColors.primary
                          : Colors.green.shade700,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Booking Request',
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade600,
                            letterSpacing: 0.5,
                          ),
                        ),
                        if (isPending)
                          Row(
                            children: [
                              Text(
                                'Waiting for driver',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black87,
                                ),
                              ),
                              Text(
                                '.' * _dotCount,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          )
                        else
                          Text(
                            _getStatusMessage(widget.activeBooking.status),
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Expand/Collapse Icon
                  Icon(
                    _isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),

          if (_isExpanded) ...[
            const SizedBox(height: 8),

            // Trip Details Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TRIP DETAILS',
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade600,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildModernLocationRow(
                      Icons.my_location,
                      'Pick-Up',
                      widget.activeBooking.pickupLocation.address,
                      AppColors.primary,
                    ),
                    const SizedBox(height: 8),
                    _buildModernLocationRow(
                      Icons.location_on,
                      'Destination',
                      widget.activeBooking.destination.address,
                      Colors.red.shade600,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 8),

            // Fare Summary Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary.withValues(alpha: 0.05),
                      AppColors.primary.withValues(alpha: 0.02),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.1),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'FARE BREAKDOWN',
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade600,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _buildFareRow(
                      'Base Fare',
                      widget.activeBooking.fare.baseFare,
                    ),
                    _buildFareRow(
                      'Distance',
                      widget.activeBooking.fare.distanceFare,
                    ),
                    if (widget.activeBooking.fare.passengerFare > 0)
                      _buildFareRow(
                        'Passenger',
                        widget.activeBooking.fare.passengerFare,
                      ),
                    if (widget.activeBooking.fare.timeMultiplier != 1.0)
                      _buildMultiplierRow(
                        'Time Multiplier',
                        widget.activeBooking.fare.timeMultiplier,
                      ),
                    const SizedBox(height: 4),
                    Container(height: 1, color: Colors.grey.shade300),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total Fare',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                        ),
                        Text(
                          widget.activeBooking.fare.formattedTotal,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Cancel Button
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: widget.onCancelBooking,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red.shade600,
                    side: BorderSide(color: Colors.red.shade300, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    'Cancel Booking',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildModernLocationRow(
    IconData icon,
    String label,
    String address,
    Color color,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
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
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                address,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFareRow(String label, double amount) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade700,
            ),
          ),
          Text(
            '₱${amount.toStringAsFixed(2)}',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMultiplierRow(String label, double multiplier) {
    final percentage = ((multiplier - 1.0) * 100).toStringAsFixed(0);
    final isIncrease = multiplier > 1.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade700,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isIncrease ? Colors.orange.shade50 : Colors.green.shade50,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${isIncrease ? '+' : ''}$percentage%',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isIncrease
                    ? Colors.orange.shade700
                    : Colors.green.shade700,
              ),
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
      case BookingStatus.pickedUp:
        return 'Passenger picked up';
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
