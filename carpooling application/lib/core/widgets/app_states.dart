import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../theme/app_theme.dart';
import 'app_button.dart';

/// Full-bleed centered loading indicator with optional message.
class AppLoadingState extends StatelessWidget {
  final String? message;
  const AppLoadingState({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(strokeWidth: 2.6),
          if (message != null) ...[
            const SizedBox(height: AppTheme.space16),
            Text(message!, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13.5)),
          ],
        ],
      ),
    );
  }
}

/// Friendly empty state with icon, title, optional subtitle & CTA.
class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const AppEmptyState({
    super.key,
    this.icon = Icons.search_off_rounded,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.space32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: AppTheme.surfaceVariant,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 38, color: AppTheme.textTertiary),
            ),
            const SizedBox(height: AppTheme.space20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: AppTheme.space8),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13.5, color: AppTheme.textSecondary, height: 1.4),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppTheme.space24),
              AppButton.outline(label: actionLabel!, onPressed: onAction, expand: false, size: AppButtonSize.medium),
            ],
          ],
        ),
      ),
    );
  }
}

/// Error state with retry affordance.
class AppErrorState extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onRetry;

  const AppErrorState({
    super.key,
    this.title = 'Something went wrong',
    this.subtitle,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.space32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: const BoxDecoration(color: AppTheme.errorBg, shape: BoxShape.circle),
              child: const Icon(Icons.error_outline_rounded, size: 38, color: AppTheme.error),
            ),
            const SizedBox(height: AppTheme.space20),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
            if (subtitle != null) ...[
              const SizedBox(height: AppTheme.space8),
              Text(subtitle!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13.5, color: AppTheme.textSecondary, height: 1.4)),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: AppTheme.space24),
              AppButton.primary(label: 'Try Again', onPressed: onRetry, expand: false, size: AppButtonSize.medium, icon: Icons.refresh_rounded),
            ],
          ],
        ),
      ),
    );
  }
}

/// Shimmering skeleton block — use while content streams in.
class AppSkeleton extends StatelessWidget {
  final double height;
  final double? width;
  final double radius;

  const AppSkeleton({super.key, this.height = 16, this.width, this.radius = 8});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppTheme.surfaceVariant,
      highlightColor: const Color(0xFFFAFBFC),
      child: Container(
        height: height,
        width: width ?? double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

/// Pre-built skeleton matching a typical ride/booking card layout, used as a
/// placeholder while lists load from Firestore / the API.
class RideCardSkeleton extends StatelessWidget {
  const RideCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.space12),
      padding: const EdgeInsets.all(AppTheme.space16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const AppSkeleton(height: 38, width: 38, radius: 19),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    AppSkeleton(height: 12, width: 120),
                    SizedBox(height: 6),
                    AppSkeleton(height: 10, width: 80),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const AppSkeleton(height: 12, width: double.infinity),
          const SizedBox(height: 8),
          const AppSkeleton(height: 12, width: 180),
        ],
      ),
    );
  }
}
