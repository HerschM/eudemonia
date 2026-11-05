import 'package:flutter/material.dart';
import '../mock_data.dart';
import '../preview_theme.dart';

/// Screen 4: Action Center Preview
/// Pure presentational preview showing extracted todo commitments, urgency tagging,
/// calendar time blocks, and calendar synchronization status.
class ActionScreenPreview extends StatefulWidget {
  final List<MockActionItem>? actionItems;
  final List<MockCalendarTimeBlock>? timeBlocks;
  final String calendarSyncStatus;
  final VoidCallback? onPushToCalendar;

  const ActionScreenPreview({
    super.key,
    this.actionItems,
    this.timeBlocks,
    this.calendarSyncStatus = 'Device Calendar: Connected (Personal)',
    this.onPushToCalendar,
  });

  @override
  State<ActionScreenPreview> createState() => _ActionScreenPreviewState();
}

class _ActionScreenPreviewState extends State<ActionScreenPreview> {
  late List<MockActionItem> _items;
  late List<MockCalendarTimeBlock> _blocks;

  @override
  void initState() {
    super.initState();
    _items = List.of(widget.actionItems ?? MockData.actionItems);
    _blocks = List.of(widget.timeBlocks ?? MockData.calendarTimeBlocks);
  }

  void _toggleItem(int index) {
    setState(() {
      final current = _items[index];
      _items[index] = current.copyWith(isCompleted: !current.isCompleted);
    });
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount = _items.where((i) => !i.isCompleted).length;
    final completedCount = _items.where((i) => i.isCompleted).length;

    return Container(
      color: PreviewTheme.background,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section: Calendar Sync Status Header Card
            _buildCalendarSyncCard(),
            const SizedBox(height: 16.0),

            // Section Header: Commitments Todo List
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8.0,
              runSpacing: 4.0,
              children: [
                const Text(
                  'COMMITMENTS & TODOS',
                  style: TextStyle(
                    color: PreviewTheme.textSecondary,
                    fontSize: 12.0,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
                  decoration: BoxDecoration(
                    color: PreviewTheme.accentAction.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(PreviewTheme.pillRadius),
                  ),
                  child: Text(
                    '$pendingCount open',
                    style: const TextStyle(
                      color: PreviewTheme.accentAction,
                      fontSize: 11.0,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (completedCount > 0)
                  Text(
                    '$completedCount done',
                    style: const TextStyle(
                      color: PreviewTheme.textTertiary,
                      fontSize: 11.0,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12.0),

            // Action Items List
            ...List.generate(_items.length, (index) {
              return _buildActionItemCard(_items[index], index);
            }),

            const SizedBox(height: 20.0),

            // Section Header: Schedule Time-Blocks
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8.0,
              runSpacing: 4.0,
              children: [
                const Text(
                  'SCHEDULE TIME-BLOCKS',
                  style: TextStyle(
                    color: PreviewTheme.textSecondary,
                    fontSize: 12.0,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                  ),
                ),
                Text(
                  '${_blocks.length} scheduled',
                  style: const TextStyle(
                    color: PreviewTheme.textTertiary,
                    fontSize: 11.0,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12.0),

            // Calendar Time Blocks List
            ..._blocks.map(_buildTimeBlockCard),

            const SizedBox(height: 16.0),

            // Action: Push to Calendar Button
            SizedBox(
              width: double.infinity,
              height: 48.0,
              child: ElevatedButton.icon(
                key: const Key('push_to_calendar_button'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: PreviewTheme.accentAction,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(PreviewTheme.buttonRadius),
                  ),
                  elevation: 0,
                ),
                icon: const Icon(Icons.calendar_month, size: 20.0),
                label: const Text(
                  'Push to Calendar',
                  style: TextStyle(
                    fontSize: 14.0,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onPressed: () {
                  if (widget.onPushToCalendar != null) {
                    widget.onPushToCalendar!();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: PreviewTheme.surfaceElevated,
                        content: Row(
                          children: [
                            const Icon(Icons.check_circle, color: PreviewTheme.accentCapture, size: 18.0),
                            const SizedBox(width: 8.0),
                            Text(
                              'Pushed ${_blocks.length} time blocks to device calendar',
                              style: const TextStyle(color: PreviewTheme.textPrimary),
                            ),
                          ],
                        ),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                },
              ),
            ),
            const SizedBox(height: 32.0),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarSyncCard() {
    return Container(
      padding: const EdgeInsets.all(14.0),
      decoration: PreviewTheme.cardDecoration(
        bgColor: PreviewTheme.surface,
        borderColor: PreviewTheme.accentAction.withOpacity(0.25),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10.0),
            decoration: BoxDecoration(
              color: PreviewTheme.accentAction.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.sync,
              color: PreviewTheme.accentAction,
              size: 20.0,
            ),
          ),
          const SizedBox(width: 12.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.calendarSyncStatus,
                  style: const TextStyle(
                    color: PreviewTheme.textPrimary,
                    fontSize: 13.0,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2.0),
                const Text(
                  'Two-way sync • Background polling every 30m',
                  style: TextStyle(
                    color: PreviewTheme.textSecondary,
                    fontSize: 11.0,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Calendar Settings',
            icon: const Icon(Icons.settings_outlined, color: PreviewTheme.textSecondary, size: 20.0),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Calendar sync preferences configured in Settings'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActionItemCard(MockActionItem item, int index) {
    final isUrgent = item.urgency.toLowerCase() == 'high';

    return Container(
      margin: const EdgeInsets.only(bottom: 10.0),
      padding: const EdgeInsets.all(14.0),
      decoration: PreviewTheme.cardDecoration(
        bgColor: item.isCompleted ? PreviewTheme.surface.withOpacity(0.5) : PreviewTheme.surface,
        borderColor: isUrgent ? PreviewTheme.accentWarning.withOpacity(0.3) : PreviewTheme.borderSubtle,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Checkbox
              SizedBox(
                width: 24.0,
                height: 24.0,
                child: Checkbox(
                  value: item.isCompleted,
                  activeColor: PreviewTheme.accentAction,
                  checkColor: Colors.white,
                  side: BorderSide(
                    color: item.isCompleted ? PreviewTheme.accentAction : PreviewTheme.textTertiary,
                    width: 1.5,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4.0),
                  ),
                  onChanged: (_) => _toggleItem(index),
                ),
              ),
              const SizedBox(width: 12.0),

              // Description
              Expanded(
                child: Text(
                  item.description,
                  style: TextStyle(
                    color: item.isCompleted ? PreviewTheme.textTertiary : PreviewTheme.textPrimary,
                    fontSize: 14.0,
                    fontWeight: FontWeight.w500,
                    decoration: item.isCompleted ? TextDecoration.lineThrough : null,
                    decorationColor: PreviewTheme.textTertiary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10.0),

          // Metadata Footer: Urgency Pill, Temporal Anchor, Origin Session
          Padding(
            padding: const EdgeInsets.only(left: 36.0),
            child: Wrap(
              spacing: 8.0,
              runSpacing: 6.0,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // Urgency chip
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
                  decoration: BoxDecoration(
                    color: isUrgent
                        ? PreviewTheme.accentWarning.withOpacity(0.18)
                        : PreviewTheme.surfaceElevated,
                    borderRadius: BorderRadius.circular(PreviewTheme.badgeRadius),
                  ),
                  child: Text(
                    isUrgent ? '⚡ High Urgency' : '${item.urgency} Urgency',
                    style: TextStyle(
                      color: isUrgent ? PreviewTheme.accentWarning : PreviewTheme.textSecondary,
                      fontSize: 11.0,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

                // Temporal Anchor Badge (e.g. 05/11  02:00 PM)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
                  decoration: BoxDecoration(
                    color: PreviewTheme.surfaceElevated,
                    borderRadius: BorderRadius.circular(PreviewTheme.badgeRadius),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.access_time, size: 12.0, color: PreviewTheme.textTertiary),
                      const SizedBox(width: 4.0),
                      Text(
                        item.temporalAnchor,
                        style: const TextStyle(
                          color: PreviewTheme.textSecondary,
                          fontSize: 11.0,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                // Origin Session Pill
                Text(
                  item.originSessionTitle,
                  style: const TextStyle(
                    color: PreviewTheme.textTertiary,
                    fontSize: 11.0,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeBlockCard(MockCalendarTimeBlock block) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10.0),
      padding: const EdgeInsets.all(14.0),
      decoration: PreviewTheme.cardDecoration(
        bgColor: PreviewTheme.surface,
        borderColor: PreviewTheme.accentAction.withOpacity(0.3),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
            decoration: BoxDecoration(
              color: PreviewTheme.accentAction.withOpacity(0.15),
              borderRadius: BorderRadius.circular(PreviewTheme.buttonRadius),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  block.date,
                  style: const TextStyle(
                    color: PreviewTheme.accentAction,
                    fontSize: 11.0,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2.0),
                Text(
                  block.timeRange,
                  style: const TextStyle(
                    color: PreviewTheme.textPrimary,
                    fontSize: 11.0,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  block.title,
                  style: const TextStyle(
                    color: PreviewTheme.textPrimary,
                    fontSize: 14.0,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2.0),
                const Text(
                  'Auto-scheduled focus block',
                  style: TextStyle(
                    color: PreviewTheme.textSecondary,
                    fontSize: 11.0,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: PreviewTheme.textTertiary, size: 20.0),
        ],
      ),
    );
  }
}
