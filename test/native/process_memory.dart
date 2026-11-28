import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

/// The memory the process holds. On macOS this is the physical footprint (what Activity Monitor
/// shows): resident memory leaves out pages the system compressed, so a leak can look freed.
/// Elsewhere it is the resident memory.
int processMemory() {
  if (!Platform.isMacOS) return ProcessInfo.currentRss;
  final libc = DynamicLibrary.process();
  final taskInfo = libc.lookupFunction<Int32 Function(Uint32, Int32, Pointer<Int32>, Pointer<Uint32>),
      int Function(int, int, Pointer<Int32>, Pointer<Uint32>)>('task_info');
  final task = libc.lookup<Uint32>('mach_task_self_').value;
  const taskVmInfo = 22; // TASK_VM_INFO
  const physFootprintOffset = 144; // task_vm_info_data_t.phys_footprint
  final info = calloc<Int32>(128);
  final count = calloc<Uint32>()..value = 128;
  try {
    if (taskInfo(task, taskVmInfo, info, count) != 0) throw StateError('task_info failed');
    return (info.cast<Uint8>() + physFootprintOffset).cast<Uint64>().value;
  } finally {
    calloc.free(info);
    calloc.free(count);
  }
}
