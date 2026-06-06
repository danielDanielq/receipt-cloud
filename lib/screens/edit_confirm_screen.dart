import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

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

  @override
  void dispose() {
    _vendorController.dispose();
    _dateController.dispose();
    _totalController.dispose();
    super.dispose();
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
                prefixIcon: Icon(Icons.attach_money),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            // Phase 4: auto-parse rawOcrText into fields above
            _RawOcrTextBox(text: widget.rawOcrText),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                // Phase 4: save Receipt to Firestore, then pop to Home
                Navigator.popUntil(context, (route) => route.isFirst);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(fontSize: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Save Receipt'),
            ),
          ],
        ),
      ),
    );
  }
}

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
