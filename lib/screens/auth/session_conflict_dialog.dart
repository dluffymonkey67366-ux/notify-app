import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Non-dismissible dialog shown immediately when a session conflict is detected
class SessionConflictDialog extends StatelessWidget {
  final String reason;
  final VoidCallback onDismiss;

  const SessionConflictDialog({
    super.key,
    required this.reason,
    required this.onDismiss,
  });

  static Future<void> show(BuildContext context, String reason, VoidCallback onDismiss) {
    return showDialog(
      context: context,
      barrierDismissible: false, // Force user to acknowledge
      builder: (ctx) => SessionConflictDialog(reason: reason, onDismiss: onDismiss),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Prevent Android back button dismiss
      child: AlertDialog(
        backgroundColor: AppTheme.inkCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppTheme.errorRed.withValues(alpha: 0.4), width: 1.5),
        ),
        title: Row(
          children: [
            const Icon(Icons.devices_other, color: AppTheme.errorRed, size: 28),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Session Terminated',
                style: TextStyle(
                  color: AppTheme.textLight,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              reason,
              style: const TextStyle(
                color: AppTheme.textMuted,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.inkDarker,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.shield_outlined, color: AppTheme.accentAmber, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Notify policy: 1 active account session at a time.',
                      style: TextStyle(color: AppTheme.accentAmber, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentAmber,
              foregroundColor: AppTheme.inkDarker,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () {
              Navigator.of(context).pop();
              onDismiss();
            },
            child: const Text('Return to Login'),
          ),
        ],
      ),
    );
  }
}
