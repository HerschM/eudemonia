/// The model files Eudemonia downloads, and the pure rules that decide which ones a phone can
/// use. Pure Dart, const data (FR16).
library;

import 'package:eudemonia/features/synthesis/domain/synthesis_model_profile.dart';

enum ModelKind { speech, language }

/// [listed] models are offered to every user; a [candidate] has not yet been measured to keep
/// the spoken details (FR16.4) and is shown in debug builds only.
enum ModelListing { listed, candidate }

class ModelFileSpec {
  /// Path below the app's external files directory, where the app loads the file from.
  final String relativePath;
  final String url;

  /// Lower-case hex SHA-256 of the complete file.
  final String sha256;
  final int sizeBytes;

  const ModelFileSpec({
    required this.relativePath,
    required this.url,
    required this.sha256,
    required this.sizeBytes,
  });
}

class ModelSpec {
  final String id;
  final ModelKind kind;
  final String displayName;
  final String qualityLine;
  final String memoryLine;
  final List<ModelFileSpec> files;

  /// Total device memory (MB, as the OS reports it) below which the model is not offered. 0 = any.
  final int minDeviceRamMb;

  /// The same requirement as printed on a phone's box ("8 GB"), for messages. A phone sold as
  /// 8 GB reports roughly 7.3-7.7 GB, which is why [minDeviceRamMb] sits below this figure.
  final int requiredNominalGb;
  final ModelListing listing;

  /// How synthesis uses the model; `null` for the speech model.
  final SynthesisModelProfile? profile;

  const ModelSpec({
    required this.id,
    required this.kind,
    required this.displayName,
    required this.qualityLine,
    required this.memoryLine,
    required this.files,
    required this.minDeviceRamMb,
    required this.requiredNominalGb,
    this.listing = ModelListing.listed,
    this.profile,
  });

  int get totalBytes => files.fold(0, (sum, f) => sum + f.sizeBytes);

  bool get isCandidate => listing == ModelListing.candidate;
}

class ModelCatalogue {
  const ModelCatalogue._();

  static const String _parakeetBase =
      'https://huggingface.co/csukuangfj/sherpa-onnx-nemo-parakeet-tdt-0.6b-v3-int8/resolve/'
      'ed5d745623472f97cfc2e6c2916ee248798fc5a8';

  static const ModelSpec speech = ModelSpec(
    id: 'parakeet-tdt-0.6b-v3-int8',
    kind: ModelKind.speech,
    displayName: 'Speech model',
    qualityLine: 'Turns your recordings into text.',
    memoryLine: 'Loaded only while transcribing',
    minDeviceRamMb: 0,
    requiredNominalGb: 0,
    files: [
      ModelFileSpec(
        relativePath: 'parakeet/encoder.int8.onnx',
        url: '$_parakeetBase/encoder.int8.onnx',
        sha256: '1afbe69c1ffdabee94755f42e4daf1d93549131a3da11356bda84fcef0f2c479',
        sizeBytes: 652282294,
      ),
      ModelFileSpec(
        relativePath: 'parakeet/decoder.int8.onnx',
        url: '$_parakeetBase/decoder.int8.onnx',
        sha256: '0222a86147299d4dee90edf95b6d13827edb42ad8b7c9cf0b2582f030937c0b5',
        sizeBytes: 11845274,
      ),
      ModelFileSpec(
        relativePath: 'parakeet/joiner.int8.onnx',
        url: '$_parakeetBase/joiner.int8.onnx',
        sha256: 'cbd02f3696e9944970111fb439d9c3fd365a80374565f13f2b9c7007d253fc98',
        sizeBytes: 6355277,
      ),
      ModelFileSpec(
        relativePath: 'parakeet/tokens.txt',
        url: '$_parakeetBase/tokens.txt',
        sha256: 'd58544679ea4bc6ac563d1f545eb7d474bd6cfa467f0a6e2c1dc1c7d37e3c35d',
        sizeBytes: 93939,
      ),
    ],
  );

  static const ModelSpec qwen3_4b = ModelSpec(
    id: 'qwen3-4b',
    kind: ModelKind.language,
    displayName: 'Qwen3 4B',
    qualityLine: 'Best notes. Well organised and keeps the details.',
    memoryLine: 'Uses about 3.7 GB of memory while writing',
    minDeviceRamMb: 7000,
    requiredNominalGb: 8,
    files: [
      ModelFileSpec(
        relativePath: 'qwen3-4b.gguf',
        url: 'https://huggingface.co/unsloth/Qwen3-4B-GGUF/resolve/'
            '22c9fc8a8c7700b76a1789366280a6a5a1ad1120/Qwen3-4B-Q4_K_M.gguf',
        sha256: 'f6f851777709861056efcdad3af01da38b31223a3ba26e61a4f8bf3a2195813a',
        sizeBytes: 2497281312,
      ),
    ],
    profile: SynthesisModelProfile.qwen3_4b,
  );

  static const ModelSpec qwen3_1_7b = ModelSpec(
    id: 'qwen3-1.7b',
    kind: ModelKind.language,
    displayName: 'Qwen3 1.7B',
    qualityLine: 'Lighter. Keeps the details, organises less tidily.',
    memoryLine: 'Uses about 1.8 GB of memory while writing (estimate)',
    minDeviceRamMb: 5200,
    requiredNominalGb: 6,
    listing: ModelListing.candidate,
    files: [
      ModelFileSpec(
        relativePath: 'qwen3-1.7b.gguf',
        url: 'https://huggingface.co/unsloth/Qwen3-1.7B-GGUF/resolve/'
            'd7f544eead698dbd1f15126ef60b45a1e1933222/Qwen3-1.7B-Q4_K_M.gguf',
        sha256: 'b139949c5bd74937ad8ed8c8cf3d9ffb1e99c866c823204dc42c0d91fa181897',
        sizeBytes: 1107409472,
      ),
    ],
    profile: SynthesisModelProfile.qwen3_1_7b,
  );

  /// Largest first: the order of the list on screen.
  static const List<ModelSpec> languageModels = [qwen3_4b, qwen3_1_7b];

  static const List<ModelSpec> all = [speech, qwen3_4b, qwen3_1_7b];

  /// The spec with [id], or `null` when the catalogue has none.
  static ModelSpec? byId(String? id) {
    if (id == null) return null;
    for (final m in all) {
      if (m.id == id) return m;
    }
    return null;
  }

  /// The language models to show. Candidates only when [includeCandidates] (debug builds).
  static List<ModelSpec> visibleLanguageModels({required bool includeCandidates}) => [
        for (final m in languageModels)
          if (includeCandidates || !m.isCandidate) m,
      ];

  /// True when a phone with [totalRamMb] of memory can run [spec]. Unknown memory does not
  /// fit a model that has a requirement.
  static bool fitsDevice(ModelSpec spec, int? totalRamMb) {
    if (spec.minDeviceRamMb <= 0) return true;
    return totalRamMb != null && totalRamMb >= spec.minDeviceRamMb;
  }

  /// Memory as printed on the box: the OS reports about 7.6 GB for an 8 GB phone, so the
  /// figure is rounded up to a whole number of GB.
  static int nominalGb(int ramMb) => (ramMb + 1023) ~/ 1024;

  /// The smallest memory (whole GB) any of [models] asks for, or `null` for an empty list.
  static int? smallestRequirementGb(List<ModelSpec> models) {
    if (models.isEmpty) return null;
    return models.map((m) => m.requiredNominalGb).reduce((a, b) => a < b ? a : b);
  }
}
