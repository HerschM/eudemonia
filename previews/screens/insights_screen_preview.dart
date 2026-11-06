import 'package:flutter/material.dart';
import '../mock_data.dart';
import '../preview_theme.dart';

class InsightsScreenPreview extends StatefulWidget {
  const InsightsScreenPreview({super.key});

  @override
  State<InsightsScreenPreview> createState() => _InsightsScreenPreviewState();
}

class _InsightsScreenPreviewState extends State<InsightsScreenPreview> {
  String _activeSubView = 'Emotion Map';
  final List<String> _subViews = const ['Emotion Map', 'Topic Density', 'Recurrent Loops'];
  late MockInsightsData _insightsData;

  @override
  void initState() {
    super.initState();
    _insightsData = MockData.insightsData;
  }

  Color _getValenceColor(double valence) {
    if (valence >= 0.4) {
      return PreviewTheme.accentCapture; // Green
    } else if (valence >= 0.0) {
      return PreviewTheme.accentWarning; // Yellow
    } else {
      return const Color(0xFFC084FC); // Purple
    }
  }

  void _triggerCoherenceBreath() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: PreviewTheme.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(PreviewTheme.modalRadius)),
        title: const Row(
          children: [
            Icon(Icons.spa, color: PreviewTheme.accentCapture),
            SizedBox(width: 8),
            Text(
              'Coherence Breath',
              style: TextStyle(color: PreviewTheme.textPrimary, fontSize: 18),
            ),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Somatic parasympathetic reset activated.',
              style: TextStyle(color: PreviewTheme.textPrimary, fontSize: 14),
            ),
            SizedBox(height: 12),
            Text(
              'Breathe in for 4 seconds, hold for 4 seconds, and exhale for 6 seconds with haptic sync.',
              style: TextStyle(color: PreviewTheme.textSecondary, fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: PreviewTheme.accentCapture)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: PreviewTheme.background,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        children: [
          // Sub-View Segmented Selector
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _subViews.map((subView) {
                final isSelected = _activeSubView == subView;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text(subView),
                    selected: isSelected,
                    selectedColor: PreviewTheme.accentAction.withValues(alpha: 0.2),
                    backgroundColor: PreviewTheme.surfaceElevated,
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected ? PreviewTheme.accentAction : PreviewTheme.textSecondary,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(PreviewTheme.pillRadius),
                      side: BorderSide(
                        color: isSelected ? PreviewTheme.accentAction : PreviewTheme.borderSubtle,
                      ),
                    ),
                    onSelected: (val) {
                      if (val) {
                        setState(() => _activeSubView = subView);
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),
        ),
          const SizedBox(height: 8),
          // Active Sub-View Body
          if (_activeSubView == 'Emotion Map') ...[
            _buildEmotionMap(),
          ] else if (_activeSubView == 'Topic Density') ...[
            _buildTopicDensity(),
          ] else ...[
            _buildRecurrentLoops(),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildEmotionMap() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Card: Weekly Climate Summary
        Container(
          padding: const EdgeInsets.all(16),
          decoration: PreviewTheme.cardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'WEEKLY EMOTIONAL VALENCE & CLIMATE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                  color: PreviewTheme.textSecondary.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Dominant State: ${_insightsData.dominantState}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: PreviewTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              // 7-Day Valence Row
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: _insightsData.weeklyValence.map((day) {
                    final color = _getValenceColor(day.valence);
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: Column(
                        children: [
                          Text(
                            day.dayLabel,
                            style: const TextStyle(
                              fontSize: 11,
                              color: PreviewTheme.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.18),
                              shape: BoxShape.circle,
                              border: Border.all(color: color, width: 1.5),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              day.valence >= 0 ? '+${day.valence.toStringAsFixed(1)}' : day.valence.toStringAsFixed(1),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: color,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            day.moodSummary,
                            style: TextStyle(
                              fontSize: 9,
                              color: PreviewTheme.textTertiary.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Energy Breakdown Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: PreviewTheme.cardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'COGNITIVE ENERGY BREAKDOWN',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                  color: PreviewTheme.textSecondary.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 12),
              _buildEnergyRow(Icons.lightbulb_outline, '58% Creative Architecture', PreviewTheme.accentAI),
              const SizedBox(height: 8),
              _buildEnergyRow(Icons.business_center_outlined, '28% Logistics & Coordination', PreviewTheme.accentAction),
              const SizedBox(height: 8),
              _buildEnergyRow(Icons.spa_outlined, '14% Somatic Reflection & Rest', PreviewTheme.accentCapture),
            ],
          ),
        ),
        const SizedBox(height: 20),
        // Coherence Breath Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: PreviewTheme.surfaceElevated,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(PreviewTheme.buttonRadius),
                side: const BorderSide(color: PreviewTheme.borderSubtle),
              ),
            ),
            icon: const Icon(Icons.spa, color: PreviewTheme.accentCapture),
            label: const Text(
              '2-Minute Coherence Breath',
              style: TextStyle(color: PreviewTheme.textPrimary, fontWeight: FontWeight.w600),
            ),
            onPressed: _triggerCoherenceBreath,
          ),
        ),
      ],
    );
  }

  Widget _buildEnergyRow(IconData icon, String text, Color color) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 13, color: PreviewTheme.textPrimary),
          ),
        ),
      ],
    );
  }

  Widget _buildTopicDensity() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: PreviewTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TOPIC COGNITIVE DENSITY',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
              color: PreviewTheme.textSecondary.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 16),
          ..._insightsData.topicDensity.entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(entry.key, style: const TextStyle(fontSize: 13, color: PreviewTheme.textPrimary)),
                      Text('${(entry.value * 100).toInt()}%',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: PreviewTheme.textSecondary)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: entry.value,
                      backgroundColor: PreviewTheme.surfaceElevated,
                      valueColor: const AlwaysStoppedAnimation<Color>(PreviewTheme.accentAction),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildRecurrentLoops() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: PreviewTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'RECURRENT THOUGHT PATTERNS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
              color: PreviewTheme.textSecondary.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 12),
          ..._insightsData.recurrentPatterns.map((pattern) {
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: PreviewTheme.surfaceElevated,
                borderRadius: BorderRadius.circular(PreviewTheme.buttonRadius),
                border: Border.all(color: PreviewTheme.borderSubtle),
              ),
              child: Row(
                children: [
                  const Icon(Icons.repeat, color: PreviewTheme.accentAI, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '"${pattern.phrase}"',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: PreviewTheme.textPrimary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Mentioned ${pattern.frequencyCount} times across ${pattern.sessionCount} sessions',
                          style: const TextStyle(fontSize: 11, color: PreviewTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, size: 16, color: PreviewTheme.textTertiary),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
