class ParsedReceipt {
  final String vendor;
  final String date;
  final String total;
  final List<String> items;

  const ParsedReceipt({
    required this.vendor,
    required this.date,
    required this.total,
    required this.items,
  });
}

class ReceiptParser {
  ParsedReceipt parse(String rawText) {
    final lines = rawText
        .split(RegExp(r'\r?\n'))
        .map((l) => l.trim())
        .toList();

    final date = _extractDate(rawText);
    final vendor = _extractVendor(lines);
    final total = _extractTotal(rawText);
    final items = _extractItems(lines, vendor: vendor, date: date);

    return ParsedReceipt(
      vendor: vendor,
      date: date,
      total: total,
      items: items,
    );
  }

  // ── Vendor ──────────────────────────────────────────────────────────────────

  String _extractVendor(List<String> lines) {
    final priceOrDigit = RegExp(r'^[\d\s\$\.,\-\+\(\)\/]+$');
    final separator = RegExp(r'^[\-=\*\_\~\#\.\s]{2,}$');

    for (final line in lines) {
      if (line.length < 2) continue;
      if (priceOrDigit.hasMatch(line)) continue;
      if (separator.hasMatch(line)) continue;
      return line;
    }
    return '';
  }

  // ── Total ───────────────────────────────────────────────────────────────────

  String _extractTotal(String rawText) {
    // Primary: look for TOTAL / AMOUNT DUE keyword followed by a price
    final keyword = RegExp(
      r'(?:GRAND\s+TOTAL|TOTAL\s+DUE|AMOUNT\s+DUE|TOTAL\s+AMOUNT|'
      r'BALANCE\s+DUE|NET\s+TOTAL|TOTAL)[:\s]*\$?\s*(\d{1,6}[.,]\d{2})',
      caseSensitive: false,
      multiLine: true,
    );
    final kMatch = keyword.firstMatch(rawText);
    if (kMatch != null) {
      return kMatch.group(1)!.replaceAll(',', '.');
    }

    // Fallback: largest price-like number in the document
    final price = RegExp(r'\$?\s*(\d{1,6}[.,]\d{2})');
    double largest = 0;
    String largestStr = '';
    for (final m in price.allMatches(rawText)) {
      final str = m.group(1)!.replaceAll(',', '.');
      final val = double.tryParse(str) ?? 0;
      if (val > largest) {
        largest = val;
        largestStr = str;
      }
    }
    return largestStr;
  }

  // ── Date ────────────────────────────────────────────────────────────────────

  String _extractDate(String rawText) {
    final patterns = [
      // ISO: 2024-01-12
      RegExp(r'\b\d{4}-\d{2}-\d{2}\b'),
      // DD/MM/YYYY or MM/DD/YYYY
      RegExp(r'\b\d{1,2}/\d{1,2}/\d{2,4}\b'),
      // DD-MM-YY(YY) — only when not caught by ISO
      RegExp(r'\b\d{1,2}-\d{1,2}-\d{2,4}\b'),
      // DD.MM.YYYY
      RegExp(r'\b\d{1,2}\.\d{1,2}\.\d{4}\b'),
      // Jan 12, 2024 / January 12 2024
      RegExp(
        r'\b(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\.?\s+\d{1,2},?\s+\d{4}\b',
        caseSensitive: false,
      ),
      // 12 Jan 2024 / 12 January 2024
      RegExp(
        r'\b\d{1,2}\s+(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\.?\s+\d{4}\b',
        caseSensitive: false,
      ),
    ];

    for (final pattern in patterns) {
      final m = pattern.firstMatch(rawText);
      if (m != null) return m.group(0)!;
    }
    return '';
  }

  // ── Items ───────────────────────────────────────────────────────────────────

  List<String> _extractItems(
    List<String> lines, {
    required String vendor,
    required String date,
  }) {
    final skipKeywords = RegExp(
      r'^(?:TOTAL|SUB[\s\-]?TOTAL|TAX|HST|GST|VAT|PST|TIP|CASH|CHANGE|'
      r'BALANCE|RECEIPT|THANK|WELCOME|PHONE|TEL|FAX|WWW|HTTP|VISA|MASTER|'
      r'AMEX|CARD|DEBIT|CREDIT|MEMBER|POINTS|SAVINGS|DISCOUNT|COUPON|'
      r'AUTH|APPROVAL|REF|TRANS|INVOICE|ORDER|GUEST|TABLE|SERVER|CASHIER|'
      r'OPERATOR|STORE|DATE|TIME|QTY|PRICE|AMOUNT|DESCRIPTION|ITEM)[:\s#\d]*$',
      caseSensitive: false,
    );
    final priceOnly = RegExp(r'^[\$\€\£]?\s*\d{1,6}[.,]?\d{0,2}\s*$');
    final separator = RegExp(r'^[\-=\*\_\~\#\.\s]{3,}$');
    final noAlpha = RegExp(r'^[^a-zA-Z]+$');
    final trailingPrice = RegExp(r'\s+\$?\d{1,6}[.,]\d{2}\s*$');

    final items = <String>[];

    for (final line in lines) {
      if (line.length < 3) continue;
      if (line == vendor) continue;
      if (date.isNotEmpty && line.contains(date)) continue;
      if (separator.hasMatch(line)) continue;
      if (noAlpha.hasMatch(line)) continue;
      if (priceOnly.hasMatch(line)) continue;
      if (skipKeywords.hasMatch(line)) continue;

      // Strip trailing price from lines like "Flat White    3.50"
      final cleaned = line.replaceAll(trailingPrice, '').trim();
      if (cleaned.length >= 3) items.add(cleaned);
    }

    return items.take(20).toList();
  }
}
