/// The model files Eudemonia downloads, and the pure rules that decide which ones a phone can
/// use. Pure Dart, const data (FR16).
library;

import 'package:eudemonia/features/synthesis/domain/synthesis_model_profile.dart';

enum ModelKind { speech, language }

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

  /// How synthesis uses the model; `null` for a speech model.
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
    this.profile,
  });

  int get totalBytes => files.fold(0, (sum, f) => sum + f.sizeBytes);

  /// The folder (below the app's external files directory) that holds every file of the model:
  /// `parakeet-v2` for `parakeet-v2/encoder.int8.onnx`. A file at the top level gives an empty string.
  String get directory {
    final path = files.first.relativePath;
    final slash = path.lastIndexOf('/');
    return slash < 0 ? '' : path.substring(0, slash);
  }
}

class ModelCatalogue {
  const ModelCatalogue._();

  static const String _parakeetV2Base =
      'https://huggingface.co/csukuangfj/sherpa-onnx-nemo-parakeet-tdt-0.6b-v2-int8/resolve/'
      '84b478d541cdbf0c296a7ab5f1e20a6f8f998114';

  /// Parakeet v2: English only, and the app's only speech model (user decision 2026-11-28). It
  /// beat Parakeet v3 on English (2.0 % against 10.5 % word error rate on 22 real recordings,
  /// 2026-11-27); v3's European-language model is not offered because it has not been tested.
  static const ModelSpec parakeetV2 = ModelSpec(
    id: 'parakeet-tdt-0.6b-v2-int8',
    kind: ModelKind.speech,
    displayName: 'Parakeet v2 (English)',
    qualityLine: 'English only. The most accurate for English.',
    memoryLine: 'Loaded only while transcribing',
    minDeviceRamMb: 0,
    requiredNominalGb: 0,
    files: [
      ModelFileSpec(
        relativePath: 'parakeet-v2/encoder.int8.onnx',
        url: '$_parakeetV2Base/encoder.int8.onnx',
        sha256: '92a10bd9c23936ea0566c29f963bc57c2a5df4261b6a8921c39abea66557ca8b',
        sizeBytes: 652282309,
      ),
      ModelFileSpec(
        relativePath: 'parakeet-v2/decoder.int8.onnx',
        url: '$_parakeetV2Base/decoder.int8.onnx',
        sha256: '4d097bae3bac5c96018d5293ba39f1b657296102b142affda40378f38b020f41',
        sizeBytes: 7257753,
      ),
      ModelFileSpec(
        relativePath: 'parakeet-v2/joiner.int8.onnx',
        url: '$_parakeetV2Base/joiner.int8.onnx',
        sha256: '77a29f3e5ac7d37074e0af465391b80f314015d5b97f0f90c6c7767f1d56f428',
        sizeBytes: 1739080,
      ),
      ModelFileSpec(
        relativePath: 'parakeet-v2/tokens.txt',
        url: '$_parakeetV2Base/tokens.txt',
        sha256: 'ec182b70dd42113aff6c5372c75cac58c952443eb22322f57bbd7f53977d497d',
        sizeBytes: 9384,
      ),
    ],
  );

  /// The order of the list on screen.
  static const List<ModelSpec> speechModels = [parakeetV2];

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
    qualityLine: 'Smaller and faster, for phones with 6 GB of memory. Notes are less tidy and can miss a detail now and then.',
    memoryLine: 'Uses about 1.8 GB of memory while writing (estimate)',
    minDeviceRamMb: 5200,
    requiredNominalGb: 6,
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

  static const List<ModelSpec> all = [parakeetV2, qwen3_4b, qwen3_1_7b];

  /// The spec with [id], or `null` when the catalogue has none.
  static ModelSpec? byId(String? id) {
    if (id == null) return null;
    for (final m in all) {
      if (m.id == id) return m;
    }
    return null;
  }

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
