import 'package:flutter/material.dart';
import 'package:eudemonia/features/synthesis/presentation/synthesis_filtering.dart';
import 'package:eudemonia/features/theme/app_colors.dart';

/// The content of the folder panel: the triage chips (All / Unread / Read) at the top, `All
/// notes` with its counts, one row per folder with its note count and a badge with its unread
/// count, and the footer link `Manage folders`. Pure presentational widget. Keys: `folder_panel`,
/// `folder_panel_all_notes`, `folder_panel_row_<name>`, `triage_chip_<all|unread|read>` and
/// `manage_folders_link`.
class FolderPanel extends StatelessWidget {
  final SynthesisTriage triage;
  final ValueChanged<SynthesisTriage> onTriageChanged;

  /// The folder whose notes are listed; null is `All notes`.
  final String? selectedFolder;
  final int totalCount;
  final int totalUnread;
  final List<FolderCount> folders;
  final VoidCallback onSelectAll;
  final ValueChanged<String> onSelectFolder;
  final VoidCallback onManageFolders;

  const FolderPanel({
    super.key,
    required this.triage,
    required this.onTriageChanged,
    required this.selectedFolder,
    required this.totalCount,
    required this.totalUnread,
    required this.folders,
    required this.onSelectAll,
    required this.onSelectFolder,
    required this.onManageFolders,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const Key('folder_panel'),
      color: AppColors.surface,
      elevation: 8,
      child: SafeArea(
        right: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 14, 12, 10),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final t in SynthesisTriage.values)
                    ChoiceChip(
                      key: Key('triage_chip_${t.name}'),
                      label: Text(switch (t) {
                        SynthesisTriage.all => 'All',
                        SynthesisTriage.unread => 'Unread',
                        SynthesisTriage.read => 'Read',
                      }),
                      selected: triage == t,
                      showCheckmark: false,
                      visualDensity: VisualDensity.compact,
                      selectedColor: AppColors.accentAction.withValues(alpha: 0.25),
                      backgroundColor: AppColors.surfaceElevated,
                      side: BorderSide(color: triage == t ? AppColors.accentAction : AppColors.borderSubtle),
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: triage == t ? AppColors.textPrimary : AppColors.textSecondary,
                      ),
                      onSelected: (_) => onTriageChanged(t),
                    ),
                ],
              ),
            ),
            const Divider(color: AppColors.borderSubtle, height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 6),
                children: [
                  _PanelRow(
                    keyId: 'folder_panel_all_notes',
                    icon: Icons.notes,
                    name: 'All notes',
                    count: totalCount,
                    unread: totalUnread,
                    selected: selectedFolder == null,
                    onTap: onSelectAll,
                  ),
                  for (final f in folders)
                    _PanelRow(
                      keyId: 'folder_panel_row_${f.name}',
                      icon: Icons.folder_outlined,
                      name: f.name,
                      count: f.count,
                      unread: f.unread,
                      selected: selectedFolder != null && selectedFolder!.toLowerCase() == f.name.toLowerCase(),
                      onTap: () => onSelectFolder(f.name),
                    ),
                ],
              ),
            ),
            const Divider(color: AppColors.borderSubtle, height: 1),
            InkWell(
              key: const Key('manage_folders_link'),
              onTap: onManageFolders,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Icon(Icons.tune, size: 16, color: AppColors.accentAction),
                    SizedBox(width: 8),
                    Text(
                      'Manage folders',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.accentAction),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PanelRow extends StatelessWidget {
  final String keyId;
  final IconData icon;
  final String name;
  final int count;
  final int unread;
  final bool selected;
  final VoidCallback onTap;

  const _PanelRow({
    required this.keyId,
    required this.icon,
    required this.name,
    required this.count,
    required this.unread,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
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
                Icon(icon, size: 18, color: selected ? AppColors.accentAction : AppColors.textSecondary),
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
                if (unread > 0)
                  Container(
                    key: Key('${keyId}_unread'),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppColors.accentAction,
                      borderRadius: BorderRadius.circular(AppColors.pillRadius),
                    ),
                    child: Text(
                      '$unread',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                  ),
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
    );
  }
}

/// Lays the folder panel over [child] (the list): it slides in from the left, about 80 % of the
/// width and at most 320 dp, with a scrim behind that closes it when tapped. There is no drag
/// to open it: horizontal swipes belong to the tab switch. The list underneath keeps its place.
/// Pure presentational widget.
class FolderPanelOverlay extends StatefulWidget {
  final bool open;
  final VoidCallback onDismiss;
  final Widget panel;
  final Widget child;

  const FolderPanelOverlay({
    super.key,
    required this.open,
    required this.onDismiss,
    required this.panel,
    required this.child,
  });

  static const Duration slideDuration = Duration(milliseconds: 220);
  static const double maxPanelWidth = 320;

  @override
  State<FolderPanelOverlay> createState() => _FolderPanelOverlayState();
}

class _FolderPanelOverlayState extends State<FolderPanelOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: FolderPanelOverlay.slideDuration,
    value: widget.open ? 1 : 0,
  );

  late final CurvedAnimation _eased = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);

  @override
  void didUpdateWidget(covariant FolderPanelOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.open != oldWidget.open) {
      widget.open ? _controller.forward() : _controller.reverse();
    }
  }

  @override
  void dispose() {
    _eased.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final showing = !_controller.isDismissed;
        return Stack(
          fit: StackFit.expand,
          children: [
            widget.child,
            if (showing)
              Positioned.fill(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final width = (constraints.maxWidth * 0.8).clamp(0.0, FolderPanelOverlay.maxPanelWidth);
                    return Stack(
                      children: [
                        Positioned.fill(
                          child: FadeTransition(
                            opacity: _eased,
                            child: GestureDetector(
                              key: const Key('folder_panel_scrim'),
                              behavior: HitTestBehavior.opaque,
                              onTap: widget.onDismiss,
                              child: const ColoredBox(color: Color(0x99000000)),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 0,
                          top: 0,
                          bottom: 0,
                          width: width,
                          child: SlideTransition(
                            position: Tween(begin: const Offset(-1, 0), end: Offset.zero).animate(_eased),
                            child: widget.panel,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}
