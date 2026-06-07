import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/receipt.dart';

class ReceiptService {
  final _db = FirebaseFirestore.instance;

  Stream<List<Receipt>> receiptsStream(String userId) {
    return _db
        .collection('receipts')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(Receipt.fromFirestore).toList());
  }

  Future<void> saveReceipt({
    required String vendor,
    required String dateStr,
    required String totalStr,
    required List<String> items,
    required String userId,
  }) async {
    final now = DateTime.now();
    final receipt = Receipt(
      id: '',
      vendor: vendor.trim().isEmpty ? 'Unknown' : vendor.trim(),
      date: _parseDate(dateStr),
      total: double.tryParse(totalStr.trim().replaceAll(',', '.')) ?? 0.0,
      items: items,
      imageUrl: '', // TODO: upload to Firebase Storage in a future phase
      userId: userId,
      createdAt: now,
    );
    await _db.collection('receipts').add(receipt.toMap());
  }

  // ── Date string → DateTime ───────────────────────────────────────────────

  DateTime _parseDate(String dateStr) {
    final s = dateStr.trim();
    if (s.isEmpty) return DateTime.now();

    // ISO 8601: 2024-01-12
    final iso = DateTime.tryParse(s);
    if (iso != null) return iso;

    // MM/DD/YYYY or DD/MM/YYYY
    final slash =
        RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{2,4})$').firstMatch(s);
    if (slash != null) {
      final a = int.parse(slash.group(1)!);
      final b = int.parse(slash.group(2)!);
      var year = int.parse(slash.group(3)!);
      if (year < 100) year += 2000;
      // Try MM/DD first (US), then DD/MM (EU)
      try {
        return DateTime(year, a, b);
      } catch (_) {}
      try {
        return DateTime(year, b, a);
      } catch (_) {}
    }

    // DD-MM-YYYY
    final dash =
        RegExp(r'^(\d{1,2})-(\d{1,2})-(\d{2,4})$').firstMatch(s);
    if (dash != null) {
      final day = int.parse(dash.group(1)!);
      final month = int.parse(dash.group(2)!);
      var year = int.parse(dash.group(3)!);
      if (year < 100) year += 2000;
      try {
        return DateTime(year, month, day);
      } catch (_) {}
    }

    // DD.MM.YYYY
    final dot =
        RegExp(r'^(\d{1,2})\.(\d{1,2})\.(\d{4})$').firstMatch(s);
    if (dot != null) {
      try {
        return DateTime(
          int.parse(dot.group(3)!),
          int.parse(dot.group(2)!),
          int.parse(dot.group(1)!),
        );
      } catch (_) {}
    }

    const months = {
      'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
      'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
    };

    // Jan 12, 2024 / January 12 2024
    final mdy = RegExp(
      r'([A-Za-z]{3})[a-z]*\.?\s+(\d{1,2}),?\s+(\d{4})',
    ).firstMatch(s);
    if (mdy != null) {
      final month = months[mdy.group(1)!.toLowerCase()];
      if (month != null) {
        try {
          return DateTime(
            int.parse(mdy.group(3)!),
            month,
            int.parse(mdy.group(2)!),
          );
        } catch (_) {}
      }
    }

    // 12 Jan 2024 / 12 January 2024
    final dmy = RegExp(
      r'(\d{1,2})\s+([A-Za-z]{3})[a-z]*\.?\s+(\d{4})',
    ).firstMatch(s);
    if (dmy != null) {
      final month = months[dmy.group(2)!.toLowerCase()];
      if (month != null) {
        try {
          return DateTime(
            int.parse(dmy.group(3)!),
            month,
            int.parse(dmy.group(1)!),
          );
        } catch (_) {}
      }
    }

    return DateTime.now();
  }
}
