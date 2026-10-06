import 'package:flutter/material.dart';
import 'package:m18_residences_shared/m18_residences_shared.dart';

enum SnackBarType { success, error, info, loading }

class CustomSnackbar {
  static void show(
    BuildContext context,
    String message, {
    SnackBarType type = SnackBarType.info,
    Duration duration = const Duration(seconds: 2),
    bool dismissPrevious = true,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    showWithMessenger(messenger, message, type: type, duration: duration, dismissPrevious: dismissPrevious);
  }

  static void showWithMessenger(
    ScaffoldMessengerState messenger,
    String message, {
    SnackBarType type = SnackBarType.info,
    Duration duration = const Duration(seconds: 2),
    bool dismissPrevious = true,
  }) {
    final snackBar = _buildSnackBar(messenger.context, message, type, duration);
    if (dismissPrevious) messenger.hideCurrentSnackBar();
    messenger.showSnackBar(snackBar);
  }

  static void hide(BuildContext context) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
  }

  static void hideWithMessenger(ScaffoldMessengerState messenger) {
    messenger.hideCurrentSnackBar();
  }

  static SnackBar _buildSnackBar(BuildContext context, String message, SnackBarType type, Duration duration) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final status = StatusColors.of(context);
    final isError = type == SnackBarType.error;
    // Errors on the error color; everything else on the theme's inverse surface with a colored icon.
    final background = isError ? scheme.error : scheme.inverseSurface;
    final contentColor = isError ? scheme.onError : scheme.onInverseSurface;
    final iconColor = switch (type) {
      SnackBarType.success => scheme.brightness == Brightness.light ? status.paid : status.onPaid,
      SnackBarType.error => scheme.onError,
      SnackBarType.info || SnackBarType.loading => scheme.inversePrimary,
    };

    final Widget leading = type == SnackBarType.loading
        ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(iconColor)))
        : Icon(switch (type) {
            SnackBarType.success => Icons.check_circle,
            SnackBarType.error => Icons.error_outline,
            _ => Icons.info_outline,
          }, color: iconColor);

    return SnackBar(
      backgroundColor: background,
      margin: const EdgeInsets.all(16),
      // A loading toast is replaced by the result's toast; the limit only guards against a result that never comes.
      duration: type == SnackBarType.loading ? const Duration(seconds: 30) : duration,
      content: Row(
        children: [
          leading,
          const SizedBox(width: 12),
          Expanded(
            child: Text(message, style: theme.textTheme.bodyMedium?.copyWith(color: contentColor)),
          ),
        ],
      ),
    );
  }
}
