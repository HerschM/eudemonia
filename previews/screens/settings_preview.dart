import 'package:flutter/material.dart';
import '../mock_data.dart';
import '../preview_theme.dart';
import 'model_setup_preview.dart';

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
          // Section 1: Capture permissions
          _buildSectionHeader('CAPTURE PERMISSIONS'),
          _buildCard(
            children: [
              _buildSwitchRow(
                title: 'Keep capture ready in the background',
                subtitle: 'Keeps the Record button on your lock screen and finishes transcription and notes while the app is closed.',
                value: _config.isForegroundKeepAlive,
                onChanged: (val) =>
                    setState(() => _config = _config.copyWith(isForegroundKeepAlive: val)),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // On-device models: opens the model setup preview (FR16)
          _buildSectionHeader('ON-DEVICE MODELS'),
          _buildCard(
            children: [
              InkWell(
                key: const Key('settings_models_row'),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ModelSetupPreview()),
                ),
                child: const Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Speech model · Not downloaded',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600, color: PreviewTheme.textPrimary),
                      ),
                    ),
                    Icon(Icons.chevron_right, size: 20, color: PreviewTheme.textTertiary),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Section 2: Automatic Synthesis Trigger & Batching Safeguards
          _buildSectionHeader('AUTOMATIC SYNTHESIS'),
          _buildCard(
            children: [
              Text(
                'Synthesis turns waiting thoughts into notes by itself. Choose when it starts.',
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
                          'Start after this many thoughts',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: PreviewTheme.textPrimary,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Synthesis starts once this many thoughts are waiting.',
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
                          'Or after a quiet period',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: PreviewTheme.textPrimary,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Synthesis also starts when no new thought has arrived for this long.',
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
                            _unprocessedBufferCount == 0
                                ? 'No thoughts waiting'
                                : '$_unprocessedBufferCount ${_unprocessedBufferCount == 1 ? 'thought' : 'thoughts'} ready for Synthesis',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: PreviewTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Starts by itself when the settings above are met',
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

          // Folders synthesis files notes under (read-only)
          _buildSectionHeader('FOLDERS'),
          _buildCard(
            children: [
              Text(
                'Synthesis files each note in one of these folders.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: PreviewTheme.textSecondary.withValues(alpha: 0.85),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                key: const Key('settings_folder_list'),
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final name in const ['Work', 'Personal', 'Journal', 'Uncategorized'])
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: PreviewTheme.surfaceElevated,
                        borderRadius: BorderRadius.circular(PreviewTheme.badgeRadius),
                        border: Border.all(color: PreviewTheme.borderSubtle),
                      ),
                      child: Text(
                        name,
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600, color: PreviewTheme.textPrimary),
                      ),
                    ),
                ],
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
                          'Inactivity eviction timer: 01:44 (to <60MB)',
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
          const SizedBox(height: 20),

          // About
          _buildSectionHeader('ABOUT'),
          _buildCard(
            children: [
              InkWell(
                key: const Key('settings_licences_row'),
                onTap: () => showLicensePage(context: context, applicationName: 'Eudemonia'),
                child: const Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Licences and credits',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600, color: PreviewTheme.textPrimary),
                      ),
                    ),
                    Icon(Icons.chevron_right, size: 20, color: PreviewTheme.textTertiary),
                  ],
                ),
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
