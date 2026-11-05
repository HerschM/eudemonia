import 'package:flutter/material.dart';
import 'preview_theme.dart';
import 'screens/capture_screen_preview.dart';
import 'screens/synthesis_screen_preview.dart';
import 'screens/insights_screen_preview.dart';
import 'screens/action_screen_preview.dart';

/// Top-level shell presenting the 4-Stage Cognitive Architecture
/// [ Capture • Synthesis • Insights • Action ]
/// Designed for isolated interactive testing and verification.
class GalleryShell extends StatefulWidget {
  final int initialIndex;

  const GalleryShell({super.key, this.initialIndex = 0});

  @override
  State<GalleryShell> createState() => _GalleryShellState();
}

class _GalleryShellState extends State<GalleryShell> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _stages = ['Capture', 'Synthesis', 'Insights', 'Action'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: _stages.length,
      vsync: this,
      initialIndex: widget.initialIndex,
    );
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PreviewTheme.background,
      appBar: AppBar(
        backgroundColor: PreviewTheme.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 16.0,
        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // App Branding
              const Text(
                'Eudemonia',
                style: TextStyle(
                  color: PreviewTheme.textPrimary,
                  fontSize: 18.0,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(width: 8.0),
              // Live Processing Queue Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
                decoration: BoxDecoration(
                  color: PreviewTheme.accentAI.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(PreviewTheme.pillRadius),
                  border: Border.all(
                    color: PreviewTheme.accentAI.withOpacity(0.35),
                    width: 1.0,
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bolt, size: 12.0, color: PreviewTheme.accentAI),
                    SizedBox(width: 4.0),
                    Text(
                      '2 pending',
                      style: TextStyle(
                        color: PreviewTheme.accentAI,
                        fontSize: 11.0,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Settings & Diagnostics',
            icon: const Icon(Icons.settings_outlined, color: PreviewTheme.textSecondary, size: 22.0),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Settings & Diagnostics available in production build'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
          ),
          const SizedBox(width: 8.0),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48.0),
          child: Container(
            height: 44.0,
            margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
            decoration: BoxDecoration(
              color: PreviewTheme.surface,
              borderRadius: BorderRadius.circular(PreviewTheme.pillRadius),
              border: Border.all(color: PreviewTheme.borderSubtle, width: 1.0),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              indicator: BoxDecoration(
                color: PreviewTheme.surfaceElevated,
                borderRadius: BorderRadius.circular(PreviewTheme.pillRadius),
                border: Border.all(color: PreviewTheme.borderFocus, width: 1.0),
              ),
              labelColor: PreviewTheme.textPrimary,
              unselectedLabelColor: PreviewTheme.textSecondary,
              labelStyle: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 12.0,
                fontWeight: FontWeight.w500,
              ),
              labelPadding: EdgeInsets.zero,
              tabs: _stages.map((stage) => Tab(text: stage)).toList(),
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          CaptureScreenPreview(),
          SynthesisScreenPreview(),
          InsightsScreenPreview(),
          ActionScreenPreview(),
        ],
      ),
    );
  }
}
