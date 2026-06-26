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
  void initState() { super.initState(); _loadExisting(); }

  @override
  void dispose() { _idCtrl.dispose(); _labelCtrl.dispose(); super.dispose(); }

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
          _previewData = '${_labelCtrl.text}:$id';
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select an image first'), backgroundColor: AppTheme.error));
      return;
    }
    setState(() => _loading = true);
    try {
      final bytes = await _qrImage!.readAsBytes();
      final filename = _qrImage!.name;
      final ext = filename.split('.').last.toLowerCase();
      final contentType = ext == 'png' ? 'image/png' : ext == 'jpg' || ext == 'jpeg' ? 'image/jpeg' : ext == 'webp' ? 'image/webp' : 'application/octet-stream';
      final result = await ApiService.uploadMultipart('/payments/qr/image', 'qrImage', bytes, filename: filename, contentType: contentType);
      final url = result['url'] as String?;
      if (url != null) setState(() { _qrImageUrl = url; _qrImages[_labelCtrl.text] = url; });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('QR image uploaded!'), backgroundColor: AppTheme.success));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (_idCtrl.text.trim().isEmpty || _labelCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all fields'), backgroundColor: AppTheme.error));
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
      setState(() { _loading = false; _saved = true; _previewData = '${_labelCtrl.text}:${_idCtrl.text.trim()}'; });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('QR details saved!'), backgroundColor: AppTheme.success));
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.error));
    }
  }

  void _onMethodChanged(String newLabel) {
    setState(() { _labelCtrl.text = newLabel; _qrImageUrl = _qrImages[newLabel]; _qrImage = null; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('QR Payment Setup'), backgroundColor: AppTheme.primary),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppTheme.infoBg, borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: AppTheme.info, size: 20),
                  SizedBox(width: 10),
                  Expanded(child: Text('Set up your mobile money details. Passengers will use this to pay you.', style: TextStyle(color: AppTheme.info, fontSize: 13, height: 1.4))),
                ],
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _idCtrl,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Mobile Money Number',
                prefixIcon: const Icon(Icons.phone_outlined),
                filled: true,
                fillColor: AppTheme.surfaceVariant,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusPill), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              value: _labels.contains(_labelCtrl.text) ? _labelCtrl.text : null,
              decoration: InputDecoration(
                labelText: 'Payment Service',
                prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
                filled: true,
                fillColor: AppTheme.surfaceVariant,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusPill), borderSide: BorderSide.none),
              ),
              items: _labels.map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
              onChanged: (v) { if (v != null) _onMethodChanged(v); },
              hint: const Text('Select service'),
            ),
            const SizedBox(height: 16),
            if (_qrImageUrl != null && _qrImage == null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      child: CachedNetworkImage(
                        imageUrl: _qrImageUrl!,
                        height: 60,
                        width: 60,
                        fit: BoxFit.contain,
                        placeholder: (c, u) => const SizedBox(height: 60, width: 60, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
                        errorWidget: (c, u, e) => const Icon(Icons.broken_image_rounded, size: 40, color: AppTheme.textTertiary),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text('Current ${_labelCtrl.text} QR saved', style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary))),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.image_rounded),
                    label: const Text('Select QR Image'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primary,
                      side: const BorderSide(color: AppTheme.primary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusPill)),
                    ),
                    onPressed: _loading ? null : _pickImage,
                  ),
                ),
                if (_qrImage != null) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: _loading
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.cloud_upload_rounded),
                      label: const Text('Upload'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusPill)),
                      ),
                      onPressed: _loading ? null : _uploadQrImage,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                icon: _loading
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save_rounded),
                label: const Text('Save QR Details', style: TextStyle(fontWeight: FontWeight.w800)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusPill)),
                ),
                onPressed: _loading ? null : _save,
              ),
            ),
            if (_saved && _previewData != null) ...[
              const SizedBox(height: 32),
              const Center(child: Text('Your QR Preview', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppTheme.textPrimary))),
              const SizedBox(height: 16),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                    border: Border.all(color: AppTheme.border),
                    boxShadow: AppTheme.cardShadow,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('QR for ${_labelCtrl.text}', style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                      const SizedBox(height: 12),
                      if (_qrImageUrl != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                          child: CachedNetworkImage(
                            imageUrl: _qrImageUrl!,
                            height: 180,
                            width: 180,
                            fit: BoxFit.contain,
                            placeholder: (c, u) => const SizedBox(height: 180, width: 180, child: Center(child: CircularProgressIndicator(color: AppTheme.primary))),
                            errorWidget: (c, u, e) => const SizedBox(height: 180, width: 180, child: Icon(Icons.broken_image_rounded, size: 60, color: AppTheme.textTertiary)),
                          ),
                        )
                      else
                        QrImageView(data: _previewData!, size: 180),
                      const SizedBox(height: 12),
                      Text(_labelCtrl.text, style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                      Text(_idCtrl.text, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
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
