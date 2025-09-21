import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/transaction_model.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Transaction> transactions = TransactionData.getSampleTransactions();

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

          // Transactions List
          Expanded(child: _buildTransactionsList()),
        ],
      ),
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

            const SizedBox(height: 16),

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
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Colors.black,
                ),
              ),

              const SizedBox(height: 4),

              // Place/Destination and Price row
              Row(
                children: [
                  // Place/Destination
                  Expanded(
                    child: Text(
                      transaction.routeDescription,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        color: Colors.black,
                      ),
                    ),
                  ),

                  // Price
                  Text(
                    transaction.priceString,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: Colors.black,
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
}
