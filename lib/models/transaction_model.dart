class Transaction {
  final String id;
  final DateTime timestamp;
  final String place;
  final String destination;
  final double price;
  final String status;

  const Transaction({
    required this.id,
    required this.timestamp,
    required this.place,
    required this.destination,
    required this.price,
    required this.status,
  });

  String get timeString {
    final hour = timestamp.hour.toString().padLeft(2, '0');
    final minute = timestamp.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String get dateString {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final transactionDate = DateTime(
      timestamp.year,
      timestamp.month,
      timestamp.day,
    );

    if (transactionDate == today) {
      return 'Today';
    } else if (transactionDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }

  String get priceString => '₱${price.toStringAsFixed(2)}';

  String get routeDescription => '$place → $destination';
}

