import 'package:flutter/material.dart';
import 'package:eudemonia/features/home/presentation/pipeline_status_chip.dart';
import 'package:eudemonia/features/theme/app_colors.dart';

/// The one row under the status bar: the pipeline status chip on the left, the Capture | Synthesis
/// tabs taking the remaining width, and the Settings gear on the right. There is no app title:
/// the space goes to the notes. The chip scales its text down before the tabs give way.
class ShellTopBar extends StatelessWidget {
  final TabController controller;
  final String captureLabel;
  final String synthesisLabel;
  final VoidCallback onOpenSettings;

  const ShellTopBar({
    super.key,
    required this.controller,
    required this.captureLabel,
    required this.synthesisLabel,
    required this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.only(left: 12.0, top: 4.0, bottom: 4.0),
        child: Row(
          children: [
            const PipelineStatusChip(),
            const SizedBox(width: 8.0),
            Expanded(
              child: Container(
                height: 44.0,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppColors.pillRadius),
                  border: Border.all(color: AppColors.borderSubtle, width: 1.0),
                ),
                child: TabBar(
                  controller: controller,
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  // No rectangular ink frame around the rounded pill; the pill itself slides with the
                  // swipe (it follows the controller's animation), so the tap needs no splash.
                  splashFactory: NoSplash.splashFactory,
                  overlayColor: const WidgetStatePropertyAll(Colors.transparent),
                  indicatorAnimation: TabIndicatorAnimation.linear,
                  indicator: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(AppColors.pillRadius),
                    border: Border.all(color: AppColors.borderFocus, width: 1.0),
                  ),
                  labelColor: AppColors.textPrimary,
                  unselectedLabelColor: AppColors.textSecondary,
                  labelStyle: const TextStyle(fontSize: 12.0, fontWeight: FontWeight.w600),
                  unselectedLabelStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500),
                  labelPadding: EdgeInsets.zero,
                  tabs: [
                    _tab(captureLabel),
                    _tab(synthesisLabel),
                  ],
                ),
              ),
            ),
            IconButton(
              key: const Key('settings_gear_button'),
              tooltip: 'Settings',
              icon: const Icon(Icons.settings_outlined, color: AppColors.textSecondary, size: 22.0),
              onPressed: onOpenSettings,
            ),
          ],
        ),
      ),
    );
  }

  /// A tab whose label shrinks rather than wraps or clips when the count grows to two digits.
  Tab _tab(String label) => Tab(child: FittedBox(fit: BoxFit.scaleDown, child: Text(label, maxLines: 1)));
}
