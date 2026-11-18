import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';
import 'package:eudemonia/core/database/app_database.dart';
import 'package:eudemonia/features/synthesis/domain/synthesis_cluster.dart';
import 'synthesis_session_record.dart';

/// Durable storage for synthesis sessions, with an in-memory fallback when no
/// database is provided (isolated unit and widget tests).
class SynthesisSessionStore {
  final Isar? _isar;
  /// Holds the same durable records the database would, so both paths persist identical fields.
  final Map<String, SynthesisSessionRecord> _inMemory = {};

  SynthesisSessionStore({this._isar});

  /// All stored sessions, newest session identifier first.
  Future<List<SynthesisCluster>> loadAll() async {
    final isar = _isar;
    final clusters = isar != null
        ? (await isar.synthesisSessionRecords.where().findAll()).map((r) => r.toCluster()).toList()
        : _inMemory.values.map((r) => r.toCluster()).toList();
    clusters.sort((a, b) => sequenceIndexOf(b).compareTo(sequenceIndexOf(a)));
    return clusters;
  }

  Future<void> put(SynthesisCluster cluster) async {
    final isar = _isar;
    if (isar == null) {
      _inMemory[cluster.clusterId] = SynthesisSessionRecord.fromCluster(cluster);
      return;
    }
    await isar.writeTxn(() async {
      final record = SynthesisSessionRecord.fromCluster(cluster);
      final existing = await isar.synthesisSessionRecords
          .where()
          .clusterIdEqualTo(cluster.clusterId)
          .findFirst();
      if (existing != null) record.id = existing.id;
      await isar.synthesisSessionRecords.put(record);
    });
  }

  Future<void> delete(String clusterId) async {
    final isar = _isar;
    if (isar == null) {
      _inMemory.remove(clusterId);
      return;
    }
    await isar.writeTxn(() async {
      await isar.synthesisSessionRecords.where().clusterIdEqualTo(clusterId).deleteAll();
    });
  }

  /// Numeric part of a `#S-NN` identifier, or 0 when it cannot be parsed.
  static int sequenceIndexOf(SynthesisCluster cluster) =>
      int.tryParse(cluster.sequenceNumber.replaceFirst('#S-', '')) ?? 0;
}

final synthesisSessionStoreProvider = Provider<SynthesisSessionStore>((ref) {
  return SynthesisSessionStore(isar: ref.watch(appDatabaseProvider));
});
