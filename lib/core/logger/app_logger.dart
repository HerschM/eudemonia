import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

/// Central on-device logger that persists timestamped diagnostic logs, errors,
/// trigger events, and state transitions to local storage.
///
/// Designed to survive debugger disconnects so logs can be exported directly from the device.
class AppLogger {
  final Future<File> Function()? _logFileResolver;
  final int _maxSizeBytes;
  File? _cachedFile;
  bool _isWriting = false;
  final List<String> _writeBuffer = [];

  AppLogger({
    Future<File> Function()? logFileResolver,
    int maxSizeBytes = 2 * 1024 * 1024, // 2MB default rotation cap
  })  : _logFileResolver = logFileResolver,
        _maxSizeBytes = maxSizeBytes;

  Future<File> _resolveLogFile() async {
    if (_cachedFile != null) return _cachedFile!;
    if (_logFileResolver != null) {
      _cachedFile = await _logFileResolver();
      return _cachedFile!;
    }
    final appDir = await getApplicationDocumentsDirectory();
    final logDir = Directory('${appDir.path}/logs');
    if (!await logDir.exists()) {
      await logDir.create(recursive: true);
    }
    _cachedFile = File('${logDir.path}/app_logs.txt');
    return _cachedFile!;
  }

  Future<void> info(String message) async {
    await _writeEntry('INFO', message);
  }

  Future<void> warning(String message) async {
    await _writeEntry('WARN', message);
  }

  Future<void> error(String message, {dynamic error, StackTrace? stackTrace}) async {
    final sb = StringBuffer(message);
    if (error != null) {
      sb.write(' | Exception: $error');
    }
    if (stackTrace != null) {
      sb.write('\n$stackTrace');
    }
    await _writeEntry('ERROR', sb.toString());
  }

  Future<void> trigger(String message) async {
    await _writeEntry('TRIGGER', message);
  }

  Future<void> _writeEntry(String level, String message) async {
    final now = DateTime.now().toIso8601String();
    final entry = '[$now] [$level] $message';

    // Also echo to console for active debug sessions
    // ignore: avoid_print
    print(entry);

    _writeBuffer.add(entry);
    if (!_isWriting) {
      _isWriting = true;
      try {
        final file = await _resolveLogFile();
        while (_writeBuffer.isNotEmpty) {
          final chunk = _writeBuffer.join('\n') + '\n';
          _writeBuffer.clear();

          // Check for size cap rotation
          if (await file.exists() && await file.length() > _maxSizeBytes) {
            await _rotateLogFile(file);
          }

          await file.writeAsString(chunk, mode: FileMode.append, flush: true);
        }
      } catch (e) {
        // Fallback print if file IO fails
        // ignore: avoid_print
        print('[AppLogger Error writing to disk: $e]');
      } finally {
        _isWriting = false;
      }
    }
  }

  Future<void> _rotateLogFile(File file) async {
    try {
      final content = await file.readAsString();
      final lines = content.split('\n');
      // Keep only the most recent half of the lines
      final keepLines = lines.sublist((lines.length / 2).floor());
      await file.writeAsString(keepLines.join('\n'), flush: true);
    } catch (_) {}
  }

  Future<String> getLogDump() async {
    try {
      final file = await _resolveLogFile();
      if (!await file.exists()) return 'No logs recorded yet.';
      return await file.readAsString();
    } catch (e) {
      return 'Error reading logs: $e';
    }
  }

  Future<List<String>> getRecentLines({int count = 100}) async {
    try {
      final file = await _resolveLogFile();
      if (!await file.exists()) return [];
      final lines = await file.readAsLines();
      if (lines.length <= count) return lines;
      return lines.sublist(lines.length - count);
    } catch (e) {
      return ['Error reading recent logs: $e'];
    }
  }

  Future<void> clearLogs() async {
    try {
      final file = await _resolveLogFile();
      if (await file.exists()) {
        await file.writeAsString('', flush: true);
      }
    } catch (_) {}
  }
}

final appLoggerProvider = Provider<AppLogger>((ref) {
  return AppLogger();
});
