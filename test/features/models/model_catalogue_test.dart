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

    test('the first speech model has four files and totals their sizes', () {
      expect(ModelCatalogue.parakeetV3.files, hasLength(4));
      expect(ModelCatalogue.parakeetV3.totalBytes, 652282294 + 11845274 + 6355277 + 93939);
      expect(ModelCatalogue.parakeetV3.kind, ModelKind.speech);
      expect(ModelCatalogue.parakeetV3.profile, isNull);
    });

    test('two speech models are offered, the shipped v3 first, with their quality lines', () {
      expect(ModelCatalogue.speechModels, [ModelCatalogue.parakeetV3, ModelCatalogue.parakeetV2]);
      expect(ModelCatalogue.parakeetV3.id, 'parakeet-tdt-0.6b-v3-int8');
      expect(ModelCatalogue.parakeetV3.qualityLine, '25 European languages. Good for mixed-language speakers.');
      expect(ModelCatalogue.parakeetV2.id, 'parakeet-tdt-0.6b-v2-int8');
      expect(ModelCatalogue.parakeetV2.qualityLine, 'English only. The most accurate for English.');
      for (final model in ModelCatalogue.speechModels) {
        expect(model.kind, ModelKind.speech);
        expect(model.profile, isNull);
        expect(model.files.map((f) => f.relativePath.split('/').last),
            ['encoder.int8.onnx', 'decoder.int8.onnx', 'joiner.int8.onnx', 'tokens.txt']);
        expect(ModelCatalogue.byId(model.id), model);
      }
    });

    test('the speech models keep their files in distinct directories; v3 stays where it always was', () {
      expect(ModelCatalogue.parakeetV3.directory, 'parakeet');
      expect(ModelCatalogue.parakeetV2.directory, 'parakeet-v2');
      for (final model in ModelCatalogue.speechModels) {
        expect(model.files.every((f) => f.relativePath.startsWith('${model.directory}/')), isTrue);
      }
      expect(ModelCatalogue.qwen3_4b.directory, '', reason: 'a file at the top level has no directory');
    });

    test('v2 is pinned to one commit of its repository and carries the verified hashes', () {
      const repo = 'https://huggingface.co/csukuangfj/sherpa-onnx-nemo-parakeet-tdt-0.6b-v2-int8/resolve/'
          '84b478d541cdbf0c296a7ab5f1e20a6f8f998114';
      expect({for (final f in ModelCatalogue.parakeetV2.files) f.relativePath: f.url}, {
        'parakeet-v2/encoder.int8.onnx': '$repo/encoder.int8.onnx',
        'parakeet-v2/decoder.int8.onnx': '$repo/decoder.int8.onnx',
        'parakeet-v2/joiner.int8.onnx': '$repo/joiner.int8.onnx',
        'parakeet-v2/tokens.txt': '$repo/tokens.txt',
      });
      expect({for (final f in ModelCatalogue.parakeetV2.files) f.relativePath: f.sha256}, {
        'parakeet-v2/encoder.int8.onnx': '92a10bd9c23936ea0566c29f963bc57c2a5df4261b6a8921c39abea66557ca8b',
        'parakeet-v2/decoder.int8.onnx': '4d097bae3bac5c96018d5293ba39f1b657296102b142affda40378f38b020f41',
        'parakeet-v2/joiner.int8.onnx': '77a29f3e5ac7d37074e0af465391b80f314015d5b97f0f90c6c7767f1d56f428',
        'parakeet-v2/tokens.txt': 'ec182b70dd42113aff6c5372c75cac58c952443eb22322f57bbd7f53977d497d',
      });
      expect(ModelCatalogue.parakeetV2.totalBytes, 652282309 + 7257753 + 1739080 + 9384);
    });

    test('v3 is unchanged: its files, hashes and pinned commit', () {
      const repo = 'https://huggingface.co/csukuangfj/sherpa-onnx-nemo-parakeet-tdt-0.6b-v3-int8/resolve/'
          'ed5d745623472f97cfc2e6c2916ee248798fc5a8';
      expect({for (final f in ModelCatalogue.parakeetV3.files) f.relativePath: (f.url, f.sha256)}, {
        'parakeet/encoder.int8.onnx': (
          '$repo/encoder.int8.onnx',
          '1afbe69c1ffdabee94755f42e4daf1d93549131a3da11356bda84fcef0f2c479'
        ),
        'parakeet/decoder.int8.onnx': (
          '$repo/decoder.int8.onnx',
          '0222a86147299d4dee90edf95b6d13827edb42ad8b7c9cf0b2582f030937c0b5'
        ),
        'parakeet/joiner.int8.onnx': (
          '$repo/joiner.int8.onnx',
          'cbd02f3696e9944970111fb439d9c3fd365a80374565f13f2b9c7007d253fc98'
        ),
        'parakeet/tokens.txt': ('$repo/tokens.txt', 'd58544679ea4bc6ac563d1f545eb7d474bd6cfa467f0a6e2c1dc1c7d37e3c35d'),
      });
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
    test('both language models are offered to everyone, the 4B first', () {
      expect(ModelCatalogue.languageModels, [ModelCatalogue.qwen3_4b, ModelCatalogue.qwen3_1_7b]);
    });

    test('the 1.7B carries a quality note and keeps its memory requirement', () {
      final small = ModelCatalogue.qwen3_1_7b;
      expect(small.qualityLine,
          'Smaller and faster, for phones with 6 GB of memory. Notes are less tidy and can miss a detail now and then.');
      expect(small.memoryLine, 'Uses about 1.8 GB of memory while writing (estimate)');
      expect(small.minDeviceRamMb, 5200);
      expect(small.requiredNominalGb, 6);
    });

    test('a model fits when the phone has at least its requirement', () {
      expect(ModelCatalogue.fitsDevice(ModelCatalogue.qwen3_4b, 7600), isTrue);
      expect(ModelCatalogue.fitsDevice(ModelCatalogue.qwen3_4b, 7000), isTrue);
      expect(ModelCatalogue.fitsDevice(ModelCatalogue.qwen3_4b, 6999), isFalse);
      expect(ModelCatalogue.fitsDevice(ModelCatalogue.qwen3_1_7b, 5600), isTrue);
    });

    test('unknown memory fits only a model with no requirement', () {
      expect(ModelCatalogue.fitsDevice(ModelCatalogue.qwen3_4b, null), isFalse);
      expect(ModelCatalogue.fitsDevice(ModelCatalogue.parakeetV3, null), isTrue);
      expect(ModelCatalogue.fitsDevice(ModelCatalogue.parakeetV2, null), isTrue);
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
