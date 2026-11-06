import 'package:flutter/material.dart';
import '../mock_data.dart';
import '../preview_theme.dart';

class SettingsPreview extends StatefulWidget {
  final MockSettingsConfig? initialConfig;

  const SettingsPreview({super.key, this.initialConfig});

  @override
  State<SettingsPreview> createState() => _SettingsPreviewState();
}

class _SettingsPreviewState extends State<SettingsPreview> {
  late MockSettingsConfig _config;
  int _unprocessedBufferCount = 2;

  @override
  void initState() {
    super.initState();
    _config = widget.initialConfig ?? MockData.settingsConfig;
  }

  void _triggerSynthesisNow() {
    setState(() {
      _unprocessedBufferCount = 0;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: PreviewTheme.surfaceElevated,
        content: const Row(
          children: [
            Icon(Icons.auto_awesome, color: PreviewTheme.accentAI, size: 16),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Triggered on-demand synthesis for buffered thoughts!',
                style: TextStyle(color: PreviewTheme.textPrimary),
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _evictModelsNow() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: PreviewTheme.surfaceElevated,
        content: const Text(
          'AI models evicted. Memory reclaimed: ~1.58 GB RAM. Baseline: <60 MB.',
          style: TextStyle(color: PreviewTheme.accentCapture),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PreviewTheme.background,
      appBar: AppBar(
        backgroundColor: PreviewTheme.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          key: const Key('settings_back_button'),
          icon: const Icon(Icons.arrow_back, color: PreviewTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Settings & Diagnostics',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: PreviewTheme.textPrimary,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        children: [
          // Section 1: Background & Hardware Permissions
          _buildSectionHeader('HARDWARE & BACKGROUND PERMISSIONS'),
          _buildCard(
            children: [
              _buildStatusRow(
                title: 'Accessibility Interceptor',
                subtitle: 'Zero-latency volume key hardware listener',
                badgeText: _config.isAccessibilityGranted ? 'ENABLED' : 'DISABLED',
                isSuccess: _config.isAccessibilityGranted,
              ),
              const Divider(height: 20, color: PreviewTheme.borderSubtle),
              _buildStatusRow(
                title: 'Battery Optimization Exemption',
                subtitle: 'Protects process from OS Doze hibernation',
                badgeText: _config.isBatteryExemptGranted ? 'ENABLED' : 'DISABLED',
                isSuccess: _config.isBatteryExemptGranted,
              ),
              const Divider(height: 20, color: PreviewTheme.borderSubtle),
              _buildSwitchRow(
                title: 'Keep-Alive Foreground Service',
                subtitle: 'Low-priority persistent notification keeps worker active',
                value: _config.isForegroundKeepAlive,
                onChanged: (val) =>
                    setState(() => _config = _config.copyWith(isForegroundKeepAlive: val)),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Section 2: Automatic Synthesis Trigger & Batching Safeguards
          _buildSectionHeader('AUTOMATIC SYNTHESIS TRIGGER & BATCHING'),
          _buildCard(
            children: [
              Text(
                'Groups thoughts captured during an activity (e.g. morning walk) and triggers clustering without draining mobile battery.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: PreviewTheme.textSecondary.withValues(alpha: 0.85),
                ),
              ),
              const SizedBox(height: 14),

              // Threshold 1: Trigger after X capture thoughts
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Trigger After X Captures',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: PreviewTheme.textPrimary,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Accumulated unprocessed notes threshold',
                          style: TextStyle(fontSize: 12, color: PreviewTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    key: const Key('synthesis_note_threshold_dropdown'),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    decoration: BoxDecoration(
                      color: PreviewTheme.surfaceElevated,
                      borderRadius: BorderRadius.circular(PreviewTheme.buttonRadius),
                      border: Border.all(color: PreviewTheme.borderSubtle),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: _config.synthesisNoteThreshold,
                        dropdownColor: PreviewTheme.surfaceElevated,
                        isDense: true,
                        icon: const Icon(Icons.arrow_drop_down,
                            color: PreviewTheme.accentAction, size: 20),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: PreviewTheme.textPrimary,
                        ),
                        items: const [1, 2, 3, 5, 8, 10].map((count) {
                          return DropdownMenuItem<int>(
                            value: count,
                            child: Text('$count ${count == 1 ? 'note' : 'notes'}'),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(
                                () => _config = _config.copyWith(synthesisNoteThreshold: val));
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 20, color: PreviewTheme.borderSubtle),

              // Threshold 2: Trigger after Y minutes of session quiet
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Trigger After Y Minutes Quiet',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: PreviewTheme.textPrimary,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Session quiet window since last capture',
                          style: TextStyle(fontSize: 12, color: PreviewTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    key: const Key('synthesis_inactivity_minutes_dropdown'),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    decoration: BoxDecoration(
                      color: PreviewTheme.surfaceElevated,
                      borderRadius: BorderRadius.circular(PreviewTheme.buttonRadius),
                      border: Border.all(color: PreviewTheme.borderSubtle),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: _config.synthesisInactivityMinutes,
                        dropdownColor: PreviewTheme.surfaceElevated,
                        isDense: true,
                        icon: const Icon(Icons.arrow_drop_down,
                            color: PreviewTheme.accentAction, size: 20),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: PreviewTheme.textPrimary,
                        ),
                        items: const [5, 10, 15, 30, 45, 60].map((mins) {
                          return DropdownMenuItem<int>(
                            value: mins,
                            child: Text('$mins mins'),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() =>
                                _config = _config.copyWith(synthesisInactivityMinutes: val));
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 20, color: PreviewTheme.borderSubtle),

              // Buffer Status & Instant Override Trigger
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: PreviewTheme.background.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: PreviewTheme.borderSubtle),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.inventory_2_outlined,
                        size: 20, color: PreviewTheme.accentAction),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$_unprocessedBufferCount Unprocessed Thoughts in Buffer',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: PreviewTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Will auto-cluster when threshold is met',
                            style: TextStyle(fontSize: 11, color: PreviewTheme.textTertiary),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      key: const Key('trigger_synthesis_now_btn'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: PreviewTheme.accentAction,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(PreviewTheme.badgeRadius)),
                      ),
                      onPressed: _unprocessedBufferCount > 0 ? _triggerSynthesisNow : null,
                      child: const Text(
                        'Synthesize Now',
                        style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Section 3: Calendar Synchronization
          _buildSectionHeader('CALENDAR SYNCHRONIZATION'),
          _buildCard(
            children: [
              _buildSwitchRow(
                title: 'Sync Action Items with Calendar',
                subtitle: 'Automatically schedule extracted commitments as time blocks',
                value: _config.isCalendarSyncEnabled,
                onChanged: (val) =>
                    setState(() => _config = _config.copyWith(isCalendarSyncEnabled: val)),
              ),
              const Divider(height: 20, color: PreviewTheme.borderSubtle),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text(
                      'Active Calendar Provider',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600, color: PreviewTheme.textPrimary),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _config.calendarProvider,
                    style: const TextStyle(fontSize: 13, color: PreviewTheme.accentAction),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text(
                      'Target Calendar',
                      style: TextStyle(fontSize: 13, color: PreviewTheme.textSecondary),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _config.targetCalendar,
                    style: const TextStyle(fontSize: 12, color: PreviewTheme.textTertiary),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Section 4: Audio Capture Storage
          _buildSectionHeader('AUDIO CAPTURE STORAGE'),
          _buildCard(
            children: [
              _buildSwitchRow(
                title: 'Keep Raw Audio Files',
                subtitle: 'Retain original WAV voice audio alongside cleaned transcripts',
                value: _config.keepRawWav,
                onChanged: (val) => setState(() => _config = _config.copyWith(keepRawWav: val)),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Section 5: Device Thermal & RAM Telemetry
          _buildSectionHeader('ON-DEVICE AI MEMORY & THERMAL GATING'),
          _buildCard(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text(
                      'Thermal Headroom',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600, color: PreviewTheme.textPrimary),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: PreviewTheme.accentCapture.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${_config.thermalHeadroomPercent}% (Nominal)',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: PreviewTheme.accentCapture,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 20, color: PreviewTheme.borderSubtle),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'On-Device AI Model Footprint',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: PreviewTheme.textPrimary),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Inactivity eviction timer: 02:44 (to <60MB)',
                          style: TextStyle(fontSize: 12, color: PreviewTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _config.ramFootprint,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: PreviewTheme.accentWarning,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                key: const Key('evict_models_btn'),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: PreviewTheme.borderSubtle),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _evictModelsNow,
                child: const Center(
                  child: Text(
                    'Evict Models Now (<60 MB)',
                    style: TextStyle(color: PreviewTheme.textSecondary, fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Section 6: Diagnostic Logging
          _buildSectionHeader('DIAGNOSTIC LOGGING (2MB ROTATING)'),
          _buildCard(
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildLogButton('View Live Logs', Icons.visibility_outlined, () {}),
                  _buildLogButton('Copy Dump', Icons.copy_outlined, () {}),
                  _buildLogButton('Clear Logs', Icons.delete_outline, () {}),
                ],
              ),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.9,
          color: PreviewTheme.textSecondary.withValues(alpha: 0.7),
        ),
      ),
    );
  }

  Widget _buildCard({required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: PreviewTheme.surface,
        borderRadius: BorderRadius.circular(PreviewTheme.cardRadius),
        border: Border.all(color: PreviewTheme.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildStatusRow({
    required String title,
    required String subtitle,
    required String badgeText,
    required bool isSuccess,
  }) {
    final badgeColor = isSuccess ? PreviewTheme.accentCapture : PreviewTheme.accentWarning;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: PreviewTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 12, color: PreviewTheme.textSecondary),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: badgeColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(PreviewTheme.badgeRadius),
            border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
          ),
          child: Text(
            badgeText,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: badgeColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSwitchRow({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: PreviewTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 12, color: PreviewTheme.textSecondary),
              ),
            ],
          ),
        ),
        Switch.adaptive(
          value: value,
          activeTrackColor: PreviewTheme.accentAction,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildLogButton(String label, IconData icon, VoidCallback onTap) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: PreviewTheme.borderSubtle),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      icon: Icon(icon, size: 14, color: PreviewTheme.textSecondary),
      label: Text(label, style: const TextStyle(fontSize: 11, color: PreviewTheme.textSecondary)),
      onPressed: onTap,
    );
  }
}
