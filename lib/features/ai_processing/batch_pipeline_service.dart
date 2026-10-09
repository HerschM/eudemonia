import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eudemonia/features/ai_processing/audio_recording_service.dart';
import 'package:eudemonia/features/ai_processing/stt_service.dart';
import 'package:eudemonia/features/ai_processing/llm_service.dart';
import 'package:eudemonia/features/notes/data/notes_repository.dart';
import 'package:eudemonia/features/notes/data/note_model.dart';
import 'package:path_provider/path_provider.dart';

class BatchPipelineService {
  final AudioRecordingService _audioService;
  final STTService _sttService;
  final LLMService _llmService;
  final NotesRepository _notesRepo;
  BatchPipelineService(this._audioService, this._sttService, this._llmService, this._notesRepo);

  Future<void> startRecording() async {
    await _audioService.startRecording();
  }

  Future<void> stopRecordingAndProcess() async {
    final audioPath = await _audioService.stopRecording();
    
    if (audioPath != null) {
      print('Audio saved to: $audioPath');
      
      try {
        // Find the models directory (using external storage directory on Android where models were pushed)
        final directory = await getExternalStorageDirectory();
        if (directory == null) throw Exception("Could not find external storage directory.");
        
        print('Initializing STT & LLM with models at ${directory.path}...');
        // Lazy initialize STT and LLM services
        await _sttService.initialize('${directory.path}/parakeet');
        await _llmService.initialize('${directory.path}/qwen2.5-1.5b.gguf');

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
        print('Cleaned text: ${llmResponse.correctedText}');
        print('Category: ${llmResponse.folder}');

        // 3. Save to Isar Database
        final note = Note()
          ..rawText = rawTranscription
          ..correctedText = llmResponse.correctedText
          ..folder = llmResponse.folder
          ..createdAt = DateTime.now()
          ..originalAudioPath = audioPath;
          
        await _notesRepo.saveNote(note);
        print('Note saved successfully to database!');
        
      } catch (e, stack) {
        print('Pipeline Error: $e');
        print('Pipeline Stack: $stack');
      }
    } else {
      print('Audio recording failed, path is null');
    }
  }
}

final batchPipelineProvider = Provider<BatchPipelineService>((ref) {
  final audioService = ref.watch(audioRecordingServiceProvider);
  final sttService = ref.watch(sttServiceProvider);
  final llmService = ref.watch(llmServiceProvider);
  final notesRepo = ref.watch(notesRepositoryProvider);
  return BatchPipelineService(audioService, sttService, llmService, notesRepo);
});
