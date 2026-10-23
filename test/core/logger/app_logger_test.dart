import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:eudemonia/core/logger/app_logger.dart';

void main() {
  late Directory tempDir;
  late File logFile;
  late AppLogger logger;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('app_logger_test_');
    logFile = File('${tempDir.path}/app_logs.txt');
    logger = AppLogger(logFileResolver: () async => logFile);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('AppLogger writes info, warning, and error logs with timestamps to file', () async {
    await logger.info('Test info message');
    await logger.warning('Test warning message');
    await logger.error('Test error message', error: Exception('Something went wrong'));

    expect(await logFile.exists(), isTrue);
    final content = await logFile.readAsString();

    expect(content, contains('[INFO] Test info message'));
    expect(content, contains('[WARN] Test warning message'));
    expect(content, contains('[ERROR] Test error message'));
    expect(content, contains('Something went wrong'));
  });

  test('AppLogger retrieves recent logs and dump correctly', () async {
    await logger.info('Message 1');
    await logger.info('Message 2');

    final dump = await logger.getLogDump();
    expect(dump, contains('Message 1'));
    expect(dump, contains('Message 2'));

    final recentLines = await logger.getRecentLines(count: 1);
    expect(recentLines.length, 1);
    expect(recentLines.first, contains('Message 2'));
  });

  test('AppLogger clears logs cleanly', () async {
    await logger.info('Message before clear');
    expect(await logFile.length(), greaterThan(0));

    await logger.clearLogs();
    final content = await logFile.readAsString();
    expect(content, isEmpty);
  });

  test('AppLogger rotates / caps file when size exceeds limit', () async {
    // Set a very small max size (200 bytes) for testing rotation
    final smallLogger = AppLogger(
      logFileResolver: () async => logFile,
      maxSizeBytes: 200,
    );

    // Write enough data to exceed 200 bytes
    for (int i = 0; i < 10; i++) {
      await smallLogger.info('This is a relatively long test log entry line number $i');
    }

    final length = await logFile.length();
    expect(length, lessThanOrEqualTo(300));
  });
}
