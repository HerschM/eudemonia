import 'dart:io';
import 'dart:math' show min;

/// Thread counts for the language model from the cores Android currently lets this process use
/// (IMPLEMENTATION.md 4.D). A process off screen runs in a smaller core set, so the counts are
/// chosen again before every prompt.
///
/// Measured on the Pixel 7a with Qwen3-4B Q4_K_M (TASK-073): on all cores 4 threads read 30 tok/s
/// and write 7.5, 6 threads 26 / 6.4, 8 threads 21 / 1.3; on cores 0-5 (four small, two mid) 2
/// threads write 5.1 against 4.9 with 4 and 3.9 with 6. More threads than fast cores make the fast
/// cores wait for the slow ones, so reading and writing use the same count for now; the pair is
/// kept because the two may diverge again.

/// Fewest threads when some fast cores are allowed.
const int minFastThreads = 2;

/// Most threads in any case.
const int maxThreads = 4;

/// Threads for both when the cores cannot be read (a host, or an unreadable /proc or /sys).
const int fallbackThreads = 4;

class CpuCore {
  final int index;
  final int maxFrequencyKhz;

  const CpuCore({required this.index, required this.maxFrequencyKhz});
}

/// The counts chosen for one prompt and the allowed core list they were chosen for.
class CpuThreads {
  final int reading;
  final int writing;

  /// The allowed cores as the kernel lists them, such as `0-5`; `unknown` when unreadable.
  final String allowedCores;

  const CpuThreads({required this.reading, required this.writing, required this.allowedCores});
}

/// One count for reading and writing. The fast cores are the [allowed] ones whose maximum
/// frequency is above the lowest maximum frequency of all [present] cores (every allowed core
/// when all cores have the same frequency). With fast cores the count is their number, at least
/// [minFastThreads] and at most [maxThreads]; with only slowest cores allowed it is their number
/// up to [maxThreads]. It never exceeds the number of allowed cores.
({int reading, int writing}) chooseThreadCounts({required List<CpuCore> allowed, required List<CpuCore> present}) {
  if (allowed.isEmpty) throw ArgumentError.value(allowed, 'allowed', 'must not be empty');
  final frequencies = present.map((c) => c.maxFrequencyKhz);
  final slowest = frequencies.isEmpty ? 0 : frequencies.reduce(min);
  final uniform = frequencies.every((f) => f == slowest);
  final fast = uniform ? allowed.length : allowed.where((c) => c.maxFrequencyKhz > slowest).length;
  final threads = fast == 0
      ? min(allowed.length, maxThreads)
      : min(fast.clamp(minFastThreads, maxThreads), allowed.length);
  return (reading: threads, writing: threads);
}

/// Parses a kernel core list such as `0-5` or `0-3,6`; null when [text] is not one.
List<int>? parseCpuList(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return null;
  final cores = <int>[];
  for (final part in trimmed.split(',')) {
    final range = part.split('-');
    if (range.length > 2) return null;
    final first = int.tryParse(range.first);
    final last = range.length == 2 ? int.tryParse(range.last) : first;
    if (first == null || last == null || first < 0 || last < first) return null;
    for (var i = first; i <= last; i++) {
      cores.add(i);
    }
  }
  return cores;
}

String? _readFileOrNull(String path) {
  try {
    return File(path).readAsStringSync();
  } catch (_) {
    return null;
  }
}

/// Reads the allowed cores from `/proc/self/status` (`Cpus_allowed_list`) and the maximum
/// frequency of every present core from `/sys/devices/system/cpu`, then applies
/// [chooseThreadCounts]. Falls back to [fallbackThreads] (at most the processor count) for both
/// when anything is missing or malformed. [readFile] returns null for an unreadable file.
CpuThreads readCpuThreads({String? Function(String path) readFile = _readFileOrNull}) {
  String? allowedText;
  try {
    final status = readFile('/proc/self/status');
    final line = status?.split('\n').where((l) => l.startsWith('Cpus_allowed_list:')).firstOrNull;
    allowedText = line?.substring('Cpus_allowed_list:'.length).trim();
    final allowedIndexes = allowedText == null ? null : parseCpuList(allowedText);
    final presentText = readFile('/sys/devices/system/cpu/present');
    final presentIndexes = presentText == null ? null : parseCpuList(presentText);
    if (allowedIndexes != null && presentIndexes != null) {
      final frequencies = <int, int>{};
      for (final i in {...presentIndexes, ...allowedIndexes}) {
        final khz = int.tryParse(readFile('/sys/devices/system/cpu/cpu$i/cpufreq/cpuinfo_max_freq')?.trim() ?? '');
        if (khz != null && khz > 0) frequencies[i] = khz;
      }
      if (allowedIndexes.every(frequencies.containsKey)) {
        final present = [
          for (final i in presentIndexes)
            if (frequencies[i] case final khz?) CpuCore(index: i, maxFrequencyKhz: khz),
        ];
        final counts = chooseThreadCounts(
          allowed: [for (final i in allowedIndexes) CpuCore(index: i, maxFrequencyKhz: frequencies[i]!)],
          present: present,
        );
        return CpuThreads(reading: counts.reading, writing: counts.writing, allowedCores: allowedText!);
      }
    }
  } catch (_) {}
  final threads = min(fallbackThreads, Platform.numberOfProcessors);
  final known = allowedText != null && allowedText.isNotEmpty ? allowedText : 'unknown';
  return CpuThreads(reading: threads, writing: threads, allowedCores: known);
}
