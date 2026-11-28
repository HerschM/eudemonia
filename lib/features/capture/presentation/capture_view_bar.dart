import 'package:flutter/material.dart';
import 'package:eudemonia/features/theme/app_colors.dart';

/// The bar at the top of the Capture tab, the counterpart of the Synthesis bar: one button whose
/// text names the current view (`All thoughts`, `Unread · Failed`, ...) and that opens the view
/// panel. Pure presentational widget. Keys: `capture_view_button`, `capture_view_title`.
class CaptureViewBar extends StatelessWidget {
  final String title;

  /// A filter other than the default is on; the button shows a small badge.
  final bool filterActive;
  final VoidCallback onTap;

  const CaptureViewBar({super.key, required this.title, required this.filterActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 12, 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Material(
          color: AppColors.surfaceElevated,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppColors.buttonRadius),
            side: const BorderSide(color: AppColors.borderSubtle),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: const Key('capture_view_button'),
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 40),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.filter_list, size: 16, color: AppColors.accentAction),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        title,
                        key: const Key('capture_view_title'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                      ),
                    ),
                    const Icon(Icons.arrow_drop_down, size: 20, color: AppColors.accentAction),
                    if (filterActive)
                      Container(
                        key: const Key('capture_view_filter_badge'),
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(left: 2),
                        decoration: const BoxDecoration(color: AppColors.accentAction, shape: BoxShape.circle),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
