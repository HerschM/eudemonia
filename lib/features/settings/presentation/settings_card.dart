import 'package:flutter/material.dart';
import 'package:eudemonia/features/theme/app_colors.dart';

/// Small uppercase label above a Settings card.
class SettingsSectionHeader extends StatelessWidget {
  final String title;

  const SettingsSectionHeader(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.9,
          color: AppColors.textSecondary.withValues(alpha: 0.7),
        ),
      ),
    );
  }
}

/// The rounded surface every Settings section sits on. Its [Material] gives list tiles and
/// ink splashes inside it a surface to paint on.
class SettingsCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const SettingsCard({super.key, required this.child, this.padding = const EdgeInsets.all(14)});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppColors.cardRadius),
        side: const BorderSide(color: AppColors.borderSubtle),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

/// A Settings card that shows only its title (and an optional [badge]) until tapped. The body is
/// not built while collapsed, so anything it owns (timers, readings) only runs while it is open.
class CollapsibleSettingsSection extends StatefulWidget {
  final Key headerKey;
  final String title;
  final Widget? badge;
  final WidgetBuilder bodyBuilder;

  const CollapsibleSettingsSection({
    super.key,
    required this.headerKey,
    required this.title,
    required this.bodyBuilder,
    this.badge,
  });

  @override
  State<CollapsibleSettingsSection> createState() => _CollapsibleSettingsSectionState();
}

class _CollapsibleSettingsSectionState extends State<CollapsibleSettingsSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return SettingsCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            expanded: _expanded,
            child: InkWell(
              key: widget.headerKey,
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.title,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.9,
                          color: AppColors.textSecondary.withValues(alpha: 0.9),
                        ),
                      ),
                    ),
                    if (widget.badge != null) ...[
                      widget.badge!,
                      const SizedBox(width: 8),
                    ],
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: const Icon(Icons.expand_more, size: 22, color: AppColors.textTertiary),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            alignment: Alignment.topCenter,
            child: _expanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                    child: widget.bodyBuilder(context),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}
