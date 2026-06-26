import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../../../core/services/api_service.dart';
import '../../../core/theme/app_theme.dart';

class ReviewScreen extends StatefulWidget {
  final String bookingId;
  final String reviewedUserName;
  final bool isReviewingDriver;

  const ReviewScreen({
    super.key,
    required this.bookingId,
    required this.reviewedUserName,
    required this.isReviewingDriver,
  });

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  int _rating = 0;
  final _commentController = TextEditingController();
  bool _submitting = false;

  static const _labels = ['', 'Poor', 'Fair', 'Good', 'Very Good', 'Excellent'];

  Future<void> _submit() async {
    if (_rating == 0) {
      Fluttertoast.showToast(msg: 'Please select a rating');
      return;
    }
    setState(() => _submitting = true);
    try {
      await ApiService.post('/bookings/${widget.bookingId}/review', {
        'rating': _rating,
        'comment': _commentController.text.trim().isEmpty ? null : _commentController.text.trim(),
      });
      Fluttertoast.showToast(msg: 'Review submitted!');
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      Fluttertoast.showToast(msg: e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Rate Your Trip'),
        backgroundColor: AppTheme.primary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 16),
            // Avatar
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                widget.isReviewingDriver ? Icons.drive_eta_rounded : Icons.person_rounded,
                size: 48,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'How was your trip with\n${widget.reviewedUserName}?',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.textPrimary, height: 1.3),
            ),
            const SizedBox(height: 32),

            // Stars
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                border: Border.all(color: AppTheme.border),
                boxShadow: AppTheme.cardShadow,
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (i) {
                      final star = i + 1;
                      return GestureDetector(
                        onTap: () => setState(() => _rating = star),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Icon(
                            star <= _rating ? Icons.star_rounded : Icons.star_border_rounded,
                            size: 52,
                            color: star <= _rating ? AppTheme.accent : AppTheme.border,
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 12),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Text(
                      _rating == 0 ? 'Tap to rate' : _labels[_rating],
                      key: ValueKey(_rating),
                      style: TextStyle(
                        color: _rating > 0 ? AppTheme.accent : AppTheme.textTertiary,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Comment
            TextField(
              controller: _commentController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Comment (optional)',
                hintText: 'Share your experience…',
                filled: true,
                fillColor: AppTheme.surfaceVariant,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  borderSide: const BorderSide(color: AppTheme.primary, width: 1.8),
                ),
              ),
            ),
            const SizedBox(height: 28),

            // Submit
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusPill)),
                  elevation: 0,
                ),
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                    : const Text('Submit Review', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Skip for now', style: TextStyle(color: AppTheme.textSecondary)),
            ),
          ],
        ),
      ),
    );
  }
}
