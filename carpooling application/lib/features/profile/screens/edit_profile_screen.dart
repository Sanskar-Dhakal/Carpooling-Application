import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/services/api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_event.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  bool _uploadingPhoto = false;
  bool _uploadingDoc = false;
  String? _photoUrl;
  String? _verificationStatus;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await ApiService.get('/users/me');
      final u = data['user'] as Map<String, dynamic>;
      _nameController.text = u['name'] ?? '';
      _phoneController.text = u['phone'] ?? '';
      setState(() {
        _photoUrl = u['profile_photo_url'];
        _verificationStatus = u['verification_status'];
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final phone = _phoneController.text.trim();
    if (phone.isNotEmpty && !_isValidNepalMobile(phone)) {
      Fluttertoast.showToast(msg: 'Enter a 10-digit Nepal mobile number');
      return;
    }
    setState(() => _saving = true);
    try {
      await ApiService.put('/users/me', {
        'name': _nameController.text.trim(),
        'phone': phone,
      });
      Fluttertoast.showToast(msg: 'Profile updated!');
      if (mounted) Navigator.pop(context);
    } catch (e) {
      Fluttertoast.showToast(msg: e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  bool _isValidNepalMobile(String phone) {
    return RegExp(r'^(97|98)\d{8}$').hasMatch(phone);
  }

  Future<void> _pickAndUploadPhoto() async {
    final picker = ImagePicker();
    final picked =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked == null) return;
    setState(() => _uploadingPhoto = true);
    try {
      const storage = FlutterSecureStorage();
      final token = await storage.read(key: AppConstants.tokenKey);
      final request = http.MultipartRequest(
          'POST', Uri.parse('${AppConstants.baseUrl}/users/photo'));
      if (token != null) request.headers['Authorization'] = 'Bearer $token';
      request.files.add(http.MultipartFile.fromBytes(
        'photo',
        await picked.readAsBytes(),
        filename: picked.name,
      ));
      final resp = await request.send();
      final body = await resp.stream.bytesToString();
      if (resp.statusCode == 200) {
        final data = jsonDecode(body) as Map<String, dynamic>;
        setState(() => _photoUrl = data['url'] as String?);
        Fluttertoast.showToast(msg: 'Photo updated!');
        if (mounted) context.read<AuthBloc>().add(AuthRefreshRequested());
      } else {
        Fluttertoast.showToast(msg: _messageFromBody(body, 'Upload failed'));
      }
    } catch (e) {
      Fluttertoast.showToast(msg: e.toString());
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _uploadIdDocument() async {
    final picker = ImagePicker();
    final picked =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
    if (picked == null) return;
    setState(() => _uploadingDoc = true);
    try {
      const storage = FlutterSecureStorage();
      final token = await storage.read(key: AppConstants.tokenKey);
      final request = http.MultipartRequest(
          'POST', Uri.parse('${AppConstants.baseUrl}/users/verify-doc'));
      if (token != null) request.headers['Authorization'] = 'Bearer $token';
      request.files.add(http.MultipartFile.fromBytes(
        'document',
        await picked.readAsBytes(),
        filename: picked.name,
      ));
      final resp = await request.send();
      final body = await resp.stream.bytesToString();
      if (resp.statusCode == 200) {
        setState(() => _verificationStatus = 'pending');
        Fluttertoast.showToast(msg: 'Document submitted for verification!');
      } else {
        Fluttertoast.showToast(msg: _messageFromBody(body, 'Upload failed'));
      }
    } catch (e) {
      Fluttertoast.showToast(msg: e.toString());
    } finally {
      if (mounted) setState(() => _uploadingDoc = false);
    }
  }

  String _messageFromBody(String body, String fallback) {
    try {
      final data = jsonDecode(body) as Map<String, dynamic>;
      return data['message'] as String? ?? fallback;
    } catch (_) {
      return fallback;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        backgroundColor: AppTheme.primary,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 52,
                        backgroundColor: AppTheme.primary.withOpacity(0.1),
                        backgroundImage:
                            _photoUrl != null ? NetworkImage(_photoUrl!) : null,
                        child: _photoUrl == null
                            ? const Icon(Icons.person,
                                size: 48, color: AppTheme.primary)
                            : null,
                      ),
                      GestureDetector(
                        onTap: _uploadingPhoto ? null : _pickAndUploadPhoto,
                        child: CircleAvatar(
                          radius: 18,
                          backgroundColor: AppTheme.primary,
                          child: _uploadingPhoto
                              ? const SizedBox(
                                  height: 16,
                                  width: 16,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.camera_alt,
                                  color: Colors.white, size: 18),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'Full Name',
                      prefixIcon: const Icon(Icons.person_outline),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                    decoration: InputDecoration(
                      labelText: 'Phone Number',
                      prefixIcon: const Icon(Icons.phone_outlined),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Card(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Driver Verification',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Text(
                            _verificationStatus == 'verified'
                                ? '✅ Your account is verified'
                                : _verificationStatus == 'pending'
                                    ? '⏳ Verification pending admin review'
                                    : _verificationStatus == 'rejected'
                                        ? '❌ Your document was rejected. You can reupload below.'
                                        : _verificationStatus == 'retake'
                                            ? '⚠️ Admin requested a new document. Please reupload.'
                                            : 'Upload your national ID or driving licence to get verified',
                            style: const TextStyle(
                                color: AppTheme.textSecondary, fontSize: 13),
                          ),
                          if (_verificationStatus != 'verified') ...[
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                icon: _uploadingDoc
                                    ? const SizedBox(
                                        height: 16,
                                        width: 16,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2))
                                    : const Icon(Icons.upload_file),
                                label: Text(_verificationStatus == 'pending'
                                    ? 'Re-upload Document'
                                    : _verificationStatus == 'rejected' ||
                                            _verificationStatus == 'retake'
                                        ? 'Reupload Document'
                                        : 'Upload ID Document'),
                                onPressed:
                                    _uploadingDoc ? null : _uploadIdDocument,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : const Text('Save Changes'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
