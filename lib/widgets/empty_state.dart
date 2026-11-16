import 'package:flutter/material.dart';

import '../theme.dart';

/// Shown instead of a blank list (FR11, AC5). The title defaults to the
/// exact text "No issues found".
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    this.title = 'No issues found',
    required this.message,
    this.actionLabel,
    this.onAction,
    this.icon = Icons.search_off_rounded,
  });

  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scheme.secondaryContainer.withValues(alpha: 0.6),
            ),
            child: Icon(icon, size: 42, color: AppColors.brand),
          ),
          const SizedBox(height: 20),
          Text(title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, color: AppColors.inkMuted, height: 1.4)),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 20),
            OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}
