import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../bookings/models/booking_model.dart';
import '../../bookings/repository/bookings_repository.dart';

class QrPaymentScreen extends StatefulWidget {
  final BookingModel booking;
  const QrPaymentScreen({super.key, required this.booking});

  @override
  State<QrPaymentScreen> createState() => _QrPaymentScreenState();
}

class _QrPaymentScreenState extends State<QrPaymentScreen> {
  final _repo = BookingsRepository();
  String? _scanned;
  String? _proofDataUrl;
  bool _busy = false;

  Future<void> _scan() async {
    final value = await Navigator.push<String>(context, MaterialPageRoute(builder: (_) => const _ScannerScreen()));
    if (value != null && mounted) setState(() => _scanned = value);
  }

  Future<void> _pickProof() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 55);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() => _proofDataUrl = 'data:image/jpeg;base64,${base64Encode(bytes)}');
  }

  Future<void> _submit() async {
    if (_proofDataUrl == null) return;
    setState(() => _busy = true);
    try {
      await _repo.submitQrPayment(widget.booking.id, _proofDataUrl!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('QR payment submitted')));
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final qrId = widget.booking.driver['qrPaymentId']?.toString() ?? '';
    final qrLabel = widget.booking.driver['qrPaymentLabel']?.toString() ?? 'Driver QR';
    final qrImage = widget.booking.driver['qrPaymentImageUrl']?.toString();
    return Scaffold(
      appBar: AppBar(title: const Text('QR Payment')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.booking.routeLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text('${widget.booking.amountLabel} | Driver: ${widget.booking.driver['name'] ?? 'Driver'}'),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                Text(qrLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                if (qrImage != null && qrImage.startsWith('data:image'))
                  Image.memory(base64Decode(qrImage.split(',').last), height: 210, fit: BoxFit.contain)
                else if (qrId.isNotEmpty)
                  QrImageView(data: qrId, size: 210)
                else
                  const Icon(Icons.qr_code_2_rounded, size: 120, color: AppTheme.textSecondary),
                const SizedBox(height: 10),
                Text(qrId.isEmpty ? 'No QR added by driver yet' : qrId, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                OutlinedButton.icon(onPressed: _scan, icon: const Icon(Icons.qr_code_scanner_rounded), label: const Text('Scan QR')),
                if (_scanned != null) Text(_scanned!, style: const TextStyle(color: AppTheme.success)),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Payment Proof', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                OutlinedButton.icon(onPressed: _pickProof, icon: const Icon(Icons.upload_file_rounded), label: const Text('Attach Screenshot')),
                if (_proofDataUrl != null) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(base64Decode(_proofDataUrl!.split(',').last), height: 180, fit: BoxFit.cover),
                  ),
                ],
                const SizedBox(height: 10),
                ElevatedButton.icon(onPressed: _busy ? null : _submit, icon: const Icon(Icons.send_rounded), label: const Text('Submit Payment')),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScannerScreen extends StatefulWidget {
  const _ScannerScreen();

  @override
  State<_ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<_ScannerScreen> {
  bool _done = false;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Scan QR')),
        body: MobileScanner(
          onDetect: (capture) {
            if (_done) return;
            final value = capture.barcodes.isEmpty ? null : capture.barcodes.first.rawValue;
            if (value == null) return;
            _done = true;
            Navigator.pop(context, value);
          },
        ),
      );
}
