import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Visual weight of an [AppButton].
enum AppButtonVariant { primary, accent, outline, ghost, danger }

enum AppButtonSize { large, medium, small }

/// A single, consistent button component used across the whole app so every
/// CTA (sign in, book ride, confirm, etc.) looks and behaves identically.
class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final IconData? icon;
  final bool loading;
  final bool expand;

  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.large,
    this.icon,
    this.loading = false,
    this.expand = true,
  });

  const AppButton.primary({
    super.key,
    required this.label,
    required this.onPressed,
    this.size = AppButtonSize.large,
    this.icon,
    this.loading = false,
    this.expand = true,
  }) : variant = AppButtonVariant.primary;

  const AppButton.outline({
    super.key,
    required this.label,
    required this.onPressed,
    this.size = AppButtonSize.large,
    this.icon,
    this.loading = false,
    this.expand = true,
  }) : variant = AppButtonVariant.outline;

  const AppButton.ghost({
    super.key,
    required this.label,
    required this.onPressed,
    this.size = AppButtonSize.medium,
    this.icon,
    this.loading = false,
    this.expand = false,
  }) : variant = AppButtonVariant.ghost;

  const AppButton.danger({
    super.key,
    required this.label,
    required this.onPressed,
    this.size = AppButtonSize.large,
    this.icon,
    this.loading = false,
    this.expand = true,
  }) : variant = AppButtonVariant.danger;

  double get _height {
    switch (size) {
      case AppButtonSize.large:
        return 54;
      case AppButtonSize.medium:
        return 46;
      case AppButtonSize.small:
        return 38;
    }
  }

  double get _fontSize {
    switch (size) {
      case AppButtonSize.large:
        return 16;
      case AppButtonSize.medium:
        return 14.5;
      case AppButtonSize.small:
        return 13;
    }
  }

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null || loading;

    Widget content = loading
        ? SizedBox(
            height: _fontSize + 2,
            width: _fontSize + 2,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              valueColor: AlwaysStoppedAnimation<Color>(_foreground(context)),
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: _fontSize + 4),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: _fontSize,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          );

    final button = _buildByVariant(context, disabled, content);

    return SizedBox(
      width: expand ? double.infinity : null,
      height: _height,
      child: button,
    );
  }

  Color _foreground(BuildContext context) {
    switch (variant) {
      case AppButtonVariant.primary:
      case AppButtonVariant.accent:
      case AppButtonVariant.danger:
        return Colors.white;
      case AppButtonVariant.outline:
      case AppButtonVariant.ghost:
        return AppTheme.primary;
    }
  }

  Widget _buildByVariant(BuildContext context, bool disabled, Widget content) {
    final radius = BorderRadius.circular(size == AppButtonSize.small ? AppTheme.radiusSm : AppTheme.radiusMd);

    switch (variant) {
      case AppButtonVariant.primary:
        return ElevatedButton(
          onPressed: disabled ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary,
            disabledBackgroundColor: AppTheme.primary.withOpacity(0.4),
            foregroundColor: Colors.white,
            elevation: 0,
            padding: EdgeInsets.symmetric(horizontal: size == AppButtonSize.small ? 14 : 20),
            shape: RoundedRectangleBorder(borderRadius: radius),
          ),
          child: content,
        );
      case AppButtonVariant.accent:
        return ElevatedButton(
          onPressed: disabled ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.accent,
            disabledBackgroundColor: AppTheme.accent.withOpacity(0.4),
            foregroundColor: Colors.white,
            elevation: 0,
            padding: EdgeInsets.symmetric(horizontal: size == AppButtonSize.small ? 14 : 20),
            shape: RoundedRectangleBorder(borderRadius: radius),
          ),
          child: content,
        );
      case AppButtonVariant.danger:
        return ElevatedButton(
          onPressed: disabled ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.error,
            disabledBackgroundColor: AppTheme.error.withOpacity(0.4),
            foregroundColor: Colors.white,
            elevation: 0,
            padding: EdgeInsets.symmetric(horizontal: size == AppButtonSize.small ? 14 : 20),
            shape: RoundedRectangleBorder(borderRadius: radius),
          ),
          child: content,
        );
      case AppButtonVariant.outline:
        return OutlinedButton(
          onPressed: disabled ? null : onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.primary,
            side: BorderSide(color: disabled ? AppTheme.border : AppTheme.border, width: 1.5),
            padding: EdgeInsets.symmetric(horizontal: size == AppButtonSize.small ? 14 : 20),
            shape: RoundedRectangleBorder(borderRadius: radius),
          ),
          child: content,
        );
      case AppButtonVariant.ghost:
        return TextButton(
          onPressed: disabled ? null : onPressed,
          style: TextButton.styleFrom(
            foregroundColor: AppTheme.primary,
            padding: EdgeInsets.symmetric(horizontal: size == AppButtonSize.small ? 10 : 16),
            shape: RoundedRectangleBorder(borderRadius: radius),
          ),
          child: content,
        );
    }
  }
}
