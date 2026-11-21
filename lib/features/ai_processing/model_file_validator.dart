import 'dart:io';
import 'dart:typed_data';

/// Raised when a model file is missing or structurally invalid. The message is shown to the user.
class ModelFileException implements Exception {
  final String message;
  const ModelFileException(this.message);

  @override
  String toString() => message;
}

/// The files that make up the on-device models, resolved from the models directory.
///
/// [llmModelPath] is optional: when null the language model is neither
/// validated nor part of [signature], so it cannot block speech loading.
class ModelFiles {
  final String sttModelDir;
  final String? llmModelPath;

  const ModelFiles({required this.sttModelDir, this.llmModelPath});

  List<String> get onnxFiles => [
        '$sttModelDir/encoder.int8.onnx',
        '$sttModelDir/decoder.int8.onnx',
        '$sttModelDir/joiner.int8.onnx',
      ];

  String get tokensFile => '$sttModelDir/tokens.txt';

  List<String> get all => [...onnxFiles, tokensFile, ?llmModelPath];

  /// Identity of the current file set. Changes whenever a file is replaced.
  Future<String> signature() async {
    final parts = <String>[];
    for (final path in all) {
      final stat = await File(path).stat();
      parts.add('$path:${stat.size}:${stat.modified.millisecondsSinceEpoch}');
    }
    return parts.join('|');
  }
}

/// Structural integrity checks for model files.
///
/// The native runtimes abort the whole process when handed a malformed file
/// (an uncaught C++ exception cannot be caught from Dart), so anything that
/// can be rejected cheaply must be rejected here first.
class ModelFileValidator {
  const ModelFileValidator();

  static const String _redownloadHint = 'Re-run download_models.sh to replace it.';

  Future<void> validate(ModelFiles files) async {
    for (final path in files.onnxFiles) {
      await validateOnnx(path);
    }
    if (!await File(files.tokensFile).exists()) {
      throw ModelFileException('Speech model file tokens.txt is missing. $_redownloadHint');
    }
    final llmPath = files.llmModelPath;
    if (llmPath != null) await validateGguf(llmPath);
  }

  /// Checks that [path] is a well-formed protobuf message end to end.
  ///
  /// An ONNX model is one protobuf message. Walking its top-level fields reads
  /// only a few bytes per field, yet detects truncated, spliced, zero-filled
  /// and non-model files (HTML error pages, Git LFS pointers).
  Future<void> validateOnnx(String path) async {
    final name = path.split('/').last;
    final file = File(path);
    if (!await file.exists()) {
      throw ModelFileException('Speech model file $name is missing. $_redownloadHint');
    }

    final raf = await file.open();
    try {
      final length = await raf.length();
      int offset = 0;
      int fieldCount = 0;

      Never corrupt() => throw ModelFileException(
          'Speech model file $name is corrupt or incomplete. $_redownloadHint');

      Future<int> readVarint() async {
        await raf.setPosition(offset);
        final bytes = await raf.read(10);
        int value = 0;
        for (int i = 0; i < bytes.length; i++) {
          value |= (bytes[i] & 0x7F) << (7 * i);
          if (bytes[i] & 0x80 == 0) {
            offset += i + 1;
            return value;
          }
        }
        corrupt();
      }

      if (length == 0) corrupt();
      while (offset < length) {
        final tag = await readVarint();
        final fieldNumber = tag >> 3;
        if (fieldNumber <= 0) corrupt();
        switch (tag & 0x7) {
          case 0: // varint
            await readVarint();
          case 1: // 64-bit
            offset += 8;
          case 2: // length-delimited
            final size = await readVarint();
            if (size < 0) corrupt();
            offset += size;
          case 5: // 32-bit
            offset += 4;
          default:
            corrupt();
        }
        if (offset > length) corrupt();
        fieldCount++;
      }
      // A real model has a graph plus metadata; a single stray field is not a model.
      if (fieldCount < 2) corrupt();
    } finally {
      await raf.close();
    }
  }

  /// Checks the GGUF magic header of the LLM weights.
  Future<void> validateGguf(String path) async {
    final name = path.split('/').last;
    final file = File(path);
    if (!await file.exists()) {
      throw ModelFileException('Language model file $name is missing. $_redownloadHint');
    }
    final raf = await file.open();
    try {
      final Uint8List header = await raf.read(4);
      const magic = [0x47, 0x47, 0x55, 0x46]; // "GGUF"
      final isGguf = header.length == 4 &&
          header[0] == magic[0] &&
          header[1] == magic[1] &&
          header[2] == magic[2] &&
          header[3] == magic[3];
      if (!isGguf) {
        throw ModelFileException('Language model file $name is corrupt or incomplete. $_redownloadHint');
      }
    } finally {
      await raf.close();
    }
  }
}
