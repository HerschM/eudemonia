import 'package:integration_test/integration_test_driver.dart';

/// Host-side driver for on-device benchmarks. Run with `--keep-app-running` so the
/// app and its data (database, recordings, model files) are not uninstalled afterwards:
///
/// flutter drive --driver=test_driver/integration_test.dart \
///   --target=integration_test/llm_latency_benchmark_test.dart -d DEVICE_ID --keep-app-running
///
/// Do NOT use `flutter test integration_test/... -d DEVICE_ID`: it uninstalls the app when it finishes.
Future<void> main() => integrationDriver();
