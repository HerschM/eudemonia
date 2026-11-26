import 'package:flutter/material.dart';
import 'package:eudemonia/features/models/domain/model_availability.dart';
import 'package:eudemonia/features/models/domain/model_catalogue.dart';
import 'package:eudemonia/features/models/presentation/model_setup_view.dart';
import 'package:eudemonia/features/models/presentation/model_setup_view_data.dart';
import '../mock_data.dart';
import '../preview_theme.dart';

/// On-device models screen driven by mock scenarios. It renders the production
/// [ModelSetupView]; the buttons only move the mock state (a download jumps to "downloading").
class ModelSetupPreview extends StatefulWidget {
  final int initialScenario;

  const ModelSetupPreview({super.key, this.initialScenario = 0});

  @override
  State<ModelSetupPreview> createState() => _ModelSetupPreviewState();
}

class _ModelSetupPreviewState extends State<ModelSetupPreview> {
  late final List<MockModelScenario> _scenarios = MockData.modelScenarios;
  late int _index = widget.initialScenario;
  late Map<String, ModelAvailability> _availability;
  String? _selectedId;
  bool _wifiOnly = true;

  MockModelScenario get _scenario => _scenarios[_index];

  @override
  void initState() {
    super.initState();
    _load(_index);
  }

  void _load(int index) {
    _index = index;
    _availability = Map.of(_scenario.availability);
    _selectedId = _scenario.selectedLanguageModelId;
  }

  ModelAvailability _of(String id) => _availability[id] ?? ModelAvailability.absent;

  void _downloadStarted(String id) {
    final spec = ModelCatalogue.byId(id)!;
    setState(() => _availability[id] = ModelAvailability(
          ModelAvailabilityKind.downloading,
          downloadedBytes: spec.totalBytes ~/ 3,
          totalBytes: spec.totalBytes,
        ));
  }

  @override
  Widget build(BuildContext context) {
    final data = ModelSetupData.build(
      loading: false,
      totalRamMb: _scenario.totalRamMb,
      availabilityOf: _of,
      selectedLanguageModelId: _selectedId,
      wifiOnly: _wifiOnly,
      includeCandidates: true,
    );
    return Scaffold(
      backgroundColor: PreviewTheme.background,
      appBar: AppBar(
        backgroundColor: PreviewTheme.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          key: const Key('model_setup_preview_back'),
          icon: const Icon(Icons.arrow_back, color: PreviewTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'On-device models',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: PreviewTheme.textPrimary),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Wrap(
              spacing: 6,
              runSpacing: 0,
              children: [
                for (var i = 0; i < _scenarios.length; i++)
                  ChoiceChip(
                    key: Key('model_scenario_$i'),
                    label: Text(_scenarios[i].label, style: const TextStyle(fontSize: 11)),
                    selected: i == _index,
                    onSelected: (_) => setState(() => _load(i)),
                  ),
              ],
            ),
          ),
          Expanded(
            child: ModelSetupView(
              data: data,
              onDownload: _downloadStarted,
              onCancel: (id) => setState(() => _availability.remove(id)),
              onDelete: (id) => setState(() {
                _availability.remove(id);
                if (_selectedId == id) _selectedId = null;
              }),
              onSelect: (id) => setState(() => _selectedId = id),
              onWifiOnlyChanged: (value) => setState(() => _wifiOnly = value),
            ),
          ),
        ],
      ),
    );
  }
}
