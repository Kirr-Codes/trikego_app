import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/transaction_model.dart';
import '../models/booking_model.dart';
import '../Services/booking_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Transaction> transactions = [];
  bool isLoading = true;
  String? errorMessage;
  final BookingService _bookingService = BookingService();

  @override
  void initState() {
    super.initState();
    _loadBookingHistory();
  }

  Future<void> _loadBookingHistory() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      final bookings = await _bookingService.getBookingHistory();
      final convertedTransactions = _convertBookingsToTransactions(bookings);
      
      setState(() {
        transactions = convertedTransactions;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to load booking history: ${e.toString()}';
        isLoading = false;
      });
    }
  }

  List<Transaction> _convertBookingsToTransactions(List<Booking> bookings) {
    return bookings.map((booking) {
      return Transaction(
        id: booking.id,
        timestamp: booking.createdAt,
        place: booking.pickupLocation.address,
        destination: booking.destination.address,
        price: booking.fare.totalFare,
        status: _convertBookingStatusToString(booking.status),
      );
    }).toList();
  }

  String _convertBookingStatusToString(BookingStatus status) {
    switch (status) {
      case BookingStatus.completed:
        return 'completed';
      case BookingStatus.cancelled:
        return 'cancelled';
      case BookingStatus.pending:
        return 'pending';
      default:
        return 'pending'; // Default to pending for any other statuses
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'History',
          style: GoogleFonts.inter(
            color: Colors.black,
            fontWeight: FontWeight.w700,
            fontSize: 24,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 18),
          // Transactions Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text(
              'Transactions',
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
            ),
          ),

          const SizedBox(height: 18),

          // Content based on state
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Error loading history',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              errorMessage!,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadBookingHistory,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (transactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No transactions yet',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadBookingHistory,
      child: _buildTransactionsList(),
    );
  }

  Widget _buildTransactionsList() {
    // Group transactions by date
    final Map<String, List<Transaction>> groupedTransactions = {};

    for (final transaction in transactions) {
      final dateKey = transaction.dateString;
      if (!groupedTransactions.containsKey(dateKey)) {
        groupedTransactions[dateKey] = [];
      }
      groupedTransactions[dateKey]!.add(transaction);
    }

    // Sort dates (Today first, then Yesterday, then others)
    final sortedDates = groupedTransactions.keys.toList()
      ..sort((a, b) {
        if (a == 'Today') return -1;
        if (b == 'Today') return 1;
        if (a == 'Yesterday') return -1;
        if (b == 'Yesterday') return 1;
        return b.compareTo(a); // Most recent first
      });

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      itemCount: sortedDates.length,
      itemBuilder: (context, index) {
        final date = sortedDates[index];
        final dateTransactions = groupedTransactions[date]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date Header
            Text(
              date,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: Colors.black,
              ),
            ),

            const SizedBox(height: 4),

            // Transactions for this date
            ...dateTransactions.map(
              (transaction) => _buildTransactionItem(transaction),
            ),

            const SizedBox(height: 24),
          ],
        );
      },
    );
  }

  Widget _buildTransactionItem(Transaction transaction) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Time row
              Text(
                transaction.timeString,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: Colors.black,
                ),
              ),

              const SizedBox(height: 4),

              // Place/Destination
              Text(
                transaction.routeDescription,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  color: Colors.black,
                ),
              ),

              const SizedBox(height: 6),

              // Price and Status row
              Row(
                children: [
                  // Price
                  Text(
                    transaction.priceString,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: Colors.black,
                    ),
                  ),

                  const Spacer(),

                  // Status
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _getStatusColor(transaction.status),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _getStatusText(transaction.status),
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Separator line
        Container(height: 1, color: Colors.grey.shade300),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      case 'pending':
        return 'Pending';
      default:
        return 'Unknown';
    }
  }
}
