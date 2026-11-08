import 'package:flutter/material.dart';
import 'package:eudemonia/features/theme/app_colors.dart';

class ActionPlaceholderScreen extends StatelessWidget {
  const ActionPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.all(24.0),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: const Icon(
                Icons.schedule,
                size: 36,
                color: AppColors.accentWarning,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Stage 4: Action Engine',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Commitments & Calendar Time-Blocking',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.accentWarning.withValues(alpha: 0.9),
              ),
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Text(
                'On-device action extraction, priority todo lists, and two-way calendar synchronizations will be unlocked in the upcoming release.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.45,
                  color: AppColors.textSecondary.withValues(alpha: 0.8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

