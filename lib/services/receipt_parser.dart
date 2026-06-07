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
  // ── Romanian fiscal receipt patterns ─────────────────────────────────────────

  // Quantity line: "1.000 BUC x 4.79" — both x and X accepted
  static final _bucLine = RegExp(
    r'^(\d+[.,]\d+)\s+BUC\s+[xX]\s+(\d+[.,]\d+)',
    caseSensitive: false,
  );

  // ── Entry point ───────────────────────────────────────────────────────────────

  ParsedReceipt parse(String rawText) {
    final lines = rawText
        .split(RegExp(r'\r?\n'))
        .map((l) => l.trim())
        .toList();

    final date = _extractDate(rawText);
    final vendor = _extractVendor(lines);
    final total = _extractTotal(rawText);

    // Route to Romanian block parser when BUC lines are present; otherwise
    // use the generic noise-filter fallback.
    final isRomanian = lines.any(_bucLine.hasMatch);
    final items = isRomanian
        ? _extractItemsRomanian(lines)
        : _extractItems(lines, vendor: vendor, date: date);

    return ParsedReceipt(
      vendor: vendor,
      date: date,
      total: total,
      items: items,
    );
  }

  // ── Vendor ───────────────────────────────────────────────────────────────────

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

  // ── Total ─────────────────────────────────────────────────────────────────────

  String _extractTotal(String rawText) {
    // Normalize Romanian decimal format (265,00 → 265.00) before matching.
    // Only replaces comma when it sits between a digit and exactly 2 digits,
    // so list punctuation like "item 1, item 2" is left untouched.
    final text = rawText.replaceAllMapped(
      RegExp(r'(\d),(\d{2})(?!\d)'),
      (m) => '${m.group(1)}.${m.group(2)}',
    );

    final lines = text.split(RegExp(r'\r?\n'));
    final pricePattern = RegExp(r'(\d{1,6}\.\d{2})');

    // Primary: find the TOTAL keyword line, then collect all prices within
    // the next 5 lines and return the largest. Using a window avoids
    // grabbing the first price on a multi-line receipt layout (e.g. Bolt Food
    // prints the delivery fee on the line immediately after "Total").
    // \b prevents matching "SUBTOTAL" as a bare TOTAL.
    final totalKeyword = RegExp(
      r'\b(?:GRAND\s+TOTAL|TOTAL\s+DUE|AMOUNT\s+DUE|TOTAL\s+AMOUNT|'
      r'BALANCE\s+DUE|NET\s+TOTAL|TOTAL)\b',
      caseSensitive: false,
    );

    for (int i = 0; i < lines.length; i++) {
      if (!totalKeyword.hasMatch(lines[i])) continue;
      final window = lines.sublist(i, (i + 5).clamp(0, lines.length));
      double largest = 0;
      String largestStr = '';
      for (final line in window) {
        for (final m in pricePattern.allMatches(line)) {
          final val = double.tryParse(m.group(1)!) ?? 0;
          if (val > largest) {
            largest = val;
            largestStr = m.group(1)!;
          }
        }
      }
      if (largestStr.isNotEmpty) return largestStr;
    }

    // Fallback: largest price-like number in the document
    double largest = 0;
    String largestStr = '';
    for (final m in pricePattern.allMatches(text)) {
      final val = double.tryParse(m.group(1)!) ?? 0;
      if (val > largest) {
        largest = val;
        largestStr = m.group(1)!;
      }
    }
    return largestStr;
  }

  // ── Date ─────────────────────────────────────────────────────────────────────

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

  // ── Romanian item extraction ──────────────────────────────────────────────────
  //
  // Fixed 3-line block per item (BUC line always anchors position):
  //   i+0  "1.000 BUC x 4.79"   ← quantity anchor
  //   i+1  "SMANT.GATIT 20%"    ← product name
  //   i+2  "4.79 A"             ← total price + VAT category (A or B)

  List<String> _extractItemsRomanian(List<String> lines) {
    // Total-price line: digits followed immediately by A or B VAT category.
    final vatLine = RegExp(r'^\d+[.,]\d+\s*[AB]\s*$');

    // Names matching these are noise, not products.
    final skipName = RegExp(
      r'^\s*$|^\d+([.,]\d+)?\s*$|'
      r'\b(?:DISCOUNT|Reducere|Lei|RON)\b',
      caseSensitive: false,
    );

    bool isValidName(String s) =>
        s.isNotEmpty && !vatLine.hasMatch(s) && !skipName.hasMatch(s);

    final items = <String>[];

    for (int i = 0; i < lines.length; i++) {
      final bm = _bucLine.firstMatch(lines[i]);
      if (bm == null) continue;

      final next = (i + 1 < lines.length) ? lines[i + 1].trim() : '';

      String name;
      if (!vatLine.hasMatch(next)) {
        // Normal case: name is at i+1.
        name = next;
      } else {
        // OCR missed the name — the VAT line landed at i+1.
        // Fall back to i-1 (name printed before the BUC line).
        final prev = (i > 0) ? lines[i - 1].trim() : '';
        if (!isValidName(prev)) continue; // no usable name either side — skip
        name = prev;
      }

      if (!isValidName(name)) continue;

      // Quantity: "1.000" → 1, "0.500" → 0.5
      final qtyRaw = bm.group(1)!.replaceAll(',', '.');
      final qtyNum = double.tryParse(qtyRaw) ?? 1.0;
      final qty = qtyNum == qtyNum.truncateToDouble()
          ? qtyNum.toInt().toString()
          : qtyNum.toString();

      // Unit price from BUC line (comma → dot)
      final unitPrice = bm.group(2)!.replaceAll(',', '.');

      items.add('$name - $qty x $unitPrice lei');
    }

    return items.take(20).toList();
  }

  // ── Generic item extraction (non-Romanian fallback) ───────────────────────────

  List<String> _extractItems(
    List<String> lines, {
    required String vendor,
    required String date,
  }) {
    final separator = RegExp(r'^[\-=\*\_\~\#\.\s]{3,}$');

    // Lines with no alphabetic content (pure numbers, symbols, punctuation).
    // Includes Romanian diacritics so those count as alphabetic too.
    final noAlpha = RegExp(r'^[^a-zA-ZăâîșțĂÂÎȘȚ]+$');

    // Line is just a price/amount, optionally with a currency label.
    final priceOnly = RegExp(
      r'^(?:Lei|RON|lei|\$|€|£)?\s*\d{1,6}[.,]\d{0,2}\s*(?:Lei|RON|lei)?\s*$',
    );

    // Trailing price to strip from lines like "Flat White    12,50".
    final trailingPrice = RegExp(r'\s+\d{1,6}[.,]\d{2}\s*$');

    // Any line containing one of these words is administrative, not a product.
    final noiseKeywords = RegExp(
      r'\b(?:'
      // Accounting line types
      r'TVA|SUBTOTAL|TOTAL|CASH|CARD|DISCOUNT|'
      // Romanian quantity indicator (e.g. "1.000 BUC x 5,00")
      r'BUC|'
      // Receipt header / footer blocks
      r'BON\s+FISCAL|SUBSEMNATII|'
      // Address keywords
      r'TIMISOARA|TIMIȘOARA|JUDET|JUDEȚ|CALEA|'
      // Fiscal / registration identifiers
      r'COD|CIF|NR\.REG|ID\s+UNIC|EJTRZ|'
      // Currency labels (standalone)
      r'LEI|RON|'
      // Payment methods
      r'VISA|MASTERCARD|AMEX|DEBIT|CREDIT|'
      // Generic receipt noise
      r'CHANGE|BALANCE|RECEIPT|THANK|WELCOME|PHONE|TEL|FAX|WWW|HTTP|'
      r'MEMBER|POINTS|SAVINGS|COUPON|AUTH|APPROVAL|REF|'
      r'TRANS|INVOICE|ORDER|GUEST|TABLE|SERVER|CASHIER|OPERATOR|STORE|'
      r'QTY|PRICE|AMOUNT|DESCRIPTION|TAX|VAT|HST|GST|PST|TIP'
      r')\b',
      caseSensitive: false,
    );

    // Operator/time label lines: keyword immediately followed by a colon.
    final labelLine = RegExp(
      r'\b(?:DATA|ORA|CASA|CASIER)\s*:',
      caseSensitive: false,
    );

    // Romanian street (STR.) or number (NR.) address abbreviations.
    final addressLine = RegExp(r'\bSTR\.\s|\bNR\.\s*\d', caseSensitive: false);

    // Romanian company registration codes: J35/123/2020 or RO + 6+ digits.
    final fiscalCode = RegExp(r'\b(?:J\d+\/\d+\/\d+|RO\d{6,})\b');

    final items = <String>[];

    for (final line in lines) {
      if (line.length < 3) continue;
      if (line == vendor) continue;
      if (date.isNotEmpty && line.contains(date)) continue;
      if (separator.hasMatch(line)) continue;
      if (noAlpha.hasMatch(line)) continue;
      if (priceOnly.hasMatch(line)) continue;
      if (noiseKeywords.hasMatch(line)) continue;
      if (labelLine.hasMatch(line)) continue;
      if (addressLine.hasMatch(line)) continue;
      if (fiscalCode.hasMatch(line)) continue;

      final cleaned = line.replaceAll(trailingPrice, '').trim();
      if (cleaned.length >= 3) items.add(cleaned);
    }

    return items.take(20).toList();
  }
}
