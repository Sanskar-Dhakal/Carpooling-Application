import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'app_button.dart';

export 'app_button.dart';
export 'app_card.dart';
export 'app_text_field.dart';
export 'status_badge.dart';
export 'app_states.dart';

/// Shows a modern, consistently-styled modal bottom sheet.
Future<T?> showAppBottomSheet<T>({
  required BuildContext context,
  required Widget child,
  bool isScrollControlled = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    backgroundColor: AppTheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusXl)),
    ),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: SafeArea(top: false, child: child),
    ),
  );
}

/// Shows a consistent confirmation dialog (e.g. cancel ride, logout, delete).
Future<bool> showAppConfirmDialog({
  required BuildContext context,
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool isDanger = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        Expanded(
          child: AppButton.outline(
            label: cancelLabel,
            onPressed: () => Navigator.of(ctx).pop(false),
            size: AppButtonSize.medium,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: isDanger
              ? AppButton.danger(
                  label: confirmLabel,
                  onPressed: () => Navigator.of(ctx).pop(true),
                  size: AppButtonSize.medium,
                )
              : AppButton.primary(
                  label: confirmLabel,
                  onPressed: () => Navigator.of(ctx).pop(true),
                  size: AppButtonSize.medium,
                ),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Shows a consistent floating snackbar (success / error / info).
void showAppSnackBar(BuildContext context, String message, {bool isError = false}) {
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Icon(
            isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
            color: isError ? AppTheme.error : AppTheme.success,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: const TextStyle(color: Colors.white, fontSize: 13.5))),
        ],
      ),
    ),
  );
}

/// Section header used to title groups of content on dashboards/lists.
class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const SectionHeader({super.key, required this.title, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textPrimary, letterSpacing: -0.2)),
        if (actionLabel != null)
          GestureDetector(
            onTap: onAction,
            child: Text(actionLabel!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.accentDark)),
          ),
      ],
    );
  }
}
