import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/services/api_service.dart';
import '../../../core/theme/app_theme.dart';

class QrSetupScreen extends StatefulWidget {
  const QrSetupScreen({super.key});
  @override
  State<QrSetupScreen> createState() => _QrSetupState();
}

class _QrSetupState extends State<QrSetupScreen> {
  final _idCtrl = TextEditingController();
  final _labelCtrl = TextEditingController();
  bool _loading = false;
  bool _saved = false;
  String? _previewData;
  XFile? _qrImage;
  String? _qrImageUrl;
  Map<String, String> _qrImages = {};

  static const _labels = ['eSewa', 'Khalti', 'FonePay', 'IME Pay'];

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  @override
  void dispose() {
    _idCtrl.dispose();
    _labelCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadExisting() async {
    try {
      final data = await ApiService.get('/auth/me');
      final user = data['user'] as Map<String, dynamic>? ?? {};
      final id = user['qr_payment_id'] ?? '';
      final label = user['qr_payment_label'] ?? _labels[0];
      final currentImageUrl = user['qr_payment_image_url'];
      final imagesRaw = user['qr_payment_images'];
      final images = (imagesRaw is Map) ? Map<String, dynamic>.from(imagesRaw) : {};

      setState(() {
        _labelCtrl.text = _labels.contains(label) ? label : _labels[0];
        _idCtrl.text = id;
        _qrImageUrl = currentImageUrl;
        _qrImages = images.map((k, v) => MapEntry(k, v.toString()));
        if (id.isNotEmpty || currentImageUrl != null) {
          _saved = true;
          _previewData = '${_labelCtrl.text.isEmpty ? '' : _labelCtrl.text}:${id}';
        }
      });
    } catch (_) {}
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1200, maxHeight: 1200);
    if (picked != null) setState(() => _qrImage = picked);
  }

  Future<void> _uploadQrImage() async {
    if (_qrImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an image first'), backgroundColor: AppTheme.error),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      final bytes = await _qrImage!.readAsBytes();
      final filename = _qrImage!.name;
      final ext = filename.split('.').last.toLowerCase();
      final contentType = ext == 'png'
          ? 'image/png'
          : ext == 'jpg' || ext == 'jpeg'
              ? 'image/jpeg'
              : ext == 'webp'
                  ? 'image/webp'
                  : 'application/octet-stream';

      final result = await ApiService.uploadMultipart(
        '/payments/qr/image',
        'qrImage',
        bytes,
        filename: filename,
        contentType: contentType,
      );
      final url = result['url'] as String?;
      if (url != null) {
        setState(() {
          _qrImageUrl = url;
          _qrImages[_labelCtrl.text] = url;
        });
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('QR image uploaded!'), backgroundColor: AppTheme.success),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.error),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (_idCtrl.text.trim().isEmpty || _labelCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields'), backgroundColor: AppTheme.error),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      await ApiService.put('/payments/qr', {
        'qrPaymentId': _idCtrl.text.trim(),
        'qrPaymentLabel': _labelCtrl.text.trim(),
        if (_qrImageUrl != null) 'qrPaymentImageUrl': _qrImageUrl,
        'qrPaymentImages': _qrImages,
      });
      setState(() {
        _loading = false;
        _saved = true;
        _previewData = '${_labelCtrl.text}:${_idCtrl.text.trim()}';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('QR details saved!'), backgroundColor: AppTheme.success),
        );
      }
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  void _onMethodChanged(String newLabel) {
    setState(() {
      _labelCtrl.text = newLabel;
      _qrImageUrl = _qrImages[newLabel];
      _qrImage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('QR Payment Setup'),
        backgroundColor: AppTheme.driverColor,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Set up your mobile money details. Passengers will scan this to pay you.',
              style: TextStyle(color: AppTheme.textSecondary, height: 1.5),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _idCtrl,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Mobile Money Number',
                prefixIcon: const Icon(Icons.phone_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              value: _labels.contains(_labelCtrl.text) ? _labelCtrl.text : null,
              decoration: InputDecoration(
                labelText: 'Payment Service',
                prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.white,
              ),
              items: _labels.map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
              onChanged: (v) {
                if (v != null) _onMethodChanged(v);
              },
              hint: const Text('Select service'),
            ),
            const SizedBox(height: 12),
            if (_qrImageUrl != null && _qrImage == null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    CachedNetworkImage(
                      imageUrl: _qrImageUrl!,
                      height: 60,
                      width: 60,
                      fit: BoxFit.contain,
                      placeholder: (c, u) => const SizedBox(
                        height: 60,
                        width: 60,
                        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      ),
                      errorWidget: (c, u, e) => const Icon(Icons.broken_image, size: 40, color: Colors.grey),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Currently saved ${_labelCtrl.text} QR',
                        style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
            if (_qrImage != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: QrImageView(data: _previewData ?? '', size: 100),
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.image_outlined),
                    label: const Text('Change QR Image'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.driverColor,
                      side: const BorderSide(color: AppTheme.driverColor),
                    ),
                    onPressed: _loading ? null : _pickImage,
                  ),
                ),
                const SizedBox(width: 12),
                if (_qrImage != null)
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: _loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.cloud_upload_outlined),
                      label: const Text('Upload for'),
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.driverColor),
                      onPressed: _loading ? null : _uploadQrImage,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.save_outlined),
                label: const Text('Save QR Details'),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.driverColor),
                onPressed: _loading ? null : _save,
              ),
            ),
            if (_saved && _previewData != null)
              Column(
                children: const <Widget>[],
              ),
            if (_saved && _previewData != null) ...[
              const SizedBox(height: 32),
              const Center(
                child: Text(
                  'Your QR Preview',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textPrimary),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10)],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('QR for ${_labelCtrl.text}', style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                      const SizedBox(height: 8),
                      if (_qrImageUrl != null)
                        CachedNetworkImage(
                          imageUrl: _qrImageUrl!,
                          height: 180,
                          width: 180,
                          fit: BoxFit.contain,
                          placeholder: (c, u) => const SizedBox(
                            height: 180,
                            width: 180,
                            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                          ),
                          errorWidget: (c, u, e) => const SizedBox(
                            height: 180,
                            width: 180,
                            child: Icon(Icons.broken_image, size: 60, color: Colors.grey),
                          ),
                        )
                      else
                        QrImageView(data: _previewData!, size: 180),
                      const SizedBox(height: 12),
                      Text(_labelCtrl.text, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                      Text(_idCtrl.text, style: const TextStyle(color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
