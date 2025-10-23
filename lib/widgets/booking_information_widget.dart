import 'package:flutter/material.dart';
import '../main.dart' show AppColors;
import '../Services/places_service.dart';
import '../Services/route_service.dart';
import '../models/fare_config_model.dart';

class BookingInformationWidget extends StatelessWidget {
  final String currentAddress;
  final PlaceSearchResult destination;
  final RouteResult route;
  final int passengerCount;
  final VoidCallback onClose;
  final VoidCallback onDecreasePassengers;
  final VoidCallback onIncreasePassengers;
  final Future<void> Function() onCashPayment;
  final VoidCallback onConfirm;
  final EnhancedFareCalculation? fareCalculation;
  final String? selectedPaymentMethod;
  final bool isProcessing;

  const BookingInformationWidget({
    super.key,
    required this.currentAddress,
    required this.destination,
    required this.route,
    required this.passengerCount,
    required this.onClose,
    required this.onDecreasePassengers,
    required this.onIncreasePassengers,
    required this.onCashPayment,
    required this.onConfirm,
    this.fareCalculation,
    this.selectedPaymentMethod,
    this.isProcessing = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Booking Information Title with X button
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Booking Information',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
            ),
            GestureDetector(
              onTap: onClose,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.close, color: Colors.grey.shade600, size: 16),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Pick-Up Location
        const Text(
          'Pick-Up Location',
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            Icon(Icons.location_pin, color: AppColors.primary, size: 14),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                currentAddress,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.black,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Separator line
        Container(height: 1, color: Colors.grey.shade300),
        const SizedBox(height: 8),

        // Destination
        const Text(
          'Destination',
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            Icon(Icons.location_pin, color: AppColors.primary, size: 14),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                destination.name,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.black,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Ride Summary Card
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Distance
                  Expanded(
                    child: Column(
                      children: [
                        const Text(
                          'Distance',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          route.distanceText,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Estimated Time
                  Expanded(
                    child: Column(
                      children: [
                        const Text(
                          'Est. Time',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          route.durationText,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Passengers
                  Expanded(
                    child: Column(
                      children: [
                        const Text(
                          'Passengers',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            GestureDetector(
                              onTap: onDecreasePassengers,
                              child: Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.remove,
                                  color: Colors.white,
                                  size: 14,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              '$passengerCount',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(width: 10),
                            GestureDetector(
                              onTap: onIncreasePassengers,
                              child: Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.add,
                                  color: Colors.white,
                                  size: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Fare Summary
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Fare Summary',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              _buildFareRow('Base Fare', fareCalculation?.baseFare ?? 0.0),
              _buildFareRow('Distance Fare', (fareCalculation?.driverToPickupFare ?? 0.0) + (fareCalculation?.pickupToDestinationFare ?? 0.0)),
              if ((fareCalculation?.passengerFare ?? 0.0) > 0)
                _buildFareRow('Passenger Fare', fareCalculation!.passengerFare),
              if ((fareCalculation?.timeMultiplier ?? 1.0) != 1.0)
                _buildMultiplierRow('Time Multiplier', fareCalculation!.timeMultiplier),
              const SizedBox(height: 4),
              Container(height: 1, color: Colors.grey.shade300),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total Fare',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.black,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    fareCalculation?.formattedTotal ?? '₱0.00',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Payment and Confirm buttons
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () => onCashPayment(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: selectedPaymentMethod != null 
                      ? AppColors.primary.withOpacity(0.1)
                      : Colors.grey.shade200,
                  foregroundColor: selectedPaymentMethod != null 
                      ? AppColors.primary
                      : Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      selectedPaymentMethod == 'cash' 
                          ? Icons.money
                          : selectedPaymentMethod == 'online'
                              ? Icons.account_balance_wallet
                              : Icons.account_balance_wallet,
                      color: selectedPaymentMethod != null 
                          ? AppColors.primary
                          : Colors.grey.shade600,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      selectedPaymentMethod == 'cash'
                          ? 'Cash'
                          : selectedPaymentMethod == 'online'
                              ? 'Online Payment'
                              : 'Payment',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton(
                onPressed: isProcessing ? null : onConfirm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                  disabledBackgroundColor: Colors.grey.shade400,
                ),
                child: isProcessing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Confirm',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFareRow(String label, double amount) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: Colors.grey,
              fontWeight: FontWeight.w400,
            ),
          ),
          Text(
            '₱${amount.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 10,
              color: Colors.black87,
              fontWeight: FontWeight.w500,
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
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: Colors.grey,
              fontWeight: FontWeight.w400,
            ),
          ),
          Text(
            '${isIncrease ? '+' : ''}$percentage%',
            style: TextStyle(
              fontSize: 10,
              color: isIncrease ? Colors.orange.shade700 : Colors.green.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
