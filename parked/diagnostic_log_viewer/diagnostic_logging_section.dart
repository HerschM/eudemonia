import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eudemonia/core/logger/app_logger.dart';
import 'package:eudemonia/features/theme/app_colors.dart';
import 'settings_card.dart';

/// PARKED (removed from the first release, 2026-11-26): the "DIAGNOSTIC LOGGING (2MB ROTATING)"
/// section of Settings: view the recent log lines in a sheet, copy the whole log, clear it.
/// Moved here unchanged from `settings_screen.dart` at commit 073c1d8; see README.md.
class DiagnosticLoggingSection extends ConsumerWidget {
  const DiagnosticLoggingSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SettingsSectionHeader('DIAGNOSTIC LOGGING (2MB ROTATING)'),
              Material(
                color: AppColors.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppColors.cardRadius),
                  side: const BorderSide(color: AppColors.borderSubtle),
                ),
                child: Column(
                  children: [
                    ListTile(
                      key: const Key('view_system_logs_button'),
                      leading: const Icon(Icons.description_outlined,
                          color: AppColors.accentAction),
                      title: const Text('View System Logs',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary)),
                      subtitle: const Text(
                          'Inspect recent trigger events, queue status, and errors',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.textSecondary)),
                      onTap: () async {
                        final logger = ref.read(appLoggerProvider);
                        final lines = await logger.getRecentLines(count: 80);
                        if (!context.mounted) return;
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: AppColors.surfaceElevated,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(AppColors.modalRadius),
                            ),
                          ),
                          builder: (ctx) => DraggableScrollableSheet(
                            initialChildSize: 0.7,
                            maxChildSize: 0.95,
                            minChildSize: 0.4,
                            expand: false,
                            builder: (_, scrollController) => Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Expanded(
                                        child: Text(
                                          'On-Device Diagnostic Logs',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                              color: AppColors.textPrimary),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.close,
                                            color: AppColors.textSecondary),
                                        onPressed: () => Navigator.pop(ctx),
                                      ),
                                    ],
                                  ),
                                  const Divider(color: AppColors.borderSubtle),
                                  Expanded(
                                    child: lines.isEmpty
                                        ? const Center(
                                            child: Text('No logs recorded yet.',
                                                style: TextStyle(
                                                    color: AppColors.textSecondary)))
                                        : ListView.builder(
                                            controller: scrollController,
                                            itemCount: lines.length,
                                            itemBuilder: (context, index) => Text(
                                              lines[index],
                                              style: const TextStyle(
                                                fontFamily: 'monospace',
                                                fontSize: 11,
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                          ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const Divider(height: 1, color: AppColors.borderSubtle),
                    ListTile(
                      key: const Key('copy_log_dump_button'),
                      leading: const Icon(Icons.copy_all,
                          color: AppColors.accentAction),
                      title: const Text('Copy Diagnostic Log Dump',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary)),
                      subtitle: const Text(
                          'Copies all on-device logs to clipboard for debugging',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.textSecondary)),
                      onTap: () async {
                        final logger = ref.read(appLoggerProvider);
                        final dump = await logger.getLogDump();
                        await Clipboard.setData(ClipboardData(text: dump));
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Log dump copied to clipboard.')),
                        );
                      },
                    ),
                    const Divider(height: 1, color: AppColors.borderSubtle),
                    ListTile(
                      key: const Key('clear_logs_button'),
                      leading: const Icon(Icons.delete_outline,
                          color: AppColors.accentError),
                      title: const Text('Clear Logs',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.accentError)),
                      subtitle: const Text('Truncates local log storage file',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.textSecondary)),
                      onTap: () async {
                        final logger = ref.read(appLoggerProvider);
                        await logger.clearLogs();
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Local logs cleared.')),
                        );
                      },
                    ),
                  ],
                ),
              ),
      ],
    );
  }
}
