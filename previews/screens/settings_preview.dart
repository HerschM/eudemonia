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
  late List<MockSettingsFolder> _folders;
  int _unprocessedBufferCount = 2;
  bool _memoryOpen = false;
  bool _permissionsOpen = false;

  @override
  void initState() {
    super.initState();
    _config = widget.initialConfig ?? MockData.settingsConfig;
    _folders = List.of(_config.folders);
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

  void _freeModelMemoryNow() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: PreviewTheme.surfaceElevated,
        content: const Text(
          'AI model memory freed.',
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
          'Settings',
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
          // 1. Folders synthesis files notes under: tap one to edit it
          _buildSectionHeader('FOLDERS'),
          _buildCard(
            padding: EdgeInsets.zero,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
                child: Text(
                  'Synthesis files each note in one of these folders. The description tells it what belongs there.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: PreviewTheme.textSecondary.withValues(alpha: 0.85),
                  ),
                ),
              ),
              Column(
                key: const Key('settings_folder_list'),
                children: [
                  for (final folder in _folders) _buildFolderRow(folder),
                ],
              ),
              const Divider(height: 1, color: PreviewTheme.borderSubtle),
              InkWell(
                key: const Key('settings_add_folder_row'),
                onTap: _folders.length >= 12 ? null : () => _editFolder(null),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Icon(Icons.add,
                          size: 20,
                          color: _folders.length >= 12 ? PreviewTheme.textTertiary : PreviewTheme.accentAction),
                      const SizedBox(width: 10),
                      Text(
                        'Add folder',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _folders.length >= 12 ? PreviewTheme.textTertiary : PreviewTheme.accentAction,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_folders.length >= 12)
                const Padding(
                  padding: EdgeInsets.fromLTRB(14, 0, 14, 14),
                  child: Text(
                    'You can have up to 12 folders.',
                    style: TextStyle(fontSize: 12, color: PreviewTheme.textSecondary),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),

          // 2. Automatic Synthesis Trigger & Batching Safeguards
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
          // 3. On-device models: opens the model setup preview (FR16)
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

          // 4. Capture: the widget and the background switch
          _buildSectionHeader('CAPTURE'),
          _buildCard(
            children: [
              const Row(
                children: [
                  Icon(Icons.widgets_outlined, color: PreviewTheme.accentCapture),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Add capture widget to home screen',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600, color: PreviewTheme.textPrimary),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'One tap on the home screen starts a capture.',
                          style: TextStyle(fontSize: 12, color: PreviewTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 24, color: PreviewTheme.borderSubtle),
              _buildSwitchRow(
                title: 'Keep capture ready in the background',
                subtitle:
                    'Keeps the Record button on your lock screen and finishes transcription and notes while the app is closed.',
                value: _config.isForegroundKeepAlive,
                onChanged: (val) =>
                    setState(() => _config = _config.copyWith(isForegroundKeepAlive: val)),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 5. Phone memory and temperature (collapsed)
          _buildCollapsible(
            headerKey: const Key('settings_memory_header'),
            title: 'PHONE MEMORY AND TEMPERATURE',
            open: _memoryOpen,
            onToggle: () => setState(() => _memoryOpen = !_memoryOpen),
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
                          'App Memory In Use',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: PreviewTheme.textPrimary),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'AI models loaded • inactivity eviction timer active',
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
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  key: const Key('evict_models_btn'),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: PreviewTheme.borderSubtle),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: _freeModelMemoryNow,
                  child: const Text(
                    'Free model memory now',
                    style: TextStyle(color: PreviewTheme.textSecondary, fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 6. Permissions (collapsed; amber badge when one is missing)
          _buildCollapsible(
            headerKey: const Key('settings_permissions_header'),
            title: 'PERMISSIONS',
            open: _permissionsOpen,
            onToggle: () => setState(() => _permissionsOpen = !_permissionsOpen),
            badge: (!_config.isMicrophoneGranted || !_config.areNotificationsEnabled)
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade300,
                      borderRadius: BorderRadius.circular(PreviewTheme.badgeRadius),
                    ),
                    child: const Text(
                      'Needs attention',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                  )
                : null,
            children: [
              _buildPermissionRow('Microphone', _config.isMicrophoneGranted),
              const Divider(height: 16, color: PreviewTheme.borderSubtle),
              _buildPermissionRow(
                  'Notifications (lock-screen Record button)', _config.areNotificationsEnabled),
            ],
          ),
          const SizedBox(height: 12),

          // 7. Licences: a small link, not a card
          Center(
            child: TextButton(
              key: const Key('settings_licences_link'),
              style: TextButton.styleFrom(foregroundColor: PreviewTheme.textSecondary),
              onPressed: () => showLicensePage(context: context, applicationName: 'Eudemonia'),
              child: const Text('Open-source licences', style: TextStyle(fontSize: 12.5)),
            ),
          ),
          const SizedBox(height: 24),
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

  Widget _buildCard({required List<Widget> children, EdgeInsetsGeometry padding = const EdgeInsets.all(16.0)}) {
    return Container(
      padding: padding,
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

  Widget _buildFolderRow(MockSettingsFolder folder) {
    final protected = folder.name == 'Uncategorized';
    return Column(
      children: [
        const Divider(height: 1, color: PreviewTheme.borderSubtle),
        InkWell(
          key: Key('settings_folder_row_${folder.name}'),
          onTap: () => _editFolder(folder),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        folder.name,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700, color: PreviewTheme.textPrimary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        folder.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12, height: 1.35, color: PreviewTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(protected ? Icons.lock_outline : Icons.edit_outlined,
                      size: 18, color: PreviewTheme.textTertiary),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Opens the folder editor sheet; [folder] null adds one. Uncategorized is read-only.
  void _editFolder(MockSettingsFolder? folder) {
    final protected = folder?.name == 'Uncategorized';
    final name = TextEditingController(text: folder?.name ?? '');
    final description = TextEditingController(text: folder?.description ?? '');
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: PreviewTheme.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(PreviewTheme.modalRadius)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                folder == null ? 'New folder' : (protected ? folder.name : 'Edit folder'),
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700, color: PreviewTheme.textPrimary),
              ),
              const SizedBox(height: 12),
              if (protected) ...[
                Text(folder!.description,
                    style: const TextStyle(fontSize: 14, color: PreviewTheme.textPrimary)),
                const SizedBox(height: 12),
                const Text(
                  'Catches whatever fits no other folder. It cannot be changed.',
                  style: TextStyle(fontSize: 12, color: PreviewTheme.textSecondary),
                ),
              ] else ...[
                TextField(
                  controller: name,
                  maxLength: 24,
                  style: const TextStyle(color: PreviewTheme.textPrimary),
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: description,
                  maxLength: 200,
                  minLines: 3,
                  maxLines: 6,
                  style: const TextStyle(color: PreviewTheme.textPrimary),
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  key: const Key('folder_save_button'),
                  style: ElevatedButton.styleFrom(backgroundColor: PreviewTheme.accentAction),
                  onPressed: () {
                    final next = MockSettingsFolder(
                        name: name.text.trim(), description: description.text.trim());
                    if (next.name.isEmpty) return;
                    setState(() {
                      if (folder == null) {
                        _folders.insert(_folders.length - 1, next);
                      } else {
                        _folders[_folders.indexOf(folder)] = next;
                      }
                    });
                    Navigator.pop(ctx);
                  },
                  child: const Text('Save', style: TextStyle(color: Colors.white)),
                ),
                if (folder != null)
                  TextButton(
                    key: const Key('folder_delete_button'),
                    onPressed: () {
                      setState(() => _folders.remove(folder));
                      Navigator.pop(ctx);
                    },
                    child: const Text('Delete folder', style: TextStyle(color: PreviewTheme.accentError)),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCollapsible({
    required Key headerKey,
    required String title,
    required bool open,
    required VoidCallback onToggle,
    required List<Widget> children,
    Widget? badge,
  }) {
    return Material(
      color: PreviewTheme.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(PreviewTheme.cardRadius),
        side: const BorderSide(color: PreviewTheme.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            key: headerKey,
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.9,
                        color: PreviewTheme.textSecondary.withValues(alpha: 0.9),
                      ),
                    ),
                  ),
                  if (badge != null) ...[badge, const SizedBox(width: 8)],
                  Icon(open ? Icons.expand_less : Icons.expand_more,
                      size: 22, color: PreviewTheme.textTertiary),
                ],
              ),
            ),
          ),
          if (open)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(children: children),
            ),
        ],
      ),
    );
  }

  Widget _buildPermissionRow(String title, bool granted) {
    return Row(
      children: [
        Icon(granted ? Icons.check_circle : Icons.error_outline,
            color: granted ? Colors.green : Colors.amber.shade700),
        const SizedBox(width: 12),
        Expanded(
          child: Text(title,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600, color: PreviewTheme.textPrimary)),
        ),
        Chip(
          label: Text(
            granted ? 'Enabled' : 'Disabled',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: granted ? Colors.green.shade900 : Colors.black87,
            ),
          ),
          backgroundColor: granted ? Colors.green.shade100 : Colors.amber.shade300,
        ),
      ],
    );
  }
}
