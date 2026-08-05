import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:retro_eshop/models/config/app_config.dart';
import 'package:retro_eshop/models/config/source.dart';
import 'package:retro_eshop/services/config_storage_service.dart';
import 'package:retro_eshop/services/database_service.dart';
import 'package:retro_eshop/services/sources_notifier.dart';

/// Source groups: several sources the user declares to be **one server**.
///
/// Two things are being guarded here. First, that a group is only ever what
/// the user could have meant — two or more sources, same type, each in one
/// group at most. Second, that the cached library follows the group rather
/// than the member: joining merges the lists, and leaving does not split one,
/// because after a merge nothing records which member first saw a game.
class _SpyDb extends DatabaseService {
  final adopted = <({String owner, List<String> members})>[];
  final moved = <({String from, String to})>[];
  final released = <({String source, String owner})>[];
  final purged = <({String source, Set<String> protected})>[];

  @override
  Future<int> adoptCacheInto({
    required String ownerId,
    required Iterable<String> memberIds,
  }) async {
    adopted.add((owner: ownerId, members: memberIds.toList()));
    return 0;
  }

  @override
  Future<int> moveCacheOwnership({
    required String fromOwnerId,
    required String toOwnerId,
  }) async {
    moved.add((from: fromOwnerId, to: toOwnerId));
    return 0;
  }

  @override
  Future<int> releaseCacheFrom({
    required String sourceId,
    required String ownerId,
  }) async {
    released.add((source: sourceId, owner: ownerId));
    return 0;
  }

  @override
  Future<({int detached, int deleted})> purgeOrDetachSource(
    String sourceId, {
    required Map<String, String> systemTargetFolders,
    Set<String> protectedOwnerIds = const {},
  }) async {
    purged.add((source: sourceId, protected: protectedOwnerIds));
    return (detached: 0, deleted: 0);
  }
}

ConfigStorageService _storageInTempDir() {
  final dir = Directory.systemTemp.createTempSync('rshop_groups_test_');
  addTearDown(() async {
    try {
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (_) {}
  });
  return ConfigStorageService(directoryProvider: () async => dir);
}

Source _src(String id, {SourceType type = SourceType.romm}) => Source(
      id: id,
      name: id.toUpperCase(),
      type: type,
      url: 'http://$id.local:8090',
      autoMap: true,
    );

Future<(SourcesNotifier, _SpyDb)> _seeded({
  ConfigStorageService? storage,
  List<Source>? sources,
}) async {
  final db = _SpyDb();
  final notifier = SourcesNotifier(storage ?? _storageInTempDir(), db: db);
  await notifier.ready;
  for (final s in sources ?? [_src('lan'), _src('wan')]) {
    await notifier.addSource(s);
  }
  return (notifier, db);
}

void main() {
  group('createGroup', () {
    test('groups two sources, first one preferred', () async {
      final (notifier, _) = await _seeded();

      final group = await notifier.createGroup(memberIds: ['lan', 'wan']);

      expect(group, isNotNull);
      expect(group!.memberIds, ['lan', 'wan']);
      expect(group.preferredMemberId, 'lan');
      expect(group.mode, SourceGroupMode.ordered);
      expect(notifier.state.groupContaining('wan')?.id, group.id);
    });

    test('the first member keeps the cache, so nothing re-syncs', () async {
      final (notifier, db) = await _seeded();

      final group = await notifier.createGroup(memberIds: ['lan', 'wan']);

      expect(group!.cacheOwnerId, 'lan');
      expect(db.adopted.single.owner, 'lan');
      expect(db.adopted.single.members, ['lan', 'wan']);
    });

    test('names itself after the preferred member when unnamed', () async {
      final (notifier, _) = await _seeded();

      final group = await notifier.createGroup(memberIds: ['lan', 'wan']);

      expect(group!.name, 'LAN');
    });

    test('refuses a group of one — a plain source already says that', () async {
      final (notifier, _) = await _seeded();

      expect(await notifier.createGroup(memberIds: ['lan']), isNull);
      expect(await notifier.createGroup(memberIds: ['lan', 'lan']), isNull);
      expect(notifier.state.groups, isEmpty);
    });

    test('refuses mixed types — two protocols are not one server', () async {
      final (notifier, _) = await _seeded(
        sources: [_src('lan'), _src('nas', type: SourceType.smb)],
      );

      expect(
        await notifier.createGroup(memberIds: ['lan', 'nas']),
        isNull,
      );
    });

    test('refuses a source that is already in a group', () async {
      final (notifier, _) = await _seeded(
        sources: [_src('lan'), _src('wan'), _src('vpn')],
      );
      await notifier.createGroup(memberIds: ['lan', 'wan']);

      expect(await notifier.createGroup(memberIds: ['wan', 'vpn']), isNull);
      expect(notifier.state.groups, hasLength(1));
    });

    test('survives a reload', () async {
      final storage = _storageInTempDir();
      final (notifier, _) = await _seeded(storage: storage);
      await notifier.createGroup(memberIds: ['lan', 'wan'], name: '家裡');

      final reloaded = SourcesNotifier(storage, db: _SpyDb());
      await reloaded.ready;

      final group = reloaded.state.groups.single;
      expect(group.name, '家裡');
      expect(group.memberIds, ['lan', 'wan']);
      expect(group.cacheOwnerId, 'lan');
    });
  });

  group('editing a group', () {
    test('renaming keeps the members', () async {
      final (notifier, _) = await _seeded();
      final group = await notifier.createGroup(memberIds: ['lan', 'wan']);

      await notifier.renameGroup(group!.id, '家裡的 RomM');

      expect(notifier.state.groups.single.name, '家裡的 RomM');
      expect(notifier.state.groups.single.memberIds, ['lan', 'wan']);
    });

    test('the mode switches and the order is kept either way', () async {
      final (notifier, _) = await _seeded();
      final group = await notifier.createGroup(memberIds: ['lan', 'wan']);

      await notifier.setGroupMode(group!.id, SourceGroupMode.auto);
      expect(notifier.state.groups.single.mode, SourceGroupMode.auto);
      expect(notifier.state.groups.single.memberIds, ['lan', 'wan']);

      await notifier.setGroupMode(group.id, SourceGroupMode.ordered);
      expect(notifier.state.groups.single.memberIds, ['lan', 'wan']);
    });

    test('a new member is appended, not promoted', () async {
      final (notifier, db) = await _seeded(
        sources: [_src('lan'), _src('wan'), _src('vpn')],
      );
      final group = await notifier.createGroup(memberIds: ['lan', 'wan']);

      expect(await notifier.addToGroup(group!.id, 'vpn'), isTrue);

      expect(notifier.state.groups.single.memberIds, ['lan', 'wan', 'vpn']);
      expect(db.adopted.last.owner, 'lan');
      expect(db.adopted.last.members, ['vpn']);
    });

    test('a member of another type is refused', () async {
      final (notifier, _) = await _seeded(
        sources: [_src('lan'), _src('wan'), _src('nas', type: SourceType.smb)],
      );
      final group = await notifier.createGroup(memberIds: ['lan', 'wan']);

      expect(await notifier.addToGroup(group!.id, 'nas'), isFalse);
      expect(notifier.state.groups.single.memberIds, ['lan', 'wan']);
    });

    test('reordering states a preference without moving the cache', () async {
      final (notifier, db) = await _seeded(
        sources: [_src('lan'), _src('wan'), _src('vpn')],
      );
      final group = await notifier.createGroup(
        memberIds: ['lan', 'wan', 'vpn'],
      );

      await notifier.reorderGroupMembers(group!.id, ['vpn', 'lan', 'wan']);

      expect(notifier.state.groups.single.memberIds, ['vpn', 'lan', 'wan']);
      // The rows stay under the id they were written with: reordering says
      // which server to talk to first, not where to keep the library.
      expect(notifier.state.groups.single.cacheOwnerId, 'lan');
      expect(db.moved, isEmpty);
    });

    test('moveGroupMember is the button form of the same thing', () async {
      final (notifier, _) = await _seeded(
        sources: [_src('lan'), _src('wan'), _src('vpn')],
      );
      final group = await notifier.createGroup(
        memberIds: ['lan', 'wan', 'vpn'],
      );

      await notifier.moveGroupMember(group!.id, 'vpn', 0);

      expect(notifier.state.groups.single.memberIds, ['vpn', 'lan', 'wan']);
    });
  });

  group('leaving a group', () {
    test('a plain member leaves with nothing and has to re-sync', () async {
      final (notifier, db) = await _seeded(
        sources: [_src('lan'), _src('wan'), _src('vpn')],
      );
      final group = await notifier.createGroup(
        memberIds: ['lan', 'wan', 'vpn'],
      );

      await notifier.removeFromGroup(group!.id, 'wan');

      expect(notifier.state.groups.single.memberIds, ['lan', 'vpn']);
      expect(db.released.single, (source: 'wan', owner: 'lan'));
      expect(db.moved, isEmpty);
    });

    test('when the owner leaves, the library goes to the next member',
        () async {
      final (notifier, db) = await _seeded(
        sources: [_src('lan'), _src('wan'), _src('vpn')],
      );
      final group = await notifier.createGroup(
        memberIds: ['lan', 'wan', 'vpn'],
      );

      await notifier.removeFromGroup(group!.id, 'lan');

      expect(db.moved.single, (from: 'lan', to: 'wan'));
      expect(notifier.state.groups.single.cacheOwnerId, 'wan');
    });

    test('a group down to one member is dissolved', () async {
      final (notifier, _) = await _seeded();
      final group = await notifier.createGroup(memberIds: ['lan', 'wan']);

      await notifier.removeFromGroup(group!.id, 'wan');

      expect(notifier.state.groups, isEmpty);
      expect(notifier.state.sources.map((s) => s.id), ['lan', 'wan']);
    });

    test('dissolving leaves the library with its owner', () async {
      final (notifier, db) = await _seeded(
        sources: [_src('lan'), _src('wan'), _src('vpn')],
      );
      final group = await notifier.createGroup(
        memberIds: ['lan', 'wan', 'vpn'],
      );

      await notifier.dissolveGroup(group!.id);

      expect(notifier.state.groups, isEmpty);
      expect(notifier.state.sources, hasLength(3));
      expect(db.released.map((r) => r.source), ['wan', 'vpn']);
      expect(db.released.every((r) => r.owner == 'lan'), isTrue);
    });
  });

  group('deleting a grouped source', () {
    test('the survivors keep the shared library', () async {
      final (notifier, db) = await _seeded(
        sources: [_src('lan'), _src('wan'), _src('vpn')],
      );
      final group = await notifier.createGroup(
        memberIds: ['lan', 'wan', 'vpn'],
      );

      await notifier.removeSource('wan');

      expect(notifier.state.groups.single.memberIds, ['lan', 'vpn']);
      expect(db.released.single, (source: 'wan', owner: 'lan'));
      // Purge matches the provider_config blob, which still names the deleted
      // source on rows it fetched for the group. Those rows are the group's.
      expect(db.purged.single.protected, {'lan'});
      expect(group!.id, notifier.state.groups.single.id);
    });

    test('deleting the owner hands the library over first', () async {
      final (notifier, db) = await _seeded(
        sources: [_src('lan'), _src('wan'), _src('vpn')],
      );
      await notifier.createGroup(memberIds: ['lan', 'wan', 'vpn']);

      await notifier.removeSource('lan');

      expect(db.moved.single, (from: 'lan', to: 'wan'));
      expect(db.purged.single.protected, {'wan'});
      expect(notifier.state.groups.single.cacheOwnerId, 'wan');
    });

    test('deleting one of a pair leaves the other holding the library',
        () async {
      final (notifier, db) = await _seeded();
      await notifier.createGroup(memberIds: ['lan', 'wan']);

      await notifier.removeSource('wan');

      // The group is gone — one source is not a group — but the survivor must
      // not be made to re-sync a library it was already sharing.
      expect(notifier.state.groups, isEmpty);
      expect(db.purged.single.protected, {'lan'});
    });

    test('an ungrouped source protects nothing', () async {
      final (notifier, db) = await _seeded();

      await notifier.removeSource('wan');

      expect(db.purged.single.protected, isEmpty);
    });
  });
}
