import 'dart:convert';

import 'session.dart';

/// Minimal key-value storage so persistence logic is testable without plugins.
abstract class KeyValueStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> remove(String key);
}

class MemoryStore implements KeyValueStore {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
  @override
  Future<void> remove(String key) async => values.remove(key);
}

/// Stores derived session records on the device, keyed by session id.
///
/// * Saving is an upsert by id, so repeated saves of the same session (retries,
///   double taps, draft → final) never create duplicates.
/// * Writes are serialised so concurrent saves cannot interleave.
/// * Records left `inProgress` by an app close are recovered as `interrupted`
///   and interpreted from whatever observations were stored.
class SessionRepository {
  SessionRepository(this.store);
  final KeyValueStore store;

  static const key = 'sanket_sessions_v2';

  /// Pre-v2 history entries were free-text summaries of demonstration
  /// scenarios with no measurements behind them. They are not shown.
  static const legacyKey = 'sanket_history';

  Future<void> _queue = Future.value();

  Future<T> _serial<T>(Future<T> Function() action) {
    final next = _queue.then((_) => action());
    _queue = next.then((_) {}, onError: (_) {});
    return next;
  }

  Future<List<SessionRecord>> _readAll() async {
    final raw = await store.read(key);
    if (raw == null || raw.isEmpty) return [];
    final list = <SessionRecord>[];
    for (final item in jsonDecode(raw) as List) {
      try {
        list.add(
            SessionRecord.fromJson(Map<String, dynamic>.from(item as Map)));
      } catch (_) {
        // A corrupt record is skipped rather than breaking all history.
      }
    }
    return list;
  }

  Future<void> _writeAll(List<SessionRecord> records) {
    records.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return store.write(key, jsonEncode([for (final r in records) r.toJson()]));
  }

  Future<List<SessionRecord>> loadAll() => _serial(() async {
        await store.remove(legacyKey);
        final records = await _readAll();
        records.sort((a, b) => b.startedAt.compareTo(a.startedAt));
        return records;
      });

  Future<void> save(SessionRecord record) => _serial(() async {
        final records = await _readAll();
        records.removeWhere((r) => r.id == record.id);
        records.add(SessionRecord.fromJson(record.toJson()));
        await _writeAll(records);
      });

  /// Marks sessions that were still in progress (app closed mid-session) as
  /// interrupted. [activeId] is excluded so a live session is never touched.
  Future<int> recoverInterrupted(DateTime now, {String? activeId}) =>
      _serial(() async {
        final records = await _readAll();
        var changed = 0;
        for (final r in records) {
          if (r.status == SessionStatus.inProgress && r.id != activeId) {
            r.finish(SessionStatus.interrupted, now);
            changed++;
          }
        }
        if (changed > 0) await _writeAll(records);
        return changed;
      });

  Future<void> delete(String id) => _serial(() async {
        final records = await _readAll();
        records.removeWhere((r) => r.id == id);
        await _writeAll(records);
      });

  Future<void> deleteAll() => _serial(() => store.remove(key));
}
