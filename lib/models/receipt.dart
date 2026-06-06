import 'package:cloud_firestore/cloud_firestore.dart';

class Receipt {
  final String id;
  final String vendor;
  final DateTime date;
  final double total;
  final List<String> items;
  final String imageUrl;
  final String userId;
  final DateTime createdAt;

  Receipt({
    required this.id,
    required this.vendor,
    required this.date,
    required this.total,
    required this.items,
    required this.imageUrl,
    required this.userId,
    required this.createdAt,
  });

  factory Receipt.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Receipt(
      id: doc.id,
      vendor: data['vendor'] as String,
      date: (data['date'] as Timestamp).toDate(),
      total: (data['total'] as num).toDouble(),
      items: List<String>.from(data['items'] as List),
      imageUrl: data['imageUrl'] as String,
      userId: data['userId'] as String,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'vendor': vendor,
      'date': Timestamp.fromDate(date),
      'total': total,
      'items': items,
      'imageUrl': imageUrl,
      'userId': userId,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
