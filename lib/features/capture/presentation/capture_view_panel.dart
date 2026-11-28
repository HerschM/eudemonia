import 'package:flutter/material.dart';
import 'package:eudemonia/features/capture/presentation/capture_view_filter.dart';
import 'package:eudemonia/features/theme/app_colors.dart';

/// The content of the Capture view panel, opened from the bar: two groups of choices, `Show`
/// (All thoughts / Unread / Read) and `Status` (Any status / Processing / Processed / Synthesized
/// / Failed), each row with how many thoughts it lists. It is laid over the list by
/// `FolderPanelOverlay`, the sliding panel Synthesis uses for its folders. Pure presentational
/// widget. Keys: `capture_view_panel`, `capture_view_show_<name>`, `capture_view_status_<name>`
/// (with `_count` appended for the count).
class CaptureViewPanel extends StatelessWidget {
  final CaptureTriageFilter triage;
  final CaptureStatusFilter status;
  final CaptureViewCounts counts;
  final ValueChanged<CaptureTriageFilter> onTriageChanged;
  final ValueChanged<CaptureStatusFilter> onStatusChanged;

  const CaptureViewPanel({
    super.key,
    required this.triage,
    required this.status,
    required this.counts,
    required this.onTriageChanged,
    required this.onStatusChanged,
  });

  static IconData _triageIcon(CaptureTriageFilter f) => switch (f) {
        CaptureTriageFilter.all => Icons.visibility_outlined,
        CaptureTriageFilter.unread => Icons.mark_email_unread_outlined,
        CaptureTriageFilter.read => Icons.drafts_outlined,
      };

  static IconData _statusIcon(CaptureStatusFilter f) => switch (f) {
        CaptureStatusFilter.all => Icons.layers_outlined,
        CaptureStatusFilter.processing => Icons.hourglass_top,
        CaptureStatusFilter.processed => Icons.chat_bubble_outline,
        CaptureStatusFilter.synthesized => Icons.hub_outlined,
        CaptureStatusFilter.failed => Icons.error_outline,
      };

  static Color _statusColor(CaptureStatusFilter f) => switch (f) {
        CaptureStatusFilter.all => AppColors.textSecondary,
        CaptureStatusFilter.processing => AppColors.accentWarning,
        CaptureStatusFilter.processed => AppColors.accentAction,
        CaptureStatusFilter.synthesized => AppColors.accentCapture,
        CaptureStatusFilter.failed => AppColors.accentError,
      };

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const Key('capture_view_panel'),
      color: AppColors.surface,
      elevation: 8,
      child: SafeArea(
        right: false,
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 6),
          children: [
            const _GroupHeader('Show'),
            for (final f in CaptureTriageFilter.values)
              _ViewRow(
                keyId: 'capture_view_show_${f.name}',
                icon: _triageIcon(f),
                iconColor: f == triage ? AppColors.accentAction : AppColors.textSecondary,
                name: captureTriageLabel(f),
                count: counts.show[f] ?? 0,
                selected: f == triage,
                onTap: () => onTriageChanged(f),
              ),
            const Divider(color: AppColors.borderSubtle, height: 17),
            const _GroupHeader('Status'),
            for (final f in CaptureStatusFilter.values)
              _ViewRow(
                keyId: 'capture_view_status_${f.name}',
                icon: _statusIcon(f),
                iconColor: _statusColor(f),
                name: captureStatusLabel(f),
                count: counts.status[f] ?? 0,
                selected: f == status,
                onTap: () => onStatusChanged(f),
              ),
          ],
        ),
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  final String label;

  const _GroupHeader(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: AppColors.textTertiary,
        ),
      ),
    );
  }
}

class _ViewRow extends StatelessWidget {
  final String keyId;
  final IconData icon;
  final Color iconColor;
  final String name;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const _ViewRow({
    required this.keyId,
    required this.icon,
    required this.iconColor,
    required this.name,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      child: Material(
        color: selected ? AppColors.accentAction.withValues(alpha: 0.12) : Colors.transparent,
        child: InkWell(
          key: Key(keyId),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  Icon(icon, size: 18, color: iconColor),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$count',
                    key: Key('${keyId}_count'),
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary.withValues(alpha: 0.9)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
