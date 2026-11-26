import 'package:eudemonia/features/models/domain/model_catalogue.dart';
import 'package:eudemonia/features/synthesis/domain/synthesis_model_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ModelCatalogue data', () {
    test('every URL is https and pinned to a 40-hex revision', () {
      final pinned = RegExp(r'^https://huggingface\.co/[^/]+/[^/]+/resolve/[0-9a-f]{40}/[^/]+$');
      for (final model in ModelCatalogue.all) {
        for (final file in model.files) {
          expect(pinned.hasMatch(file.url), isTrue, reason: file.url);
        }
      }
    });

    test('every sha256 is 64 lower-case hex characters and every size is positive', () {
      final hex = RegExp(r'^[0-9a-f]{64}$');
      for (final model in ModelCatalogue.all) {
        for (final file in model.files) {
          expect(hex.hasMatch(file.sha256), isTrue, reason: file.relativePath);
          expect(file.sizeBytes, greaterThan(0), reason: file.relativePath);
        }
      }
    });

    test('relative paths and ids are unique across the catalogue', () {
      final paths = [for (final m in ModelCatalogue.all) ...m.files.map((f) => f.relativePath)];
      expect(paths.toSet().length, paths.length);
      final ids = ModelCatalogue.all.map((m) => m.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('the speech model has four files and totals their sizes', () {
      expect(ModelCatalogue.speech.files, hasLength(4));
      expect(ModelCatalogue.speech.totalBytes, 652282294 + 11845274 + 6355277 + 93939);
      expect(ModelCatalogue.speech.kind, ModelKind.speech);
      expect(ModelCatalogue.speech.profile, isNull);
    });

    test('language models carry the profile that loads their file', () {
      for (final model in ModelCatalogue.languageModels) {
        expect(model.kind, ModelKind.language);
        expect(model.files, hasLength(1));
        expect(model.profile!.modelFileName, model.files.single.relativePath);
      }
      expect(ModelCatalogue.qwen3_4b.profile, SynthesisModelProfile.qwen3_4b);
      expect(ModelCatalogue.qwen3_1_7b.profile, SynthesisModelProfile.qwen3_1_7b);
    });

    test('byId finds a model or returns null', () {
      expect(ModelCatalogue.byId('qwen3-4b'), ModelCatalogue.qwen3_4b);
      expect(ModelCatalogue.byId('nope'), isNull);
      expect(ModelCatalogue.byId(null), isNull);
    });
  });

  group('ModelCatalogue rules', () {
    test('candidates are hidden unless requested', () {
      expect(ModelCatalogue.visibleLanguageModels(includeCandidates: false), [ModelCatalogue.qwen3_4b]);
      expect(ModelCatalogue.visibleLanguageModels(includeCandidates: true),
          [ModelCatalogue.qwen3_4b, ModelCatalogue.qwen3_1_7b]);
      expect(ModelCatalogue.qwen3_1_7b.isCandidate, isTrue);
      expect(ModelCatalogue.qwen3_4b.isCandidate, isFalse);
    });

    test('a model fits when the phone has at least its requirement', () {
      expect(ModelCatalogue.fitsDevice(ModelCatalogue.qwen3_4b, 7600), isTrue);
      expect(ModelCatalogue.fitsDevice(ModelCatalogue.qwen3_4b, 7000), isTrue);
      expect(ModelCatalogue.fitsDevice(ModelCatalogue.qwen3_4b, 6999), isFalse);
      expect(ModelCatalogue.fitsDevice(ModelCatalogue.qwen3_1_7b, 5600), isTrue);
    });

    test('unknown memory fits only a model with no requirement', () {
      expect(ModelCatalogue.fitsDevice(ModelCatalogue.qwen3_4b, null), isFalse);
      expect(ModelCatalogue.fitsDevice(ModelCatalogue.speech, null), isTrue);
    });

    test('nominalGb rounds the reported megabytes up to whole gigabytes', () {
      expect(ModelCatalogue.nominalGb(7600), 8);
      expect(ModelCatalogue.nominalGb(8192), 8);
      expect(ModelCatalogue.nominalGb(8193), 9);
      expect(ModelCatalogue.nominalGb(5600), 6);
      expect(ModelCatalogue.nominalGb(1), 1);
    });

    test('smallestRequirementGb is the smallest requirement, or null for no models', () {
      expect(ModelCatalogue.smallestRequirementGb([ModelCatalogue.qwen3_4b]), 8);
      expect(ModelCatalogue.smallestRequirementGb([ModelCatalogue.qwen3_4b, ModelCatalogue.qwen3_1_7b]), 6);
      expect(ModelCatalogue.smallestRequirementGb(const []), isNull);
    });
  });
}
