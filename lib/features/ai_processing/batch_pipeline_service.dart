import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eudemonia/features/ai_processing/audio_recording_service.dart';
import 'package:eudemonia/features/ai_processing/stt_service.dart';
import 'package:eudemonia/features/ai_processing/llm_service.dart';
import 'package:eudemonia/features/ai_processing/model_lifecycle_manager.dart';
import 'package:eudemonia/features/notes/data/notes_repository.dart';
import 'package:eudemonia/features/notes/data/note_model.dart';

class BatchPipelineService {
  final AudioRecordingService _audioService;
  final STTService _sttService;
  final LLMService _llmService;
  final ModelLifecycleManager _modelLifecycle;
  final NotesRepository _notesRepo;

  BatchPipelineService(
    this._audioService,
    this._sttService,
    this._llmService,
    this._modelLifecycle,
    this._notesRepo,
  );

  Future<void> startRecording() async {
    // 1. Start audio recording
    await _audioService.startRecording();
    // 2. Proactively warm up models in the background while user is speaking
    _modelLifecycle.warmupOnRecordingStart();
  }

  Future<void> stopRecordingAndProcess() async {
    final audioPath = await _audioService.stopRecording();

    if (audioPath != null) {
      print('Audio saved to: $audioPath');

      try {
        // Ensure models are loaded (awaits proactive warmup if still completing)
        await _modelLifecycle.ensureModelsLoaded(reason: 'Process audio note');

        // 1. Convert Speech to Text
        print('Transcribing audio...');
        final rawTranscription = await _sttService.transcribe(audioPath);
        print('Raw transcription: "$rawTranscription"');

        if (rawTranscription.trim().isEmpty) {
          print('No speech detected in audio recording.');
          return;
        }

        // 2. Process with LLM for cleanup and categorization
        print('Processing transcription with LLM...');
        final llmResponse = await _llmService.processText(rawTranscription);

        // 3. Save to Isar Database
        final note = Note()
          ..rawText = rawTranscription
          ..correctedText = llmResponse.correctedText
          ..folder = llmResponse.folder
          ..createdAt = DateTime.now()
          ..originalAudioPath = audioPath;

        await _notesRepo.saveNote(note);
        print('Note saved successfully to database in folder: "${llmResponse.folder}"');
      } catch (e, stack) {
        print('Pipeline Error: $e');
        print('Pipeline Stack: $stack');
      } finally {
        // Start or reset inactivity eviction countdown timer
        _modelLifecycle.touch(reason: 'Finished processing audio note');
      }
    } else {
      print('Audio recording failed, path is null');
      _modelLifecycle.touch(reason: 'Recording cancelled or empty');
    }
  }
}

final batchPipelineProvider = Provider<BatchPipelineService>((ref) {
  final audioService = ref.watch(audioRecordingServiceProvider);
  final sttService = ref.watch(sttServiceProvider);
  final llmService = ref.watch(llmServiceProvider);
  final modelLifecycle = ref.watch(modelLifecycleManagerProvider);
  final notesRepo = ref.watch(notesRepositoryProvider);
  return BatchPipelineService(
    audioService,
    sttService,
    llmService,
    modelLifecycle,
    notesRepo,
  );
});

