import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../services/receipt_parser.dart';
import '../services/receipt_service.dart';

class EditConfirmScreen extends StatefulWidget {
  final String imagePath;
  final Uint8List imageBytes;
  final String rawOcrText;

  const EditConfirmScreen({
    super.key,
    required this.imagePath,
    required this.imageBytes,
    required this.rawOcrText,
  });

  @override
  State<EditConfirmScreen> createState() => _EditConfirmScreenState();
}

class _EditConfirmScreenState extends State<EditConfirmScreen> {
  final _vendorController = TextEditingController();
  final _dateController = TextEditingController();
  final _totalController = TextEditingController();

  List<String> _parsedItems = [];
  bool _isSaving = false;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    final parsed = ReceiptParser().parse(widget.rawOcrText);
    _vendorController.text = parsed.vendor;
    _dateController.text = parsed.date;
    _totalController.text = parsed.total;
    _parsedItems = parsed.items;
  }

  @override
  void dispose() {
    _vendorController.dispose();
    _dateController.dispose();
    _totalController.dispose();
    super.dispose();
  }

  Future<void> _saveReceipt() async {
    setState(() {
      _isSaving = true;
      _saveError = null;
    });
    try {
      final userId = FirebaseAuth.instance.currentUser!.uid;
      await ReceiptService().saveReceipt(
        vendor: _vendorController.text,
        dateStr: _dateController.text,
        totalStr: _totalController.text,
        items: _parsedItems,
        userId: userId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Receipt saved!')),
      );
      Navigator.popUntil(context, (route) => route.isFirst);
    } catch (e) {
      setState(() {
        _isSaving = false;
        _saveError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Edit & Confirm'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: kIsWeb
                  ? Image.memory(widget.imageBytes,
                      height: 180, fit: BoxFit.cover)
                  : Image.file(File(widget.imagePath),
                      height: 180, fit: BoxFit.cover),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _vendorController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Vendor',
                prefixIcon: Icon(Icons.store_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _dateController,
              decoration: const InputDecoration(
                labelText: 'Date',
                prefixIcon: Icon(Icons.calendar_today_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _totalController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Total',
                prefixText: 'Lei ',
                border: OutlineInputBorder(),
              ),
            ),
            if (_parsedItems.isNotEmpty) ...[
              const SizedBox(height: 16),
              _ItemsPreview(items: _parsedItems),
            ],
            const SizedBox(height: 24),
            _RawOcrTextBox(text: widget.rawOcrText),
            const SizedBox(height: 24),
            if (_saveError != null) ...[
              Text(
                _saveError!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
            ],
            SafeArea(
              top: false,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveReceipt,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Save Receipt'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Items preview ────────────────────────────────────────────────────────────

class _ItemsPreview extends StatelessWidget {
  final List<String> items;
  const _ItemsPreview({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Detected items (${items.length})',
            style: Theme.of(context)
                .textTheme
                .labelLarge
                ?.copyWith(color: Colors.black54),
          ),
          const SizedBox(height: 8),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  const Icon(Icons.circle, size: 6, color: Colors.black38),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(item,
                        style: const TextStyle(fontSize: 13)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Raw OCR text (collapsible) ───────────────────────────────────────────────

class _RawOcrTextBox extends StatefulWidget {
  final String text;
  const _RawOcrTextBox({required this.text});

  @override
  State<_RawOcrTextBox> createState() => _RawOcrTextBoxState();
}

class _RawOcrTextBoxState extends State<_RawOcrTextBox> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Row(
            children: [
              Text(
                'Raw OCR text',
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(color: Colors.black54),
              ),
              const Spacer(),
              Icon(
                _expanded ? Icons.expand_less : Icons.expand_more,
                color: Colors.black38,
              ),
            ],
          ),
        ),
        if (_expanded) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: SelectableText(
              widget.text,
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
            ),
          ),
        ],
      ],
    );
  }
}
