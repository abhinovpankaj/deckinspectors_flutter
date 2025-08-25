import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:realm/realm.dart';

import 'sync_service.dart';
import '../models/realm/realm_schemas.dart';

/// ChangeTracker
/// - Listens to Realm collection changes for common models (project, subProject,
///   location, visual sections, etc.) and coalesces rapid updates into a
///   compact snapshot per root entity (project or subProject).
/// - On debounce expire it sends a single compact snapshot to the server via
///   SyncService.pushToWebSocket. If the socket is not connected it persists an
///   UnsyncedData entry into Realm for later retry.
class ChangeTracker {
  final Realm realm;
  final SyncService syncService;
  final Duration debounceDuration;

  final Map<String, Map<String, dynamic>> _pendingChanges = {};
  final Map<String, Timer> _debounceTimers = {};
  final List<StreamSubscription> _subscriptions = [];

  ChangeTracker(
    this.realm,
    this.syncService, {
    this.debounceDuration = const Duration(milliseconds: 500),
  });

  /// Start listening to collections.
  void start() {
    _listen<Project>(realm.all<Project>(), 'project');
    _listen<SubProject>(realm.all<SubProject>(), 'subProject');
    _listen<Location>(realm.all<Location>(), 'location');
    _listen<VisualSection>(realm.all<VisualSection>(), 'visualSection');
    _listen<InvasiveSection>(realm.all<InvasiveSection>(), 'invasiveSection');
    _listen<ConclusiveSection>(
      realm.all<ConclusiveSection>(),
      'conclusiveSection',
    );
    _listen<DynamicVisualSection>(
      realm.all<DynamicVisualSection>(),
      'dynamicVisualSection',
    );
    _listen<DeckImage>(realm.all<DeckImage>(), 'deckImage');
  }

  /// Stop listening and flush pending changes.
  Future<void> stop() async {
    for (final s in _subscriptions) {
      await s.cancel();
    }
    _subscriptions.clear();
    _cancelAllTimers();
  }

  void _listen<T>(RealmResults<T> results, String collectionName) {
    final sub = results.changes.listen((changes) {
      // Handle inserts
      for (final idx in changes.inserted) {
        try {
          final obj = results[idx];
          _enqueue(obj, collectionName, 'create');
        } catch (e) {
          debugPrint('ChangeTracker: error reading inserted object: $e');
        }
      }

      // Handle modifications
      for (final idx in changes.modified) {
        try {
          final obj = results[idx];
          _enqueue(obj, collectionName, 'update');
        } catch (e) {
          debugPrint('ChangeTracker: error reading modified object: $e');
        }
      }

      // Deleted items: we cannot access object after deletion reliably. The
      // application should call notifyDelete manually when it deletes objects
      // that must be synced immediately.
    });

    _subscriptions.add(sub);
  }

  /// When you perform manual deletes through your code, call this to ensure
  /// the deletion is sent/coalesced.
  void notifyDelete(
    String rootCollection,
    ObjectId rootId,
    String childCollection,
    String childId,
  ) {
    final change = {'action': 'delete', 'id': childId};
    final data = {
      'id': rootId.hexString,
      'changes': {childCollection: change},
      'timestamp': DateTime.now().toIso8601String(),
    };

    _sendOrPersist(rootCollection, rootId, data);
  }

  void _enqueue(dynamic obj, String collectionName, String action) {
    final root = _getRootForObject(obj);
    final rootId = (root['rootId'] as ObjectId);
    final rootCollection = root['rootCollection'] as String;

    final item = {
      'action': action,
      'id': obj.id?.hexString ?? '',
      'payload': _serialize(obj),
    };

    final key = rootId.hexString;

    _pendingChanges.putIfAbsent(key, () => <String, dynamic>{});
    // store/replace latest for this collection
    _pendingChanges[key]![collectionName] = item;

    // reset debounce timer
    _debounceTimers[key]?.cancel();
    _debounceTimers[key] = Timer(debounceDuration, () {
      final pending = _pendingChanges.remove(key);
      _debounceTimers.remove(key);
      if (pending != null) {
        final snapshot = {
          'id': rootId.hexString,
          'changes': pending,
          'timestamp': DateTime.now().toIso8601String(),
        };
        _sendOrPersist(rootCollection, rootId, snapshot);
      }
    });
  }

  Map<String, dynamic> _serialize(dynamic obj) {
    try {
      if (obj == null) return {};
      if (obj is Project ||
          obj is SubProject ||
          obj is Location ||
          obj is VisualSection ||
          obj is InvasiveSection ||
          obj is ConclusiveSection ||
          obj is DynamicVisualSection ||
          obj is DeckImage) {
        return obj.toJson();
      }
      return {};
    } catch (e) {
      debugPrint('ChangeTracker: serialization error: $e');
      return {};
    }
  }

  Map<String, dynamic> _getRootForObject(dynamic obj) {
    try {
      if (obj is Project) {
        return {'rootCollection': 'project', 'rootId': obj.id};
      }
      if (obj is SubProject) {
        final parentId = (obj.parentid as ObjectId?);
        return {'rootCollection': 'project', 'rootId': parentId};
      }

      if (obj is Location ||
          obj is VisualSection ||
          obj is InvasiveSection ||
          obj is ConclusiveSection ||
          obj is DynamicVisualSection ||
          obj is DeckImage) {
        final parentType = (obj.parenttype as String?) ?? '';
        final parentId = (obj.parentid as ObjectId?);
        if (parentId != null) {
          if (parentType == 'project') {
            return {'rootCollection': 'project', 'rootId': parentId};
          } else {
            return {'rootCollection': 'subProject', 'rootId': parentId};
          }
        }
      }
    } catch (e) {
      debugPrint('ChangeTracker: error resolving root: $e');
    }
    // fallback
    try {
      return {
        'rootCollection': _inferCollectionName(obj),
        'rootId': obj.id as ObjectId,
      };
    } catch (_) {
      return {'rootCollection': 'project', 'rootId': ObjectId()};
    }
  }

  String _inferCollectionName(dynamic obj) {
    if (obj is Project) return 'project';
    if (obj is SubProject) return 'subProject';
    if (obj is Location) return 'location';
    if (obj is VisualSection) return 'visualSection';
    if (obj is InvasiveSection) return 'invasiveSection';
    if (obj is ConclusiveSection) return 'conclusiveSection';
    if (obj is DynamicVisualSection) return 'dynamicVisualSection';
    if (obj is DeckImage) return 'deckImage';
    return 'project';
  }

  void _sendOrPersist(
    String rootCollection,
    ObjectId rootId,
    Map<String, dynamic> snapshot,
  ) {
    final socketData = {
      'id': rootId.hexString,
      'messageId': rootId.hexString,
      'collectionName': rootCollection,
      'action': 'update',
      'data': jsonEncode(snapshot),
    };

    final sent = syncService.pushToWebSocket(socketData, rootId.hexString);
    if (!sent) {
      try {
        realm.write(() {
          final existing = realm.find<UnsyncedData>(rootId);
          if (existing != null) realm.delete(existing);
          realm.add<UnsyncedData>(
            UnsyncedData(
              rootId,
              'update',
              rootCollection,
              jsonEncode(snapshot),
              DateTime.now().toString(),
            ),
            update: true,
          );
        });
      } catch (e) {
        debugPrint('ChangeTracker: error persisting unsynced snapshot: $e');
      }
    }
  }

  void _cancelAllTimers() {
    for (final t in _debounceTimers.values) {
      t.cancel();
    }
    _debounceTimers.clear();
  }
}
