import 'package:flutter/foundation.dart';

/// Attributions for the models and runtimes Eudemonia ships with, shown on Flutter's licence page.
/// Short attribution paragraphs, not full licence texts.
const List<({String package, String text})> modelCredits = [
  (
    package: 'Parakeet TDT 0.6b v3 (speech model)',
    text: 'NVIDIA. Licensed under Creative Commons Attribution 4.0 (CC-BY-4.0). '
        'Converted for on-device use by the sherpa-onnx project.',
  ),
  (
    package: 'Qwen3 (writing models)',
    text: 'Alibaba Cloud. Licensed under the Apache License 2.0.',
  ),
  (
    package: 'llama.cpp',
    text: 'The ggml authors. MIT License.',
  ),
  (
    package: 'sherpa-onnx',
    text: 'Xiaomi Corporation and contributors. Apache License 2.0.',
  ),
];

/// Adds [modelCredits] to [LicenseRegistry]. Call once, from `main()`.
void registerModelCredits() {
  for (final credit in modelCredits) {
    LicenseRegistry.addLicense(() async* {
      yield LicenseEntryWithLineBreaks([credit.package], credit.text);
    });
  }
}
