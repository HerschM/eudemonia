import 'package:flutter_test/flutter_test.dart';
import '../../previews/mock_data.dart';

void main() {
  group('Preview MockData Unit Tests', () {
    test('MockData provides valid Capture raw notes with daily sequence numbers and status colors', () {
      final notes = MockData.captureNotes;
      expect(notes.isNotEmpty, isTrue);
      expect(notes.length, greaterThanOrEqualTo(6));

      // Note sequence checks
      expect(notes[0].dailySequenceNumber, equals(6));
      expect(notes[0].formattedSequence, equals('#06'));
      expect(notes[0].status, equals(MockNoteStatus.pending));

      expect(notes[1].dailySequenceNumber, equals(5));
      expect(notes[1].formattedSequence, equals('#05'));
      expect(notes[1].status, equals(MockNoteStatus.processed));

      expect(notes[2].dailySequenceNumber, equals(4));
      expect(notes[2].formattedSequence, equals('#04'));
      expect(notes[2].status, equals(MockNoteStatus.processed));

      expect(notes[3].dailySequenceNumber, equals(3));
      expect(notes[3].formattedSequence, equals('#03'));
      expect(notes[3].status, equals(MockNoteStatus.synthesized));

      expect(notes[4].dailySequenceNumber, equals(2));
      expect(notes[4].formattedSequence, equals('#02'));
      expect(notes[4].status, equals(MockNoteStatus.failed));

      expect(notes[5].dailySequenceNumber, equals(1));
      expect(notes[5].formattedSequence, equals('#01'));
      expect(notes[5].status, equals(MockNoteStatus.synthesized));

      // Verify all statuses are represented
      final statuses = notes.map((n) => n.status).toSet();
      expect(statuses, contains(MockNoteStatus.pending));
      expect(statuses, contains(MockNoteStatus.processed));
      expect(statuses, contains(MockNoteStatus.synthesized));
      expect(statuses, contains(MockNoteStatus.failed));

      // Verify timestamp format: DD/MM  HH:MM AM/PM
      for (final note in notes) {
        expect(note.formattedTimestamp, matches(r'^\d{2}/\d{2}\s\s\d{2}:\d{2}\s[AP]M$'));
        expect(note.cleanedText.isNotEmpty, isTrue);
        expect(note.audioDuration.inSeconds, greaterThan(0));
      }
    });

    test('MockData provides valid Synthesis clusters mapped to predefined folders', () {
      final clusters = MockData.synthesisClusters;
      expect(clusters.isNotEmpty, isTrue);

      for (final cluster in clusters) {
        expect(cluster.sequenceNumber, matches(r'^#S-\d{2}$'));
        expect(
          ['Work', 'Ideas', 'Todos', 'Journal', 'Uncategorized'],
          contains(cluster.folder),
          reason: 'Cluster folder must adhere to single-folder discipline',
        );
        expect(cluster.originNotes.isNotEmpty, isTrue);
        expect(cluster.synthesizedContent.isNotEmpty, isTrue);
        expect(cluster.formattedTimeSpan.isNotEmpty, isTrue);
        expect(cluster.sessionDuration.inMinutes, greaterThan(0));
        expect(cluster.appliedStyleId.isNotEmpty, isTrue);
      }
    });

    test('MockData provides exactly the 6 defined AI Style presets', () {
      final presets = MockData.stylePresets;
      expect(presets.length, equals(6));

      final presetNames = presets.map((p) => p.name).toList();
      expect(presetNames, contains('Concise & Direct'));
      expect(presetNames, contains('Bullet Points'));
      expect(presetNames, contains('Professional'));
      expect(presetNames, contains('Journal / Reflective'));
      expect(presetNames, contains('Actionable / Next Steps'));
      expect(presetNames, contains('Casual / Conversational'));

      for (final preset in presets) {
        expect(preset.prompt.isNotEmpty, isTrue);
        expect(preset.outputFormat.isNotEmpty, isTrue);
      }
    });

    test('MockData provides Action commitments and Calendar Time Blocks', () {
      final actions = MockData.actionItems;
      expect(actions.isNotEmpty, isTrue);

      for (final action in actions) {
        expect(action.description.isNotEmpty, isTrue);
        expect(action.temporalAnchor, matches(r'^\d{2}/\d{2}\s\s\d{2}:\d{2}\s[AP]M$'));
        expect(['High', 'Normal', 'Low'], contains(action.urgency));
        expect(action.originSessionId.isNotEmpty, isTrue);
      }

      final blocks = MockData.calendarTimeBlocks;
      expect(blocks.isNotEmpty, isTrue);
      for (final block in blocks) {
        expect(block.title.isNotEmpty, isTrue);
        expect(block.timeRange.isNotEmpty, isTrue);
      }
    });

    test('MockData provides Insights emotional valence, topic density, and recurrent loops', () {
      final insights = MockData.insightsData;
      expect(insights.weeklyValence.length, equals(7));

      for (final day in insights.weeklyValence) {
        expect(day.valence, inInclusiveRange(-1.0, 1.0));
        expect(day.dayLabel.isNotEmpty, isTrue);
      }

      expect(insights.topicDensity.isNotEmpty, isTrue);
      expect(insights.recurrentPatterns.isNotEmpty, isTrue);
      for (final pattern in insights.recurrentPatterns) {
        expect(pattern.phrase.isNotEmpty, isTrue);
        expect(pattern.frequencyCount, greaterThan(1));
      }
    });

    test('MockData provides AI Pipeline status telemetry across stages', () {
      final pipeline = MockData.pipelineStatus;
      expect(pipeline.captureTranscribingCount, equals(1));
      expect(pipeline.synthesisReadyCount, equals(2));
      expect(pipeline.actionPendingCount, equals(0));
      expect(pipeline.totalPending, equals(3));
      expect(pipeline.hasActiveJobs, isTrue);
      expect(pipeline.insightsNextRefresh, equals('14h'));

      final idlePipeline = const MockPipelineStatus(
        captureTranscribingCount: 0,
        synthesisReadyCount: 0,
        actionPendingCount: 0,
      );
      expect(idlePipeline.totalPending, equals(0));
      expect(idlePipeline.hasActiveJobs, isFalse);
    });

    test('MockData provides Settings and Batching Configuration thresholds', () {
      final settings = MockData.settingsConfig;
      expect(settings.isAccessibilityGranted, isTrue);
      expect(settings.isBatteryExemptGranted, isTrue);
      expect(settings.isForegroundKeepAlive, isTrue);
      expect(settings.synthesisNoteThreshold, equals(3));
      expect(settings.synthesisInactivityMinutes, equals(15));
      expect(settings.isCalendarSyncEnabled, isTrue);
      expect(settings.calendarProvider, equals('Google Calendar'));
      expect(settings.targetCalendar, equals('Personal (Default)'));
      expect(settings.autoSyncOnExtract, isTrue);
      expect(settings.thermalHeadroomPercent, equals(84));
      expect(settings.ramFootprint, equals('1.58 GB'));
      expect(settings.evictionCountdownSeconds, equals(164));
    });

    test('MockSynthesisCluster tracks unread indicator and action extraction completion', () {
      final clusters = MockData.synthesisClusters;
      expect(clusters.length, greaterThanOrEqualTo(2));

      // First cluster (#S-02) is unread and action extraction is complete (green)
      expect(clusters[0].isUnread, isTrue);
      expect(clusters[0].isActionExtracted, isTrue);

      // Second cluster (#S-01) is read and awaiting action extraction pass (blue)
      expect(clusters[1].isUnread, isFalse);
      expect(clusters[1].isActionExtracted, isFalse);
    });

    test('MockData provides semantic folder manifestos with descriptions and auto keywords', () {
      final manifestos = MockData.folderManifestos;
      expect(manifestos.length, equals(5));

      final names = manifestos.map((m) => m.name).toList();
      expect(names, containsAll(['Work', 'Ideas', 'Todos', 'Journal', 'Eudemonia']));

      for (final manifesto in manifestos) {
        expect(manifesto.id.isNotEmpty, isTrue);
        expect(manifesto.name.isNotEmpty, isTrue);
        expect(manifesto.description.isNotEmpty, isTrue);
        expect(manifesto.noteCount, greaterThan(0));
        expect(manifesto.autoGeneratedKeywords.isNotEmpty, isTrue);
      }
    });
  });
}

