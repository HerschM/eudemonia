import 'package:flutter/material.dart';

/// Helper to format date then time: "DD/MM  HH:MM AM/PM"
String formatDateTimeCustom(DateTime dt) {
  final day = dt.day.toString().padLeft(2, '0');
  final month = dt.month.toString().padLeft(2, '0');
  final hour12 = dt.hour == 0
      ? 12
      : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
  final hourStr = hour12.toString().padLeft(2, '0');
  final minuteStr = dt.minute.toString().padLeft(2, '0');
  final amPm = dt.hour >= 12 ? 'PM' : 'AM';
  return '$day/$month  $hourStr:$minuteStr $amPm';
}

/// Processing status of a capture note
enum MockNoteStatus {
  pending, // Yellow - Transcribing audio / queue worker pending
  processed, // Blue - STT + language cleanup done; awaiting synthesis
  synthesized, // Green - Clustered and synthesized into a session note
  failed, // Red - Processing error
}

/// Raw Capture thought item
class MockCaptureNote {
  final String id;
  final int dailySequenceNumber;
  final DateTime timestamp;
  final String audioFilePath;
  final Duration audioDuration;
  final String cleanedText;
  final bool isUnread;
  final MockNoteStatus status;
  final String? clusterSequence; // e.g. "#S-02" if synthesized
  final String? failureMessage; // If failed

  const MockCaptureNote({
    required this.id,
    required this.dailySequenceNumber,
    required this.timestamp,
    required this.audioFilePath,
    required this.audioDuration,
    required this.cleanedText,
    required this.isUnread,
    this.status = MockNoteStatus.processed,
    this.clusterSequence,
    this.failureMessage,
  });

  String get formattedSequence => '#${dailySequenceNumber.toString().padLeft(2, '0')}';
  String get formattedTimestamp => formatDateTimeCustom(timestamp);
  String get formattedAudioDuration {
    final m = audioDuration.inMinutes.toString().padLeft(2, '0');
    final s = (audioDuration.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  MockCaptureNote copyWith({
    String? cleanedText,
    bool? isUnread,
    MockNoteStatus? status,
    String? clusterSequence,
    String? failureMessage,
  }) {
    return MockCaptureNote(
      id: id,
      dailySequenceNumber: dailySequenceNumber,
      timestamp: timestamp,
      audioFilePath: audioFilePath,
      audioDuration: audioDuration,
      cleanedText: cleanedText ?? this.cleanedText,
      isUnread: isUnread ?? this.isUnread,
      status: status ?? this.status,
      clusterSequence: clusterSequence ?? this.clusterSequence,
      failureMessage: failureMessage ?? this.failureMessage,
    );
  }
}

/// Synthesis cluster item
class MockSynthesisCluster {
  final String clusterId;
  final String sequenceNumber; // e.g. "#S-02"
  final String folder; // Predefined folder e.g. "Ideas", "Work", "Todos", "Journal"
  final String synthesizedContent;
  final DateTime sessionStart;
  final DateTime sessionEnd;
  final Duration sessionDuration;
  final List<MockCaptureNote> originNotes;
  final bool isExpanded;
  final bool isReprocessing; // True when marked yellow for re-synthesis
  final String appliedStyleId; // e.g. "concise", "bullets", "professional", etc.
  final bool isUnread; // Toggles electric blue unread indicator dot
  final bool isActionExtracted; // True when action extraction pass completed (Green)

  const MockSynthesisCluster({
    required this.clusterId,
    required this.sequenceNumber,
    required this.folder,
    required this.synthesizedContent,
    required this.sessionStart,
    required this.sessionEnd,
    required this.sessionDuration,
    required this.originNotes,
    this.isExpanded = false,
    this.isReprocessing = false,
    this.appliedStyleId = 'concise',
    this.isUnread = false,
    this.isActionExtracted = true,
  });

  MockSynthesisCluster copyWith({
    String? folder,
    String? synthesizedContent,
    List<MockCaptureNote>? originNotes,
    bool? isExpanded,
    bool? isReprocessing,
    String? appliedStyleId,
    bool? isUnread,
    bool? isActionExtracted,
  }) {
    return MockSynthesisCluster(
      clusterId: clusterId,
      sequenceNumber: sequenceNumber,
      folder: folder ?? this.folder,
      synthesizedContent: synthesizedContent ?? this.synthesizedContent,
      sessionStart: sessionStart,
      sessionEnd: sessionEnd,
      sessionDuration: sessionDuration,
      originNotes: originNotes ?? this.originNotes,
      isExpanded: isExpanded ?? this.isExpanded,
      isReprocessing: isReprocessing ?? this.isReprocessing,
      appliedStyleId: appliedStyleId ?? this.appliedStyleId,
      isUnread: isUnread ?? this.isUnread,
      isActionExtracted: isActionExtracted ?? this.isActionExtracted,
    );
  }

  String get formattedTimeSpan {
    final startDay = sessionStart.day.toString().padLeft(2, '0');
    final startMonth = sessionStart.month.toString().padLeft(2, '0');
    final startH12 = sessionStart.hour == 0
        ? 12
        : (sessionStart.hour > 12 ? sessionStart.hour - 12 : sessionStart.hour);
    final startHStr = startH12.toString().padLeft(2, '0');
    final startMStr = sessionStart.minute.toString().padLeft(2, '0');
    final startAmPm = sessionStart.hour >= 12 ? 'PM' : 'AM';

    final endH12 = sessionEnd.hour == 0
        ? 12
        : (sessionEnd.hour > 12 ? sessionEnd.hour - 12 : sessionEnd.hour);
    final endHStr = endH12.toString().padLeft(2, '0');
    final endMStr = sessionEnd.minute.toString().padLeft(2, '0');
    final endAmPm = sessionEnd.hour >= 12 ? 'PM' : 'AM';

    return '$startDay/$startMonth  $startHStr:$startMStr $startAmPm - $endHStr:$endMStr $endAmPm';
  }
}

/// AI Style Re-Writer preset item
class MockStylePreset {
  final String id;
  final String name;
  final IconData icon;
  final String prompt;
  final String outputFormat;

  const MockStylePreset({
    required this.id,
    required this.name,
    required this.icon,
    required this.prompt,
    required this.outputFormat,
  });
}

/// Action item commitment
class MockActionItem {
  final String id;
  final String description;
  final String temporalAnchor; // "05/11  02:00 PM"
  final String urgency; // "High", "Normal", "Low"
  final String originSessionId;
  final String originSessionTitle;
  final bool isCompleted;

  const MockActionItem({
    required this.id,
    required this.description,
    required this.temporalAnchor,
    required this.urgency,
    required this.originSessionId,
    required this.originSessionTitle,
    this.isCompleted = false,
  });

  MockActionItem copyWith({bool? isCompleted}) {
    return MockActionItem(
      id: id,
      description: description,
      temporalAnchor: temporalAnchor,
      urgency: urgency,
      originSessionId: originSessionId,
      originSessionTitle: originSessionTitle,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}

/// Calendar time block item
class MockCalendarTimeBlock {
  final String id;
  final String title;
  final String timeRange; // "14:00 - 15:00"
  final String date;

  const MockCalendarTimeBlock({
    required this.id,
    required this.title,
    required this.timeRange,
    required this.date,
  });
}

/// Insights day valence item
class MockDayValence {
  final String dayLabel; // "Mon", "Tue"
  final double valence; // -1.0 to +1.0
  final String moodSummary;

  const MockDayValence({
    required this.dayLabel,
    required this.valence,
    required this.moodSummary,
  });
}

/// Recurrent thought pattern item
class MockRecurrentPattern {
  final String id;
  final String phrase;
  final int frequencyCount;
  final int sessionCount;

  const MockRecurrentPattern({
    required this.id,
    required this.phrase,
    required this.frequencyCount,
    required this.sessionCount,
  });
}

/// Insights combined data package
class MockInsightsData {
  final List<MockDayValence> weeklyValence;
  final String dominantState;
  final Map<String, double> topicDensity;
  final List<MockRecurrentPattern> recurrentPatterns;

  const MockInsightsData({
    required this.weeklyValence,
    required this.dominantState,
    required this.topicDensity,
    required this.recurrentPatterns,
  });
}

/// Pipeline status package for top bar and HUD modal
class MockPipelineStatus {
  final int captureTranscribingCount;
  final int synthesisReadyCount;
  final String insightsNextRefresh;
  final int actionPendingCount;

  const MockPipelineStatus({
    this.captureTranscribingCount = 1,
    this.synthesisReadyCount = 2,
    this.insightsNextRefresh = '14h',
    this.actionPendingCount = 0,
  });

  int get totalPending =>
      captureTranscribingCount + synthesisReadyCount + actionPendingCount;
  bool get hasActiveJobs => totalPending > 0;
}

/// Settings and batching configuration
class MockSettingsConfig {
  final bool isAccessibilityGranted;
  final bool isBatteryExemptGranted;
  final bool isForegroundKeepAlive;
  final int synthesisNoteThreshold; // X captures (default 3)
  final int synthesisInactivityMinutes; // Y minutes quiet (default 15)
  final bool isCalendarSyncEnabled;
  final String calendarProvider;
  final String targetCalendar;
  final bool autoSyncOnExtract;
  final bool keepRawWav;
  final int thermalHeadroomPercent;
  final String ramFootprint;
  final int evictionCountdownSeconds;

  const MockSettingsConfig({
    this.isAccessibilityGranted = true,
    this.isBatteryExemptGranted = true,
    this.isForegroundKeepAlive = true,
    this.synthesisNoteThreshold = 3,
    this.synthesisInactivityMinutes = 15,
    this.isCalendarSyncEnabled = true,
    this.calendarProvider = 'Google Calendar',
    this.targetCalendar = 'Personal (Default)',
    this.autoSyncOnExtract = true,
    this.keepRawWav = true,
    this.thermalHeadroomPercent = 84,
    this.ramFootprint = '1.58 GB',
    this.evictionCountdownSeconds = 164,
  });

  MockSettingsConfig copyWith({
    bool? isAccessibilityGranted,
    bool? isBatteryExemptGranted,
    bool? isForegroundKeepAlive,
    int? synthesisNoteThreshold,
    int? synthesisInactivityMinutes,
    bool? isCalendarSyncEnabled,
    String? calendarProvider,
    String? targetCalendar,
    bool? autoSyncOnExtract,
    bool? keepRawWav,
  }) {
    return MockSettingsConfig(
      isAccessibilityGranted:
          isAccessibilityGranted ?? this.isAccessibilityGranted,
      isBatteryExemptGranted:
          isBatteryExemptGranted ?? this.isBatteryExemptGranted,
      isForegroundKeepAlive:
          isForegroundKeepAlive ?? this.isForegroundKeepAlive,
      synthesisNoteThreshold:
          synthesisNoteThreshold ?? this.synthesisNoteThreshold,
      synthesisInactivityMinutes:
          synthesisInactivityMinutes ?? this.synthesisInactivityMinutes,
      isCalendarSyncEnabled:
          isCalendarSyncEnabled ?? this.isCalendarSyncEnabled,
      calendarProvider: calendarProvider ?? this.calendarProvider,
      targetCalendar: targetCalendar ?? this.targetCalendar,
      autoSyncOnExtract: autoSyncOnExtract ?? this.autoSyncOnExtract,
      keepRawWav: keepRawWav ?? this.keepRawWav,
      thermalHeadroomPercent: thermalHeadroomPercent,
      ramFootprint: ramFootprint,
      evictionCountdownSeconds: evictionCountdownSeconds,
    );
  }
}

/// Semantic Folder Manifesto representation
class MockFolderManifesto {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final int noteCount;
  final List<String> autoGeneratedKeywords;

  const MockFolderManifesto({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.noteCount,
    required this.autoGeneratedKeywords,
  });

  MockFolderManifesto copyWith({
    String? name,
    String? description,
    IconData? icon,
    int? noteCount,
    List<String>? autoGeneratedKeywords,
  }) {
    return MockFolderManifesto(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      noteCount: noteCount ?? this.noteCount,
      autoGeneratedKeywords:
          autoGeneratedKeywords ?? this.autoGeneratedKeywords,
    );
  }
}

/// Central MockData container with typed fixture datasets
class MockData {
  static List<MockCaptureNote> get captureNotes => [
        MockCaptureNote(
          id: 'note_6',
          dailySequenceNumber: 6,
          timestamp: DateTime(2026, 11, 5, 10, 15),
          audioFilePath: '/audio/note_6.wav',
          audioDuration: const Duration(seconds: 5),
          cleanedText: 'Transcribing speech and cleaning language on-device...',
          isUnread: true,
          status: MockNoteStatus.pending,
        ),
        MockCaptureNote(
          id: 'note_5',
          dailySequenceNumber: 5,
          timestamp: DateTime(2026, 11, 5, 9, 58),
          audioFilePath: '/audio/note_5.wav',
          audioDuration: const Duration(seconds: 12),
          cleanedText: 'Audit the battery optimization exemption whitepaper for Samsung OneUI devices.',
          isUnread: true,
          status: MockNoteStatus.processed,
        ),
        MockCaptureNote(
          id: 'note_4',
          dailySequenceNumber: 4,
          timestamp: DateTime(2026, 11, 5, 9, 42),
          audioFilePath: '/audio/note_4.wav',
          audioDuration: const Duration(seconds: 8),
          cleanedText:
              'Need to verify whether the accessibility key debouncer works properly when device is locked.',
          isUnread: true,
          status: MockNoteStatus.processed,
        ),
        MockCaptureNote(
          id: 'note_3',
          dailySequenceNumber: 3,
          timestamp: DateTime(2026, 11, 5, 8, 15),
          audioFilePath: '/audio/note_3.wav',
          audioDuration: const Duration(seconds: 15),
          cleanedText:
              'The battery drain test passed with 1.8% over 24 hours with foreground keep-alive enabled.',
          isUnread: false,
          status: MockNoteStatus.synthesized,
          clusterSequence: '#S-01',
        ),
        MockCaptureNote(
          id: 'note_2',
          dailySequenceNumber: 2,
          timestamp: DateTime(2026, 11, 5, 7, 40),
          audioFilePath: '/audio/note_2.wav',
          audioDuration: const Duration(seconds: 2),
          cleanedText: 'Audio recording failed: background noise only.',
          isUnread: false,
          status: MockNoteStatus.failed,
          failureMessage: 'No speech detected in audio recording',
        ),
        MockCaptureNote(
          id: 'note_1',
          dailySequenceNumber: 1,
          timestamp: DateTime(2026, 11, 5, 7, 10),
          audioFilePath: '/audio/note_1.wav',
          audioDuration: const Duration(seconds: 4),
          cleanedText: 'Remember to pick up almond milk on the way back.',
          isUnread: false,
          status: MockNoteStatus.synthesized,
          clusterSequence: '#S-02',
        ),
      ];

  static List<MockSynthesisCluster> get synthesisClusters => [
        MockSynthesisCluster(
          clusterId: 'cluster_2',
          sequenceNumber: '#S-02',
          folder: 'Ideas',
          synthesizedContent:
              'Consolidated architectural roadmap for local speech clustering. Decided to separate raw inbox from synthesized notes to prevent clutter. Will implement SQLite vector indices.',
          sessionStart: DateTime(2026, 11, 5, 7, 10),
          sessionEnd: DateTime(2026, 11, 5, 7, 45),
          sessionDuration: const Duration(minutes: 35),
          originNotes: [
            MockCaptureNote(
              id: 'raw_1',
              dailySequenceNumber: 1,
              timestamp: DateTime(2026, 11, 5, 7, 12),
              audioFilePath: '/audio/raw_1.wav',
              audioDuration: const Duration(seconds: 4),
              cleanedText: 'Idea about splitting raw & processed notes into clear tabs.',
              isUnread: false,
            ),
            MockCaptureNote(
              id: 'raw_2',
              dailySequenceNumber: 2,
              timestamp: DateTime(2026, 11, 5, 7, 24),
              audioFilePath: '/audio/raw_2.wav',
              audioDuration: const Duration(seconds: 8),
              cleanedText: 'Need local embeddings for walk notes clustering.',
              isUnread: false,
            ),
            MockCaptureNote(
              id: 'raw_4',
              dailySequenceNumber: 4,
              timestamp: DateTime(2026, 11, 5, 7, 40),
              audioFilePath: '/audio/raw_4.wav',
              audioDuration: const Duration(seconds: 6),
              cleanedText: 'Performance should stay under 50ms latency.',
              isUnread: false,
            ),
          ],
          isExpanded: false,
          isUnread: true,
          isActionExtracted: true,
        ),
        MockSynthesisCluster(
          clusterId: 'cluster_1',
          sequenceNumber: '#S-01',
          folder: 'Work',
          synthesizedContent:
              'Prepare quarterly deliverables before 3 PM sync with Marcus and mobile engineering platform leads.',
          sessionStart: DateTime(2026, 11, 4, 16, 15),
          sessionEnd: DateTime(2026, 11, 4, 16, 27),
          sessionDuration: const Duration(minutes: 12),
          originNotes: [
            MockCaptureNote(
              id: 'raw_yesterday_1',
              dailySequenceNumber: 14,
              timestamp: DateTime(2026, 11, 4, 16, 15),
              audioFilePath: '/audio/raw_y1.wav',
              audioDuration: const Duration(seconds: 11),
              cleanedText: 'Sync with Marcus on deliverables before sprint review.',
              isUnread: false,
            ),
          ],
          isExpanded: false,
          isUnread: false,
          isActionExtracted: false,
        ),
      ];

  static MockPipelineStatus get pipelineStatus => const MockPipelineStatus();

  static MockSettingsConfig get settingsConfig => const MockSettingsConfig();

  static List<MockStylePreset> get stylePresets => const [
        MockStylePreset(
          id: 'concise',
          name: 'Concise & Direct',
          icon: Icons.bolt,
          prompt: 'Distill this thought into a punchy, 1-2 sentence core insight without fluff.',
          outputFormat: '1-2 punchy sentences',
        ),
        MockStylePreset(
          id: 'bullets',
          name: 'Bullet Points',
          icon: Icons.format_list_bulleted,
          prompt: 'Convert this thought into a structured, clear bulleted list highlighting key ideas.',
          outputFormat: 'Structured markdown bullets',
        ),
        MockStylePreset(
          id: 'professional',
          name: 'Professional',
          icon: Icons.business_center,
          prompt: 'Rewrite this thought in polished, professional business language suitable for work.',
          outputFormat: 'Formal prose',
        ),
        MockStylePreset(
          id: 'journal',
          name: 'Journal / Reflective',
          icon: Icons.spa,
          prompt: 'Rewrite with introspective, thoughtful prose preserving personal sentiment and nuances.',
          outputFormat: 'Reflective narrative',
        ),
        MockStylePreset(
          id: 'actionable',
          name: 'Actionable / Next Steps',
          icon: Icons.track_changes,
          prompt: 'Extract the concrete actionable intent and format as immediate clear next steps.',
          outputFormat: 'Concrete action steps',
        ),
        MockStylePreset(
          id: 'casual',
          name: 'Casual / Conversational',
          icon: Icons.chat_bubble_outline,
          prompt: 'Rewrite as a friendly, natural speaking-style personal note.',
          outputFormat: 'Conversational reflection',
        ),
      ];

  static List<MockActionItem> get actionItems => [
        const MockActionItem(
          id: 'act_1',
          description: 'Verify accessibility debouncer on locked phone',
          temporalAnchor: '05/11  02:00 PM',
          urgency: 'High',
          originSessionId: 'cluster_2',
          originSessionTitle: 'Synthesis [#S-02] Ideas',
          isCompleted: false,
        ),
        const MockActionItem(
          id: 'act_2',
          description: 'Buy replacement guitar strings (.010 gauge)',
          temporalAnchor: '06/11  10:00 AM',
          urgency: 'Normal',
          originSessionId: 'cluster_3',
          originSessionTitle: 'Synthesis [#S-03] Music Session',
          isCompleted: false,
        ),
        const MockActionItem(
          id: 'act_3',
          description: 'Review PR for background keep-alive service',
          temporalAnchor: '05/11  08:30 AM',
          urgency: 'Normal',
          originSessionId: 'cluster_1',
          originSessionTitle: 'Synthesis [#S-01] Work',
          isCompleted: true,
        ),
      ];

  static List<MockCalendarTimeBlock> get calendarTimeBlocks => const [
        MockCalendarTimeBlock(
          id: 'block_1',
          title: 'App Ideas: Accessibility Test',
          timeRange: '14:00 - 15:00',
          date: '05/11',
        ),
      ];

  static MockInsightsData get insightsData => MockInsightsData(
        weeklyValence: const [
          MockDayValence(dayLabel: 'Mon', valence: 0.7, moodSummary: 'Constructive'),
          MockDayValence(dayLabel: 'Tue', valence: 0.5, moodSummary: 'Steady'),
          MockDayValence(dayLabel: 'Wed', valence: 0.0, moodSummary: 'Neutral'),
          MockDayValence(dayLabel: 'Thu', valence: 0.8, moodSummary: 'Flow State'),
          MockDayValence(dayLabel: 'Fri', valence: -0.4, moodSummary: 'Depleted'),
          MockDayValence(dayLabel: 'Sat', valence: 0.6, moodSummary: 'Inspired'),
          MockDayValence(dayLabel: 'Sun', valence: 0.9, moodSummary: 'Peaceful'),
        ],
        dominantState: 'Focused & Constructive (+0.6 Valence)',
        topicDensity: const {
          'Ideas': 0.58,
          'Work': 0.28,
          'Journal': 0.14,
        },
        recurrentPatterns: const [
          MockRecurrentPattern(
            id: 'pattern_1',
            phrase: 'Memory optimization on low-end Android',
            frequencyCount: 4,
            sessionCount: 3,
          ),
          MockRecurrentPattern(
            id: 'pattern_2',
            phrase: 'Morning walk capture routine',
            frequencyCount: 3,
            sessionCount: 2,
          ),
        ],
      );

  static List<MockFolderManifesto> get folderManifestos => [
        const MockFolderManifesto(
          id: 'work',
          name: 'Work',
          description:
              'Professional projects, client meetings, technical architecture, and team coordination.',
          icon: Icons.business_center_outlined,
          noteCount: 4,
          autoGeneratedKeywords: [
            'flutter',
            'riverpod',
            'architecture',
            'sprint'
          ],
        ),
        const MockFolderManifesto(
          id: 'ideas',
          name: 'Ideas',
          description:
              'Creative concepts, startup brainstorms, design explorations, and product hypotheses.',
          icon: Icons.lightbulb_outline,
          noteCount: 2,
          autoGeneratedKeywords: [
            'voice-first',
            'ai-hud',
            'mobile',
            'on-device'
          ],
        ),
        const MockFolderManifesto(
          id: 'todos',
          name: 'Todos',
          description:
              'Action items, chores, errands, shopping lists, and immediate tasks to complete.',
          icon: Icons.check_circle_outline,
          noteCount: 3,
          autoGeneratedKeywords: ['guitar-strings', 'pr-review', 'groceries'],
        ),
        const MockFolderManifesto(
          id: 'journal',
          name: 'Journal',
          description:
              'Personal reflections, daily diary, gratitude, emotional check-ins, and health thoughts.',
          icon: Icons.spa_outlined,
          noteCount: 1,
          autoGeneratedKeywords: ['morning-walk', 'mist', 'grateful', 'sleep'],
        ),
        const MockFolderManifesto(
          id: 'eudemonia',
          name: 'Eudemonia',
          description:
              'Voice-first on-device capture app. Android native accessibility service, Qwen 2.5 LLM, Sherpa-ONNX STT.',
          icon: Icons.mic_none,
          noteCount: 6,
          autoGeneratedKeywords: [
            'debouncer',
            'foreground-service',
            'isar',
            'key-interceptor'
          ],
        ),
      ];
}
