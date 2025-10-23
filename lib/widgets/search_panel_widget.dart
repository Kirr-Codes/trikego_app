import 'package:flutter/material.dart';
import '../main.dart' show AppColors;
import '../Services/places_service.dart';
import '../Services/route_service.dart';
import '../models/fare_config_model.dart';
import '../models/booking_model.dart';
import 'location_field_widget.dart';
import 'booking_information_widget.dart';
import 'active_booking_widget.dart';
import 'driver_accepted_booking_widget.dart';

class SearchPanelWidget extends StatelessWidget {
  final String currentAddress;
  final String? serviceUnavailableReason;
  final bool isServiceAvailable;
  final PlaceSearchResult? selectedDestination;
  final RouteResult? currentRoute;
  final bool isCalculatingRoute;
  final bool showBookingInformation;
  final int passengerCount;
  final EnhancedFareCalculation? fareCalculation;
  final Booking? activeBooking;
  final VoidCallback onDestinationSearch;
  final VoidCallback onNext;
  final VoidCallback onClear;
  final VoidCallback onCloseBooking;
  final VoidCallback onDecreasePassengers;
  final VoidCallback onIncreasePassengers;
  final Future<void> Function() onCashPayment;
  final VoidCallback onConfirm;
  final VoidCallback? onCancelBooking;
  final String? selectedPaymentMethod;
  final bool isProcessing;

  const SearchPanelWidget({
    super.key,
    required this.currentAddress,
    this.serviceUnavailableReason,
    required this.isServiceAvailable,
    this.selectedDestination,
    this.currentRoute,
    required this.isCalculatingRoute,
    required this.showBookingInformation,
    required this.passengerCount,
    this.fareCalculation,
    this.activeBooking,
    required this.onDestinationSearch,
    required this.onNext,
    required this.onClear,
    required this.onCloseBooking,
    required this.onDecreasePassengers,
    required this.onIncreasePassengers,
    required this.onCashPayment,
    required this.onConfirm,
    this.onCancelBooking,
    this.selectedPaymentMethod,
    this.isProcessing = false,
  });

  @override
  Widget build(BuildContext context) {
    // If there's an active booking, show appropriate widget based on status
    if (activeBooking != null && activeBooking!.isActive) {
      // Show driver accepted UI when booking is accepted, driver en route, arrived, picked up, or in progress
      if (activeBooking!.status == BookingStatus.accepted || 
          activeBooking!.status == BookingStatus.driverEnRoute ||
          activeBooking!.status == BookingStatus.arrived ||
          activeBooking!.status == BookingStatus.pickedUp ||
          activeBooking!.status == BookingStatus.inProgress) {
        return DriverAcceptedBookingWidget(
          activeBooking: activeBooking!,
          onCancelBooking: onCancelBooking ?? () {},
        );
      }
      
      // Show regular active booking widget for other statuses (pending, etc.)
      return ActiveBookingWidget(
        activeBooking: activeBooking!,
        onCancelBooking: onCancelBooking ?? () {},
      );
    }
    
    // Otherwise, show the search panel
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!showBookingInformation) ...[
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
            LocationFieldWidget(
              hintText: 'Your location now',
              displayText: isServiceAvailable ? currentAddress : serviceUnavailableReason,
              icon: Icons.location_pin,
              iconColor: isServiceAvailable ? Colors.green : Colors.red,
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
            LocationFieldWidget(
              hintText: 'Enter your destination',
              displayText: selectedDestination?.name,
              icon: Icons.location_on_outlined,
              iconColor: Colors.redAccent,
              onTap: onDestinationSearch,
            ),
            const SizedBox(height: 12),
          ],
          if (showBookingInformation && selectedDestination != null && currentRoute != null) ...[
            // Booking Information UI
            BookingInformationWidget(
              currentAddress: currentAddress,
              destination: selectedDestination!,
              route: currentRoute!,
              passengerCount: passengerCount,
              fareCalculation: fareCalculation,
              onClose: onCloseBooking,
              onDecreasePassengers: onDecreasePassengers,
              onIncreasePassengers: onIncreasePassengers,
              onCashPayment: onCashPayment,
              onConfirm: onConfirm,
              selectedPaymentMethod: selectedPaymentMethod,
              isProcessing: isProcessing,
            ),
          ] else if (selectedDestination != null) ...[
            // Clear and Next buttons when destination is selected
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: onClear,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade300,
                      foregroundColor: Colors.grey.shade600,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Clear',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onNext,
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
                      'Next',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            // Choose destination button
            SizedBox(
              width: 300,
              child: ElevatedButton(
                onPressed: isCalculatingRoute ? null : onDestinationSearch,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 2,
                ),
                child: isCalculatingRoute
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
}
