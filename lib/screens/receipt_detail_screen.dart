import 'package:flutter/material.dart';
import '../models/receipt.dart';
import '../services/receipt_service.dart';

class ReceiptDetailScreen extends StatelessWidget {
  final Receipt receipt;
  const ReceiptDetailScreen({super.key, required this.receipt});

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  Future<void> _delete(BuildContext context) async {
    try {
      await ReceiptService().deleteReceipt(receipt.id);
      if (context.mounted) Navigator.of(context).pop();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(receipt.vendor.isEmpty ? 'Receipt' : receipt.vendor),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete receipt',
            onPressed: () => _delete(context),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Image thumbnail — shows network image when available, placeholder otherwise
              Container(
                height: 180,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: receipt.imageUrl.isEmpty
                    ? const Center(
                        child: Icon(
                          Icons.receipt_long,
                          size: 56,
                          color: Colors.black26,
                        ),
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          receipt.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Center(
                            child: Icon(
                              Icons.receipt_long,
                              size: 56,
                              color: Colors.black26,
                            ),
                          ),
                        ),
                      ),
              ),
              const SizedBox(height: 24),

              // Vendor / Date / Total
              _InfoCard(
                children: [
                  _InfoRow(
                    label: 'Vendor',
                    value: receipt.vendor.isEmpty ? 'Unknown' : receipt.vendor,
                  ),
                  const Divider(height: 1),
                  _InfoRow(label: 'Date', value: _formatDate(receipt.date)),
                  const Divider(height: 1),
                  _InfoRow(
                    label: 'Total',
                    value: 'Lei ${receipt.total.toStringAsFixed(2)}',
                    valueStyle: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: Colors.deepPurple,
                    ),
                  ),
                ],
              ),

              // Items list
              if (receipt.items.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text(
                  'Items (${receipt.items.length})',
                  style: Theme.of(context)
                      .textTheme
                      .labelLarge
                      ?.copyWith(color: Colors.black54),
                ),
                const SizedBox(height: 8),
                _InfoCard(
                  children: [
                    for (int i = 0; i < receipt.items.length; i++) ...[
                      if (i > 0) const Divider(height: 1),
                      _ItemRow(raw: receipt.items[i]),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Info card container ───────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final List<Widget> children;
  const _InfoCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(children: children),
    );
  }
}

// ── Labeled value row ─────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final TextStyle? valueStyle;
  const _InfoRow({required this.label, required this.value, this.valueStyle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey[500], fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: valueStyle ?? const TextStyle(fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Item row — splits trailing price from name when present ───────────────────

class _ItemRow extends StatelessWidget {
  final String raw;
  const _ItemRow({required this.raw});

  static final _trailingPrice = RegExp(r'^(.*?)\s+(\d{1,6}[.,]\d{2})\s*$');

  @override
  Widget build(BuildContext context) {
    final m = _trailingPrice.firstMatch(raw);
    final name = m?.group(1) ?? raw;
    final price = m?.group(2);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          const Icon(Icons.circle, size: 5, color: Colors.black26),
          const SizedBox(width: 10),
          Expanded(
            child: Text(name, style: const TextStyle(fontSize: 14)),
          ),
          if (price != null)
            Text(
              price,
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
        ],
      ),
    );
  }
}
