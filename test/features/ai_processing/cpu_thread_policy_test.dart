import 'dart:io';

import 'package:eudemonia/features/ai_processing/cpu_thread_policy.dart';
import 'package:flutter_test/flutter_test.dart';

/// The Pixel 7a: four small cores, two mid cores, two fast cores.
const pixel7aFrequencies = [1803000, 1803000, 1803000, 1803000, 2348000, 2348000, 2850000, 2850000];

List<CpuCore> cores(List<int> indexes, List<int> frequencies) =>
    [for (final i in indexes) CpuCore(index: i, maxFrequencyKhz: frequencies[i])];

/// A fake /proc and /sys: [files] maps a path to its text; any other path is unreadable.
String? Function(String) fileSystem(Map<String, String> files) => (path) => files[path];

Map<String, String> sysfs({required String allowed, required List<int> frequencies, String? present}) => {
      '/proc/self/status': 'Name:\tworker\nCpus_allowed:\t3f\nCpus_allowed_list:\t$allowed\nMems_allowed:\t1\n',
      '/sys/devices/system/cpu/present': '${present ?? '0-${frequencies.length - 1}'}\n',
      for (var i = 0; i < frequencies.length; i++)
        '/sys/devices/system/cpu/cpu$i/cpufreq/cpuinfo_max_freq': '${frequencies[i]}\n',
    };

void main() {
  group('parseCpuList', () {
    test('reads ranges, single cores and their mix', () {
      expect(parseCpuList('0-5'), [0, 1, 2, 3, 4, 5]);
      expect(parseCpuList('0-3,6'), [0, 1, 2, 3, 6]);
      expect(parseCpuList('7'), [7]);
      expect(parseCpuList(' 0-1,4-5\n'), [0, 1, 4, 5]);
    });

    test('rejects text that is not a core list', () {
      expect(parseCpuList(''), isNull);
      expect(parseCpuList('a-b'), isNull);
      expect(parseCpuList('5-3'), isNull);
      expect(parseCpuList('0,,1'), isNull);
    });
  });

  group('chooseThreadCounts', () {
    final present = cores(List.generate(8, (i) => i), pixel7aFrequencies);

    test('Pixel 7a with every core allowed: 4 threads, one per faster core', () {
      final t = chooseThreadCounts(allowed: present, present: present);
      expect((t.reading, t.writing), (4, 4));
    });

    test('Pixel 7a in the foreground set (cores 0-5): 2 threads, one per mid core', () {
      final t = chooseThreadCounts(allowed: cores([0, 1, 2, 3, 4, 5], pixel7aFrequencies), present: present);
      expect((t.reading, t.writing), (2, 2));
    });

    test('Pixel 7a in the background set (cores 0-3, only the slowest class): 4 threads', () {
      final t = chooseThreadCounts(allowed: cores([0, 1, 2, 3], pixel7aFrequencies), present: present);
      expect((t.reading, t.writing), (4, 4));
    });

    test('one fast core is raised to the minimum of 2 threads', () {
      final t = chooseThreadCounts(allowed: cores([0, 1, 2, 3, 6], pixel7aFrequencies), present: present);
      expect((t.reading, t.writing), (2, 2));
    });

    test('only slow cores, fewer than the maximum: one thread per core', () {
      final t = chooseThreadCounts(allowed: cores([0, 1], pixel7aFrequencies), present: present);
      expect((t.reading, t.writing), (2, 2));
    });

    test('a machine whose cores all run at one frequency treats every allowed core as fast', () {
      final same = cores(List.generate(8, (i) => i), List.filled(8, 2000000));
      expect(chooseThreadCounts(allowed: same, present: same), (reading: 4, writing: 4));
      final three = same.take(3).toList();
      expect(chooseThreadCounts(allowed: three, present: same), (reading: 3, writing: 3));
    });

    test('never more threads than allowed cores', () {
      final one = cores([6], pixel7aFrequencies);
      expect(chooseThreadCounts(allowed: one, present: present), (reading: 1, writing: 1));
    });
  });

  group('readCpuThreads', () {
    test('Pixel 7a foreground set read from /proc and /sys', () {
      final t = readCpuThreads(readFile: fileSystem(sysfs(allowed: '0-5', frequencies: pixel7aFrequencies)));
      expect((t.reading, t.writing, t.allowedCores), (2, 2, '0-5'));
    });

    test('Pixel 7a with all cores', () {
      final t = readCpuThreads(readFile: fileSystem(sysfs(allowed: '0-7', frequencies: pixel7aFrequencies)));
      expect((t.reading, t.writing, t.allowedCores), (4, 4, '0-7'));
    });

    test('Pixel 7a with a gap in the allowed list', () {
      final t = readCpuThreads(readFile: fileSystem(sysfs(allowed: '0-3,6', frequencies: pixel7aFrequencies)));
      // Core 6 is fast: one fast core, raised to the minimum of 2.
      expect((t.reading, t.writing, t.allowedCores), (2, 2, '0-3,6'));
    });

    final fallback = Platform.numberOfProcessors < 4 ? Platform.numberOfProcessors : 4;

    test('nothing readable (a host without /proc) falls back to the same count for both', () {
      final t = readCpuThreads(readFile: fileSystem(const {}));
      expect((t.reading, t.writing, t.allowedCores), (fallback, fallback, 'unknown'));
    });

    test('a missing frequency of an allowed core falls back, keeping the allowed list', () {
      final files = sysfs(allowed: '0-5', frequencies: pixel7aFrequencies)
        ..remove('/sys/devices/system/cpu/cpu5/cpufreq/cpuinfo_max_freq');
      final t = readCpuThreads(readFile: fileSystem(files));
      expect((t.reading, t.writing, t.allowedCores), (fallback, fallback, '0-5'));
    });

    test('a malformed status or frequency file falls back', () {
      final noList = sysfs(allowed: '0-5', frequencies: pixel7aFrequencies)
        ..['/proc/self/status'] = 'Name:\tworker\n';
      expect(readCpuThreads(readFile: fileSystem(noList)).reading, fallback);
      final badFrequency = sysfs(allowed: '0-5', frequencies: pixel7aFrequencies)
        ..['/sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq'] = 'fast';
      expect(readCpuThreads(readFile: fileSystem(badFrequency)).writing, fallback);
    });

    test('a file reader that throws falls back', () {
      final t = readCpuThreads(readFile: (_) => throw const FileSystemException('denied'));
      expect((t.reading, t.writing), (fallback, fallback));
    });
  });
}
