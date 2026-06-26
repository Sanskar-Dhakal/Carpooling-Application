import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum BadgeTone { success, warning, error, info, neutral }

/// Small pill used for ride/booking/withdrawal statuses everywhere
/// (e.g. "Confirmed", "Pending", "Cancelled", "In Progress").
class StatusBadge extends StatelessWidget {
  final String label;
  final BadgeTone tone;
  final IconData? icon;

  const StatusBadge({super.key, required this.label, this.tone = BadgeTone.neutral, this.icon});

  /// Convenience constructor that maps a common backend status string
  /// (pending / confirmed / completed / cancelled / active / rejected...)
  /// to the right tone automatically.
  factory StatusBadge.fromStatus(String status) {
    final s = status.toLowerCase();
    if (['completed', 'confirmed', 'accepted', 'approved', 'active', 'paid', 'verified', 'available'].contains(s)) {
      return StatusBadge(label: _titleCase(status), tone: BadgeTone.success);
    }
    if (['pending', 'in_progress', 'in progress', 'processing', 'awaiting', 'ongoing'].contains(s)) {
      return StatusBadge(label: _titleCase(status), tone: BadgeTone.warning);
    }
    if (['cancelled', 'canceled', 'rejected', 'failed', 'declined', 'expired'].contains(s)) {
      return StatusBadge(label: _titleCase(status), tone: BadgeTone.error);
    }
    return StatusBadge(label: _titleCase(status), tone: BadgeTone.info);
  }

  static String _titleCase(String s) {
    final clean = s.replaceAll('_', ' ');
    if (clean.isEmpty) return clean;
    return clean.split(' ').map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}').join(' ');
  }

  ({Color fg, Color bg}) get _colors {
    switch (tone) {
      case BadgeTone.success:
        return (fg: AppTheme.success, bg: AppTheme.successBg);
      case BadgeTone.warning:
        return (fg: AppTheme.warning, bg: AppTheme.warningBg);
      case BadgeTone.error:
        return (fg: AppTheme.error, bg: AppTheme.errorBg);
      case BadgeTone.info:
        return (fg: AppTheme.info, bg: AppTheme.infoBg);
      case BadgeTone.neutral:
        return (fg: AppTheme.textSecondary, bg: AppTheme.surfaceVariant);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: c.fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(color: c.fg, fontSize: 11.5, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
