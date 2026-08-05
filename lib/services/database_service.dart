import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/config/provider_config.dart';
import '../models/game_item.dart';
import '../models/game_metadata_info.dart';
import '../models/ra_models.dart';
import '../utils/ra_name_matcher.dart';

class DatabaseService {
  static Future<Database>? _initFuture;
  static const String _tableName = 'games';
  static const int _dbVersion = 16;

  @visibleForTesting
  static Database? testDatabase;

  Future<Database> get database {
    if (testDatabase != null) return Future.value(testDatabase!);
    return _initFuture ??= _initDatabase();
  }

  @visibleForTesting
  static void resetForTesting() {
    _initFuture = null;
    testDatabase = null;
  }

  /// The version the app opens its database with. Exposed so a migration test
  /// can prove the upgrade it exercises is the one users will actually run.
  @visibleForTesting
  static int get schemaVersion => _dbVersion;

  /// Runs the real upgrade path against a caller-supplied [db].
  ///
  /// Migration tests use this instead of opening the app's own file: test
  /// files run in parallel, and several of them touch that one file.
  @visibleForTesting
  Future<void> upgradeForTesting(Database db, int fromVersion) =>
      _onUpgrade(db, fromVersion, _dbVersion);

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'rshop.db');

    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $_tableName (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        systemSlug TEXT NOT NULL,
        filename TEXT NOT NULL,
        displayName TEXT NOT NULL,
        url TEXT NOT NULL,
        region TEXT,
        cover_url TEXT,
        provider_config TEXT,
        thumb_hash TEXT,
        has_thumbnail INTEGER NOT NULL DEFAULT 0,
        is_folder INTEGER NOT NULL DEFAULT 0,
        alternative_sources TEXT,
        source_id TEXT NOT NULL DEFAULT '',
        endpoint_id TEXT NOT NULL DEFAULT '',
        cache_owner_id TEXT NOT NULL DEFAULT ''
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_systemSlug ON $_tableName (systemSlug)
    ''');

    await db.execute('''
      CREATE INDEX idx_displayName ON $_tableName (displayName)
    ''');

    await db.execute('''
      CREATE INDEX idx_filename ON $_tableName (filename)
    ''');

    // Uniqueness is per *cache owner*. The owner is the group when the source
    // belongs to one, otherwise the source itself — the user declaring "these
    // sources are the same server" is the same declaration as "these routes
    // are the same server", one level up, and it has the same consequence:
    // one list, not one copy per member.
    //
    // source_id and endpoint_id both stay as plain columns. They record who
    // last fetched a row, which is useful for attribution and for re-stamping
    // when a member leaves — but neither is in the key. Keying on them stored
    // the same list once per member and nothing could tell whether those
    // copies were supposed to agree.
    //
    // cache_owner_id is NOT NULL DEFAULT '' on purpose — SQLite treats NULLs
    // as distinct inside a UNIQUE index, so a nullable column here would
    // silently stop deduplicating local scans (which belong to no owner).
    await db.execute('''
      CREATE UNIQUE INDEX idx_games_system_filename_owner
        ON $_tableName (systemSlug, filename, cache_owner_id)
    ''');

    await db.execute('''
      CREATE INDEX idx_games_owner ON $_tableName (cache_owner_id)
    ''');

    // Still indexed even though it left the key: re-stamping a departing
    // member and purgeOrDetachSource both look rows up by source.
    await db.execute('''
      CREATE INDEX idx_games_source ON $_tableName (source_id)
    ''');

    // RetroAchievements tables
    await db.execute('''
      CREATE TABLE ra_games (
        ra_game_id INTEGER PRIMARY KEY,
        console_id INTEGER NOT NULL,
        title TEXT NOT NULL,
        num_achievements INTEGER NOT NULL DEFAULT 0,
        points INTEGER NOT NULL DEFAULT 0,
        image_icon TEXT,
        normalized_title TEXT NOT NULL,
        last_updated INTEGER NOT NULL
      )
    ''');
    await db.execute(
        'CREATE INDEX idx_ra_games_console ON ra_games(console_id)');
    await db.execute(
        'CREATE INDEX idx_ra_games_norm_title ON ra_games(normalized_title)');
    await db.execute('''
      CREATE TABLE ra_hashes (
        hash TEXT PRIMARY KEY,
        ra_game_id INTEGER NOT NULL,
        rom_name TEXT
      )
    ''');
    await db.execute(
        'CREATE INDEX idx_ra_hashes_game ON ra_hashes(ra_game_id)');
    await db.execute('''
      CREATE TABLE ra_matches (
        game_filename TEXT NOT NULL,
        system_slug TEXT NOT NULL,
        ra_game_id INTEGER,
        match_type TEXT NOT NULL,
        is_mastered INTEGER NOT NULL DEFAULT 0,
        last_updated INTEGER NOT NULL,
        PRIMARY KEY (game_filename, system_slug)
      )
    ''');

    // Game metadata from RomM/IGDB
    await db.execute('''
      CREATE TABLE game_metadata (
        filename TEXT NOT NULL,
        system_slug TEXT NOT NULL,
        summary TEXT,
        genres TEXT,
        developer TEXT,
        publisher TEXT,
        release_year INTEGER,
        release_date TEXT,
        game_modes TEXT,
        rating REAL,
        franchises TEXT,
        themes TEXT,
        player_perspectives TEXT,
        age_rating TEXT,
        screenshots TEXT,
        file_size INTEGER,
        siblings TEXT,
        last_updated INTEGER NOT NULL,
        PRIMARY KEY (filename, system_slug)
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Each migration step is wrapped in a transaction so a partial failure
    // (e.g. disk full) doesn't leave the DB in a half-migrated state.
    // Note: SQLite DDL (ALTER TABLE) is transactional in SQLite.
    if (oldVersion < 2) {
      await db.transaction((txn) async {
        await txn.execute('ALTER TABLE $_tableName ADD COLUMN cover_url TEXT');
        await txn.execute(
            'CREATE INDEX IF NOT EXISTS idx_filename ON $_tableName (filename)');
      });
    }
    if (oldVersion < 3) {
      await db.transaction((txn) async {
        await txn.execute(
            'ALTER TABLE $_tableName ADD COLUMN provider_config TEXT');
      });
    }
    if (oldVersion < 4) {
      await db.transaction((txn) async {
        await txn.execute(
            'ALTER TABLE $_tableName ADD COLUMN thumb_hash TEXT');
        await txn.execute(
            'ALTER TABLE $_tableName ADD COLUMN has_thumbnail INTEGER NOT NULL DEFAULT 0');
      });
    }
    if (oldVersion < 5) {
      await db.transaction((txn) async {
        await txn.execute(
            'ALTER TABLE $_tableName ADD COLUMN is_folder INTEGER NOT NULL DEFAULT 0');
      });
    }
    if (oldVersion < 6) {
      await db.transaction((txn) async {
        await txn.execute('''
          CREATE TABLE ra_games (
            ra_game_id INTEGER PRIMARY KEY,
            console_id INTEGER NOT NULL,
            title TEXT NOT NULL,
            num_achievements INTEGER NOT NULL DEFAULT 0,
            points INTEGER NOT NULL DEFAULT 0,
            image_icon TEXT,
            normalized_title TEXT NOT NULL,
            last_updated INTEGER NOT NULL
          )
        ''');
        await txn.execute(
            'CREATE INDEX idx_ra_games_console ON ra_games(console_id)');
        await txn.execute(
            'CREATE INDEX idx_ra_games_norm_title ON ra_games(normalized_title)');
        await txn.execute('''
          CREATE TABLE ra_hashes (
            hash TEXT PRIMARY KEY,
            ra_game_id INTEGER NOT NULL,
            rom_name TEXT
          )
        ''');
        await txn.execute(
            'CREATE INDEX idx_ra_hashes_game ON ra_hashes(ra_game_id)');
        await txn.execute('''
          CREATE TABLE ra_matches (
            game_filename TEXT NOT NULL,
            system_slug TEXT NOT NULL,
            ra_game_id INTEGER,
            match_type TEXT NOT NULL,
            last_updated INTEGER NOT NULL,
            PRIMARY KEY (game_filename, system_slug)
          )
        ''');
      });
    }
    if (oldVersion < 7) {
      await db.transaction((txn) async {
        await txn.execute(
          'ALTER TABLE ra_matches ADD COLUMN is_mastered INTEGER NOT NULL DEFAULT 0',
        );
      });
    }
    if (oldVersion < 8) {
      await db.transaction((txn) async {
        await txn.execute('''
          CREATE TABLE game_metadata (
            filename TEXT NOT NULL,
            system_slug TEXT NOT NULL,
            summary TEXT,
            genres TEXT,
            developer TEXT,
            release_year INTEGER,
            game_modes TEXT,
            rating REAL,
            last_updated INTEGER NOT NULL,
            PRIMARY KEY (filename, system_slug)
          )
        ''');
      });
    }
    if (oldVersion < 9) {
      await db.transaction((txn) async {
        // Remove any duplicate (systemSlug, filename) rows before adding constraint
        await txn.execute('''
          DELETE FROM $_tableName WHERE id NOT IN (
            SELECT MIN(id) FROM $_tableName GROUP BY systemSlug, filename
          )
        ''');
        await txn.execute(
          'CREATE UNIQUE INDEX idx_games_system_filename ON $_tableName (systemSlug, filename)',
        );
      });
    }
    if (oldVersion < 10) {
      await db.transaction((txn) async {
        await txn.execute(
          'CREATE INDEX IF NOT EXISTS idx_has_thumbnail ON $_tableName (has_thumbnail)',
        );
      });
    }
    if (oldVersion < 11) {
      await db.transaction((txn) async {
        await txn.execute(
            'ALTER TABLE game_metadata ADD COLUMN publisher TEXT');
        await txn.execute(
            'ALTER TABLE game_metadata ADD COLUMN release_date TEXT');
        await txn.execute(
            'ALTER TABLE game_metadata ADD COLUMN franchises TEXT');
        await txn.execute(
            'ALTER TABLE game_metadata ADD COLUMN themes TEXT');
        await txn.execute(
            'ALTER TABLE game_metadata ADD COLUMN player_perspectives TEXT');
        await txn.execute(
            'ALTER TABLE game_metadata ADD COLUMN age_rating TEXT');
      });
    }
    if (oldVersion < 12) {
      await db.transaction((txn) async {
        await txn.execute(
            'ALTER TABLE game_metadata ADD COLUMN screenshots TEXT');
        await txn.execute(
            'ALTER TABLE game_metadata ADD COLUMN file_size INTEGER');
        await txn.execute(
            'ALTER TABLE game_metadata ADD COLUMN siblings TEXT');
      });
    }
    if (oldVersion < 13) {
      // alternative_sources: JSON list serialised by AlternativeSource.toJson.
      // Carries the merged secondary sources for a game so the grid can
      // render multi-source dots and the detail screen's "from <source>"
      // download picker survives a DB roundtrip.
      await db.transaction((txn) async {
        await txn.execute(
            'ALTER TABLE $_tableName ADD COLUMN alternative_sources TEXT');
      });
    }
    if (oldVersion < 14) {
      // Per-route game lists. Until now a game was unique per (system,
      // filename), so the same server reached two ways overwrote itself and
      // switching routes meant a full re-sync. Promoting source_id out of the
      // provider_config JSON blob and adding endpoint_id lets each route keep
      // its own list — and makes "by source" queries an indexed lookup instead
      // of a LIKE scan over serialised JSON.
      await db.transaction((txn) async {
        await txn.execute(
          "ALTER TABLE $_tableName ADD COLUMN source_id TEXT NOT NULL DEFAULT ''",
        );
        await txn.execute(
          "ALTER TABLE $_tableName ADD COLUMN endpoint_id TEXT NOT NULL DEFAULT ''",
        );

        // Backfill from the JSON blob that has carried source_id all along.
        // json_extract is available in the SQLite bundled with sqflite; fall
        // back to leaving '' rather than failing the whole migration, because
        // an empty route still works — it just starts a fresh list.
        try {
          await txn.rawUpdate(
            "UPDATE $_tableName SET source_id = "
            "COALESCE(json_extract(provider_config, '\$.source_id'), '') "
            'WHERE provider_config IS NOT NULL',
          );
        } catch (e) {
          debugPrint('migration v14: json_extract backfill skipped: $e');
        }

        // Everything that pre-dates routes belongs to the endpoint that
        // Source.fromJson synthesises from the legacy connection fields.
        await txn.rawUpdate(
          "UPDATE $_tableName SET endpoint_id = 'primary' WHERE source_id != ''",
        );

        await txn.execute('DROP INDEX IF EXISTS idx_games_system_filename');
        await txn.execute(
          'CREATE UNIQUE INDEX idx_games_system_filename_route '
          'ON $_tableName (systemSlug, filename, source_id, endpoint_id)',
        );
        await txn.execute(
          'CREATE INDEX IF NOT EXISTS idx_games_route '
          'ON $_tableName (source_id, endpoint_id)',
        );
      });
    }
    if (oldVersion < 15) {
      // One list per *source*, not per route. v14 gave every route its own
      // copy of the list, but the routes of one source are the same server by
      // another address — so those copies were duplicates of one another that
      // nothing could reconcile. Collapse them back to a single row per
      // (system, filename, source) and re-key the unique index without
      // endpoint_id. endpoint_id survives as a plain column: it still records
      // which route last fetched the row.
      await db.transaction((txn) async {
        // The dedupe join below is a self-join over the whole games table;
        // without an index on the group key it degrades to a scan per row.
        // Dropped again once the real unique index is in place.
        await txn.execute(
          'CREATE INDEX IF NOT EXISTS idx_games_dedupe_tmp '
          'ON $_tableName (source_id, systemSlug, filename)',
        );

        final collapsed = await _collapseDuplicates(txn, keyColumn: 'source_id');
        if (collapsed > 0) {
          debugPrint('migration v15: collapsed $collapsed duplicate rows');
        }

        // Safety net. The pass above provably leaves one row per group, but a
        // leftover duplicate here would make CREATE UNIQUE INDEX throw, and a
        // migration that throws on every launch is an unopenable database.
        final swept = await txn.rawDelete('''
          DELETE FROM $_tableName WHERE id NOT IN (
            SELECT MIN(id) FROM $_tableName
            GROUP BY systemSlug, filename, source_id
          )
        ''');
        if (swept > 0) {
          debugPrint('migration v15: safety sweep removed $swept rows');
        }

        await txn.execute(
            'DROP INDEX IF EXISTS idx_games_system_filename_route');
        await txn.execute(
          'CREATE UNIQUE INDEX idx_games_system_filename_source '
          'ON $_tableName (systemSlug, filename, source_id)',
        );
        await txn.execute('DROP INDEX IF EXISTS idx_games_route');
        await txn.execute('DROP INDEX IF EXISTS idx_games_dedupe_tmp');
        await txn.execute(
          'CREATE INDEX IF NOT EXISTS idx_games_source '
          'ON $_tableName (source_id)',
        );
      });
    }
    if (oldVersion < 16) {
      // One list per *cache owner*. A source owns its own list until the user
      // puts it in a group; then the group owns it, because a group is the
      // user declaring that its members are one server — the same declaration
      // that collapsed a source's routes in v15, one level up.
      //
      // **This step deletes nothing.** The backfill is one-to-one
      // (`cache_owner_id = source_id`), so the new unique key holds exactly the
      // rows the old one did and no duplicate can appear. The merging — and
      // therefore the only de-duplication groups need — happens later, in
      // [adoptCacheInto], when the config layer tells us which sources the user
      // actually grouped. That split is deliberate: groups live in the config
      // file, which this layer cannot read, and a migration that guesses at
      // them would be a migration that deletes rows on a guess.
      await db.transaction((txn) async {
        await txn.execute(
          "ALTER TABLE $_tableName ADD COLUMN cache_owner_id TEXT NOT NULL DEFAULT ''",
        );
        await txn.rawUpdate('UPDATE $_tableName SET cache_owner_id = source_id');

        await txn.execute(
            'DROP INDEX IF EXISTS idx_games_system_filename_source');
        await txn.execute(
          'CREATE UNIQUE INDEX idx_games_system_filename_owner '
          'ON $_tableName (systemSlug, filename, cache_owner_id)',
        );
        await txn.execute(
          'CREATE INDEX IF NOT EXISTS idx_games_owner '
          'ON $_tableName (cache_owner_id)',
        );
        // idx_games_source stays even though source_id left the key:
        // re-stamping a departing member and purgeOrDetachSource both look
        // rows up by the source that fetched them.
      });
    }
  }

  /// 0 for rows that are only in the table because the file is on the device
  /// (`purgeOrDetachSource` nulls `provider_config`/`url` for those), 1 for
  /// rows that still point at a server. Lower wins de-duplication.
  ///
  /// Named for v15, which introduced it, but it is now the single de-dup
  /// criterion for groups as well: dropping an on-device row makes the library
  /// forget a game the user has actually downloaded, while a row that still
  /// carries a remote url can always be re-fetched. Change the signal here and
  /// every collapse changes with it.
  static String _onDeviceRank(String alias) =>
      'CASE WHEN $alias.provider_config IS NULL '
      "OR $alias.url IS NULL OR $alias.url = '' THEN 0 ELSE 1 END";

  /// Collapses rows that are the same game under the same [keyColumn] down to
  /// one, salvaging the expensive fields onto the survivor. Returns how many
  /// rows it deleted.
  ///
  /// One shape, three callers: v15 collapsed a source's per-route copies, and
  /// [adoptCacheInto]/[moveCacheOwnership] collapse a group's per-member ones.
  ///
  /// The caller must make sure no unique index is in the way — a duplicate
  /// cannot exist while one is enforced, so every caller either has not created
  /// it yet (migration) or drops it for the duration ([_rekeyOwnership]).
  static Future<int> _collapseDuplicates(
    DatabaseExecutor txn, {
    required String keyColumn,
  }) async {
    // Pick the survivor of each duplicate group by a *total* order, so exactly
    // one row can survive: on-device copies first, then the oldest id. Finding
    // the losers rather than the winners is what makes that guarantee hold —
    // "keep the winner" leaves ties alive.
    final rankA = _onDeviceRank('a');
    final rankB = _onDeviceRank('b');
    final loserRows = await txn.rawQuery('''
      SELECT DISTINCT a.id AS id
      FROM $_tableName a
      JOIN $_tableName b
        ON b.$keyColumn = a.$keyColumn
       AND b.systemSlug = a.systemSlug
       AND b.filename = a.filename
       AND b.id <> a.id
      WHERE ($rankB) < ($rankA)
         OR (($rankB) = ($rankA) AND b.id < a.id)
    ''');
    final losers = loserRows.map((r) => r['id'] as int).toList();
    if (losers.isEmpty) return 0;

    // Salvage before deleting: covers and thumbnails are expensive to rebuild,
    // and the survivor may be the copy that never had them. Every value
    // written here already existed inside the same group.
    final group = 'c.$keyColumn = $_tableName.$keyColumn '
        'AND c.systemSlug = $_tableName.systemSlug '
        'AND c.filename = $_tableName.filename';
    await txn.rawUpdate('''
      UPDATE $_tableName SET
        cover_url = COALESCE(cover_url, (
          SELECT c.cover_url FROM $_tableName c
          WHERE $group AND c.cover_url IS NOT NULL
          ORDER BY c.id LIMIT 1)),
        has_thumbnail = COALESCE((
          SELECT MAX(c.has_thumbnail) FROM $_tableName c
          WHERE $group), has_thumbnail),
        alternative_sources = COALESCE(alternative_sources, (
          SELECT c.alternative_sources FROM $_tableName c
          WHERE $group AND c.alternative_sources IS NOT NULL
          ORDER BY c.id LIMIT 1))
      WHERE EXISTS (
        SELECT 1 FROM $_tableName c WHERE $group AND c.id <> $_tableName.id)
    ''');

    for (var i = 0; i < losers.length; i += 200) {
      final chunk = losers.skip(i).take(200).toList();
      final placeholders = List.filled(chunk.length, '?').join(',');
      await txn.rawDelete(
        'DELETE FROM $_tableName WHERE id IN ($placeholders)',
        chunk,
      );
    }
    return losers.length;
  }

  /// Moves every row owned by [fromOwners] under [toOwner] and collapses what
  /// that makes duplicate. Returns the number of rows dropped as duplicates.
  ///
  /// The unique index is dropped for the duration and rebuilt inside the same
  /// transaction. It has to be: re-stamping the owner column is exactly the
  /// operation the index forbids, so the alternative is reconciling row by row
  /// in Dart — a second de-dup rule that would drift from [_collapseDuplicates]
  /// the first time either changed. Rebuilding it also *proves* the collapse
  /// worked; if a duplicate survived, `CREATE UNIQUE INDEX` throws and the
  /// whole transaction rolls back rather than leaving the user a half-merged
  /// library.
  static Future<int> _rekeyOwnership(
    DatabaseExecutor txn, {
    required String toOwner,
    required List<String> fromOwners,
  }) async {
    if (fromOwners.isEmpty) return 0;
    final placeholders = List.filled(fromOwners.length, '?').join(',');

    await txn.execute('DROP INDEX IF EXISTS idx_games_system_filename_owner');
    await txn.rawUpdate(
      'UPDATE $_tableName SET cache_owner_id = ? '
      'WHERE cache_owner_id IN ($placeholders)',
      [toOwner, ...fromOwners],
    );

    final collapsed =
        await _collapseDuplicates(txn, keyColumn: 'cache_owner_id');

    // Safety net, same as v15: the pass above provably leaves one row per
    // group, but a leftover here would make the index rebuild throw.
    final swept = await txn.rawDelete('''
      DELETE FROM $_tableName WHERE id NOT IN (
        SELECT MIN(id) FROM $_tableName
        GROUP BY systemSlug, filename, cache_owner_id
      )
    ''');
    if (swept > 0) {
      debugPrint('_rekeyOwnership: safety sweep removed $swept rows');
    }

    await txn.execute(
      'CREATE UNIQUE INDEX idx_games_system_filename_owner '
      'ON $_tableName (systemSlug, filename, cache_owner_id)',
    );
    return collapsed + swept;
  }

  /// Folds the cached libraries of [memberIds] into the one owned by
  /// [ownerId] — what joining a group means for the database.
  ///
  /// A group is one server, so it has one list. Merging is not optional
  /// bookkeeping: leaving each member its own copy would show the user the
  /// same games twice on the home screen and let the copies drift apart with
  /// nothing able to reconcile them.
  ///
  /// De-duplication uses [_onDeviceRank] — the copy the user has downloaded
  /// survives. Everything happens in one transaction, so a failure leaves the
  /// libraries exactly as they were.
  Future<int> adoptCacheInto({
    required String ownerId,
    required Iterable<String> memberIds,
  }) async {
    if (ownerId.isEmpty) return 0;
    final from = memberIds.where((id) => id.isNotEmpty && id != ownerId).toSet();
    if (from.isEmpty) return 0;
    final db = await database;
    return db.transaction(
      (txn) => _rekeyOwnership(txn, toOwner: ownerId, fromOwners: from.toList()),
    );
  }

  /// Hands a group's cached library from [fromOwnerId] to [toOwnerId] — what
  /// the *owner itself* leaving a group means for the database.
  ///
  /// `SourceGroup.withoutMember` re-points ownership to the first remaining
  /// member; without this the rows would stay behind under the departed id and
  /// the group would look freshly empty. Call both in the same step.
  Future<int> moveCacheOwnership({
    required String fromOwnerId,
    required String toOwnerId,
  }) async {
    if (fromOwnerId.isEmpty || toOwnerId.isEmpty) return 0;
    if (fromOwnerId == toOwnerId) return 0;
    final db = await database;
    return db.transaction(
      (txn) =>
          _rekeyOwnership(txn, toOwner: toOwnerId, fromOwners: [fromOwnerId]),
    );
  }

  /// Cuts [sourceId] loose from the library owned by [ownerId] — what a
  /// *non-owning* member leaving a group means for the database.
  ///
  /// **The leaver keeps nothing.** The rows are the group's, and there is no
  /// honest way to split them: after a merge nothing records which member first
  /// saw a given game, and the whole point of the group was that the answer did
  /// not matter. So the source leaves with an empty library and re-syncs —
  /// which is why the UI has to confirm this before calling it.
  ///
  /// What this does do is re-stamp `source_id` to the owner, so that removing
  /// the departed source later cannot take the group's rows with it as
  /// collateral. Returns the number of rows re-stamped.
  Future<int> releaseCacheFrom({
    required String sourceId,
    required String ownerId,
  }) async {
    if (sourceId.isEmpty || ownerId.isEmpty || sourceId == ownerId) return 0;
    final db = await database;
    return db.rawUpdate(
      'UPDATE $_tableName SET source_id = ? '
      'WHERE source_id = ? AND cache_owner_id = ?',
      [ownerId, sourceId, ownerId],
    );
  }

  /// Persists [games] for one system **within one cached library**.
  ///
  /// [sourceId] says which source fetched them; it defaults to `''`, the bucket
  /// local filesystem scans live in — local files belong to no source.
  /// [endpointId] is recorded, not keyed on: it remembers which route last
  /// fetched these rows.
  ///
  /// [cacheOwnerId] says whose list they go into, and defaults to [sourceId] —
  /// a source owns its own library until the user puts it in a group. Pass
  /// `AppConfig.cacheOwnerIdFor(sourceId)` and grouped members write into the
  /// group's single list, so re-syncing over any member updates it in place
  /// exactly the way re-syncing over another route already did.
  ///
  /// Orphan deletion is scoped to that library. The scoping is what stops a
  /// sync of one source deleting another's rows as "orphans" — and, within a
  /// group, what lets one member's sync prune games the server no longer has.
  Future<void> saveGames(
    String systemSlug,
    List<GameItem> games, {
    bool deleteOrphans = false,
    bool forceDeleteOrphans = false,
    String sourceId = '',
    String endpointId = '',
    String? cacheOwnerId,
  }) async {
    final owner = cacheOwnerId ?? sourceId;
    final db = await database;
    await db.transaction((txn) async {
      // 1. Delete orphans when requested.
      // forceDeleteOrphans: unconditional (safe for local filesystem scans).
      // deleteOrphans: guarded — blocks mass deletion from incomplete fetches.
      if (deleteOrphans || forceDeleteOrphans) {
        final existing = await txn.query(
          _tableName,
          columns: ['filename'],
          where: 'systemSlug = ? AND cache_owner_id = ?',
          whereArgs: [systemSlug, owner],
        );
        final existingFiles =
            existing.map((r) => r['filename'] as String).toSet();
        final incomingFiles = games.map((g) => g.filename).toSet();

        final orphans = existingFiles.difference(incomingFiles);
        if (orphans.isNotEmpty) {
          // Safety: if incoming data looks incomplete, skip deletion to prevent
          // data loss from partial fetches (e.g. RomM timeout mid-pagination).
          // forceDeleteOrphans bypasses this for authoritative sources (local scan).
          if (!forceDeleteOrphans &&
              existingFiles.length >= 10 &&
              incomingFiles.length < existingFiles.length ~/ 2) {
            debugPrint(
              'saveGames($systemSlug): BLOCKED orphan deletion — '
              'incoming ${incomingFiles.length} vs existing ${existingFiles.length}. '
              'Looks like incomplete fetch data.',
            );
          } else {
            final orphanList = orphans.toList();
            for (var i = 0; i < orphanList.length; i += 100) {
              final chunk = orphanList.skip(i).take(100).toList();
              final placeholders = List.filled(chunk.length, '?').join(',');
              await txn.rawDelete(
                'DELETE FROM $_tableName WHERE systemSlug = ? '
                'AND cache_owner_id = ? '
                'AND filename IN ($placeholders)',
                [systemSlug, owner, ...chunk],
              );
              // Cascade: remove orphaned metadata and RA matches — but only
              // once no source still lists the file. Metadata and achievement
              // matches are keyed by (system, filename) with no source
              // dimension, so deleting them while another source still shows
              // the game would strip its cover and RA progress.
              final stillReferenced = <String>{};
              for (final row in await txn.rawQuery(
                'SELECT DISTINCT filename FROM $_tableName '
                'WHERE systemSlug = ? AND filename IN ($placeholders)',
                [systemSlug, ...chunk],
              )) {
                stillReferenced.add(row['filename'] as String);
              }
              final droppable =
                  chunk.where((f) => !stillReferenced.contains(f)).toList();
              if (droppable.isNotEmpty) {
                final dropPlaceholders =
                    List.filled(droppable.length, '?').join(',');
                await txn.rawDelete(
                  'DELETE FROM game_metadata WHERE system_slug = ? AND filename IN ($dropPlaceholders)',
                  [systemSlug, ...droppable],
                );
                await txn.rawDelete(
                  'DELETE FROM ra_matches WHERE system_slug = ? AND game_filename IN ($dropPlaceholders)',
                  [systemSlug, ...droppable],
                );
              }
            }
          }
        }
      }

      // 2. Upsert incoming games — preserves cover_url and has_thumbnail
      final batch = txn.batch();
      for (final game in games) {
        batch.rawInsert('''
          INSERT INTO $_tableName (systemSlug, filename, displayName, url, region, cover_url, provider_config, has_thumbnail, is_folder, alternative_sources, source_id, endpoint_id, cache_owner_id)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
          ON CONFLICT(systemSlug, filename, cache_owner_id) DO UPDATE SET
            displayName = excluded.displayName,
            url = excluded.url,
            region = excluded.region,
            cover_url = COALESCE(excluded.cover_url, cover_url),
            provider_config = excluded.provider_config,
            has_thumbnail = MAX(has_thumbnail, excluded.has_thumbnail),
            is_folder = excluded.is_folder,
            alternative_sources = excluded.alternative_sources,
            endpoint_id = excluded.endpoint_id,
            source_id = excluded.source_id
        ''', [
          systemSlug,
          game.filename,
          game.displayName,
          game.url,
          _extractRegion(game.filename),
          game.cachedCoverUrl,
          game.providerConfig != null
              ? jsonEncode(game.providerConfig!.toJsonWithoutAuth())
              : null,
          game.hasThumbnail ? 1 : 0,
          game.isFolder ? 1 : 0,
          game.alternativeSources.isEmpty
              ? null
              : jsonEncode(
                  game.alternativeSources.map((a) => a.toJson()).toList()),
          sourceId,
          endpointId,
          owner,
        ]);
      }
      await batch.commit(noResult: true);
    });
  }

  Future<Map<String, int>> getGameCountsPerSystem() async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT systemSlug, COUNT(*) as count FROM $_tableName GROUP BY systemSlug',
    );
    return {
      for (final row in rows)
        row['systemSlug'] as String: row['count'] as int,
    };
  }

  /// Returns remote game counts (games with a remote provider) per system slug.
  /// Local counts are derived from the filesystem via [InstalledFilesProvider].
  Future<Map<String, int>> getRemoteGameCountsPerSystem() async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT systemSlug, COUNT(*) AS remote_count
      FROM $_tableName
      WHERE provider_config IS NOT NULL
      GROUP BY systemSlug
    ''');
    return {
      for (final row in rows)
        row['systemSlug'] as String: (row['remote_count'] as int?) ?? 0,
    };
  }

  Future<void> updateGameCover(String filename, String coverUrl) async {
    final db = await database;
    await db.update(
      _tableName,
      {'cover_url': coverUrl},
      where: 'filename = ?',
      whereArgs: [filename],
    );
  }

  Future<void> updateGameThumbnailData(
    String filename, {
    bool? hasThumbnail,
  }) async {
    if (hasThumbnail == null) return;
    final db = await database;
    await db.update(
      _tableName,
      {'has_thumbnail': hasThumbnail ? 1 : 0},
      where: 'filename = ?',
      whereArgs: [filename],
    );
  }

  Future<void> batchUpdateThumbnailData(
    List<String> filenames, {
    bool? hasThumbnail,
  }) async {
    if (hasThumbnail == null || filenames.isEmpty) return;
    final db = await database;
    final value = hasThumbnail ? 1 : 0;
    await db.transaction((txn) async {
      for (var i = 0; i < filenames.length; i += 100) {
        final chunk = filenames.skip(i).take(100).toList();
        final placeholders = List.filled(chunk.length, '?').join(',');
        await txn.rawUpdate(
          'UPDATE $_tableName SET has_thumbnail = ? WHERE filename IN ($placeholders)',
          [value, ...chunk],
        );
      }
    });
  }

  Future<void> batchUpdateCoverUrl(
      List<String> filenames, String coverUrl) async {
    if (filenames.isEmpty) return;
    final db = await database;
    await db.transaction((txn) async {
      for (var i = 0; i < filenames.length; i += 100) {
        final chunk = filenames.skip(i).take(100).toList();
        final placeholders = List.filled(chunk.length, '?').join(',');
        await txn.rawUpdate(
          'UPDATE $_tableName SET cover_url = ? WHERE filename IN ($placeholders)',
          [coverUrl, ...chunk],
        );
      }
    });
  }

  Future<void> clearThumbnailData() async {
    final db = await database;
    await db.update(_tableName, {'thumb_hash': null, 'has_thumbnail': 0});
  }

  Future<List<Map<String, dynamic>>> getGamesNeedingThumbnails() async {
    final db = await database;
    return db.query(
      _tableName,
      columns: ['filename', 'cover_url'],
      where: 'cover_url IS NOT NULL AND has_thumbnail = 0',
    );
  }

  Future<Set<String>> getAllCoverUrls() async {
    final db = await database;
    final rows = await db.query(
      _tableName,
      columns: ['cover_url'],
      where: 'cover_url IS NOT NULL',
    );
    return rows.map((r) => r['cover_url'] as String).toSet();
  }

  Future<List<Map<String, dynamic>>> getGamesNeedingCovers() async {
    final db = await database;
    return db.query(
      _tableName,
      columns: ['filename', 'systemSlug', 'cover_url'],
      where: 'has_thumbnail = 0',
    );
  }

  /// Games for one system.
  ///
  /// Pass [sourceId] to see just one source's list, or [cacheOwnerId] to see a
  /// group's — they are the same thing for an ungrouped source, which is why
  /// [sourceId] alone still works. Passing nothing returns every row, which is
  /// what the global library and the thumbnail jobs want.
  ///
  /// [endpointId] is accepted so callers can hand over a whole route without
  /// caring, but it does **not** narrow the result: the routes of one source
  /// are the same server, so they share one list.
  ///
  /// Local filesystem entries live under the empty source (`''`); pass
  /// [includeLocal] to fold them in alongside a specific source.
  Future<List<GameItem>> getGames(
    String systemSlug, {
    String? sourceId,
    String? endpointId,
    bool includeLocal = false,
    String? cacheOwnerId,
  }) async {
    final db = await database;
    var where = 'systemSlug = ?';
    final args = <Object?>[systemSlug];
    if (sourceId != null || endpointId != null || cacheOwnerId != null) {
      const ownerClause = 'cache_owner_id = ?';
      args.add(cacheOwnerId ?? sourceId ?? '');
      where += includeLocal
          ? " AND ($ownerClause OR cache_owner_id = '')"
          : ' AND $ownerClause';
    }
    final maps = await db.query(
      _tableName,
      where: where,
      whereArgs: args,
      orderBy: 'displayName ASC',
    );

    return maps.map(_gameFromRow).toList();
  }

  static GameItem _gameFromRow(Map<String, Object?> map) => GameItem(
        filename: map['filename'] as String,
        displayName: map['displayName'] as String,
        url: map['url'] as String,
        cachedCoverUrl: map['cover_url'] as String?,
        providerConfig:
            _decodeProviderConfig(map['provider_config'] as String?),
        hasThumbnail: (map['has_thumbnail'] as int?) == 1,
        isFolder: (map['is_folder'] as int?) == 1,
        alternativeSources:
            _decodeAlternativeSources(map['alternative_sources'] as String?),
      );

  /// Games belonging to the sources behind any of [routes], optionally plus
  /// the local bucket.
  ///
  /// Callers pass the routes their system's providers currently resolve to;
  /// only the source half selects rows. Switching a source to another route
  /// therefore keeps showing the same list instead of forcing a re-sync —
  /// which is the point, since both routes reach the same server. Two routes
  /// of one source collapse to a single term. An empty [routes] with
  /// [includeLocal] gives just local files.
  Future<List<GameItem>> getGamesForRoutes(
    String systemSlug,
    Iterable<({String source, String endpoint})> routes, {
    bool includeLocal = true,
    String Function(String sourceId)? cacheOwnerOf,
  }) async {
    final db = await database;
    // Sources of one group resolve to the same owner and collapse to a single
    // term, the same way two routes of one source already did. Without a
    // resolver every source owns its own list, which is what an ungrouped
    // install looks like.
    final owners = <String>{
      for (final r in routes) cacheOwnerOf?.call(r.source) ?? r.source,
    };
    if (includeLocal) owners.add('');
    if (owners.isEmpty) return const [];

    final placeholders = List.filled(owners.length, '?').join(',');
    final maps = await db.query(
      _tableName,
      where: 'systemSlug = ? AND cache_owner_id IN ($placeholders)',
      whereArgs: [systemSlug, ...owners],
      orderBy: 'displayName ASC',
    );
    return maps.map(_gameFromRow).toList();
  }

  /// Saves [games] splitting them into one batch per source.
  ///
  /// Each [GameItem] already knows where it came from via its
  /// `providerConfig`, so the grouping needs no extra plumbing from callers.
  /// Items with no provider (local filesystem scans) land in the empty source.
  ///
  /// Use this rather than [saveGames] for anything that mixes sources: it is
  /// what stops a sync writing every source's results into one shared bucket,
  /// and it keeps orphan pruning inside the source that produced the list.
  ///
  /// The endpoint each game arrived over is carried through to the row so it
  /// still records the last route used, but it never splits the batch — one
  /// source, one list.
  /// Pass [cacheOwnerOf] (`AppConfig.cacheOwnerIdFor`) so grouped members write
  /// into the group's one list instead of each keeping a copy.
  Future<void> saveGamesByRoute(
    String systemSlug,
    List<GameItem> games, {
    bool deleteOrphans = false,
    bool forceDeleteOrphans = false,
    String Function(String sourceId)? cacheOwnerOf,
  }) async {
    final bySource = <String, List<GameItem>>{};
    final endpointOf = <String, String>{};
    for (final game in games) {
      final source = game.providerConfig?.sourceId ?? '';
      (bySource[source] ??= <GameItem>[]).add(game);
      endpointOf[source] ??= game.providerConfig?.endpointId ?? '';
    }

    // An empty incoming list still has to reach saveGames, otherwise
    // "the server now returns nothing" could never prune anything.
    if (bySource.isEmpty) {
      await saveGames(
        systemSlug,
        const [],
        deleteOrphans: deleteOrphans,
        forceDeleteOrphans: forceDeleteOrphans,
      );
      return;
    }

    // Two sources of one group in a single batch would prune each other's rows
    // as orphans and then put them back — the second list is not the whole
    // library it is being compared against. It should not happen (the home
    // screen resolves a group to one member at a time), so the guard logs
    // rather than hides it, and only the first batch of an owner prunes.
    final prunedOwners = <String>{};
    for (final entry in bySource.entries) {
      final owner = cacheOwnerOf?.call(entry.key) ?? entry.key;
      final firstForOwner = prunedOwners.add(owner);
      if (!firstForOwner) {
        debugPrint(
          'saveGamesByRoute($systemSlug): two sources share cache owner '
          '"$owner" in one batch — skipping orphan pruning for ${entry.key}',
        );
      }
      await saveGames(
        systemSlug,
        entry.value,
        deleteOrphans: deleteOrphans && firstForOwner,
        forceDeleteOrphans: forceDeleteOrphans && firstForOwner,
        sourceId: entry.key,
        endpointId: endpointOf[entry.key] ?? '',
        cacheOwnerId: owner,
      );
    }
  }

  /// How many games each cached library holds, keyed by cache owner id.
  ///
  /// This is the number the source list shows: look it up with
  /// `AppConfig.cacheOwnerIdFor(source.id)`, so every member of a group reports
  /// the group's one list rather than a share of it. The empty bucket (local
  /// filesystem scans) is excluded — it belongs to no source and would
  /// otherwise be attributed to whichever one you opened.
  Future<Map<String, int>> getGameCountsPerCacheOwner() async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT cache_owner_id, COUNT(*) AS c FROM $_tableName '
      "WHERE cache_owner_id != '' GROUP BY cache_owner_id",
    );
    return {
      for (final r in rows)
        r['cache_owner_id'] as String: (r['c'] as int?) ?? 0,
    };
  }

  /// Games in one cached library, whichever source or route fetched them.
  Future<int> getGameCountForOwner(String cacheOwnerId) async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM $_tableName WHERE cache_owner_id = ?',
      [cacheOwnerId],
    );
    return (rows.first['c'] as int?) ?? 0;
  }

  /// Drops one whole cached library, leaving every other one untouched.
  ///
  /// Deleting a *route* must not call this: the source's other routes still
  /// reach the same server and the list they share is still valid. Nor may a
  /// group member leaving — the list belongs to the group, and the leaver's
  /// half of it does not exist as a separate thing ([releaseCacheFrom]). Only
  /// the owner of the library going away justifies dropping it.
  Future<int> deleteCacheOwnedBy(String cacheOwnerId) async {
    if (cacheOwnerId.isEmpty) return 0;
    final db = await database;
    return db.delete(
      _tableName,
      where: 'cache_owner_id = ?',
      whereArgs: [cacheOwnerId],
    );
  }

  static List<AlternativeSource> _decodeAlternativeSources(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) =>
              AlternativeSource.fromJson((e as Map).cast<String, dynamic>()))
          .toList(growable: false);
    } catch (e) {
      debugPrint('_decodeAlternativeSources: $e');
      return const [];
    }
  }

  /// Cleans up cached games when a [Source] is disabled or removed.
  ///
  /// We can't simply DELETE every row tagged with the source: a game may
  /// have been downloaded from that source and now lives on disk as a
  /// local file the user expects to keep seeing in their library. So for
  /// each matching row we check whether the file (or its extracted
  /// folder) exists in the system's [systemTargetFolders] and:
  ///   - **installed** rows have their `provider_config` and `url` nulled
  ///     out (the row stays so the library/grid keeps the entry; install
  ///     detection works off the filesystem so it keeps working);
  ///   - **non-installed** rows are removed entirely.
  ///
  /// The sourceId is validated against `[A-Za-z0-9_-]+` before it hits
  /// the LIKE pattern so it can't be hijacked into a wildcard.
  ///
  /// [protectedOwnerIds] names cached libraries the user still has — the groups
  /// this source was a member of. Rows it fetched on the group's behalf are the
  /// group's rows, and a member walking out must not take them along; without
  /// this the remaining members would face a re-sync they never asked for.
  /// Pass the ids **before** the source is dropped from the group.
  ///
  /// Returns `(detached, deleted)` row counts for logging.
  Future<({int detached, int deleted})> purgeOrDetachSource(
    String sourceId, {
    required Map<String, String> systemTargetFolders,
    Set<String> protectedOwnerIds = const {},
  }) async {
    if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(sourceId)) {
      debugPrint('purgeOrDetachSource: refusing unsafe id "$sourceId"');
      return (detached: 0, deleted: 0);
    }
    final db = await database;
    final pattern = '%"source_id":"$sourceId"%';
    var where = 'provider_config LIKE ?';
    final whereArgs = <Object?>[pattern];
    if (protectedOwnerIds.isNotEmpty) {
      final placeholders =
          List.filled(protectedOwnerIds.length, '?').join(',');
      where += ' AND cache_owner_id NOT IN ($placeholders)';
      whereArgs.addAll(protectedOwnerIds);
    }
    final rows = await db.query(
      _tableName,
      columns: ['systemSlug', 'filename'],
      where: where,
      whereArgs: whereArgs,
    );

    final installedFilenames = <(String, String)>[];
    final orphanFilenames = <(String, String)>[];
    for (final row in rows) {
      final slug = row['systemSlug'] as String;
      final filename = row['filename'] as String;
      final folder = systemTargetFolders[slug];
      if (folder != null && _isFilenameOnDisk(folder, filename)) {
        installedFilenames.add((slug, filename));
      } else {
        orphanFilenames.add((slug, filename));
      }
    }

    int detached = 0;
    int deleted = 0;
    await db.transaction((txn) async {
      // Both statements repeat the selection predicate rather than matching on
      // (system, filename) alone: that pair is not unique across cached
      // libraries, so the bare version reached into every other source's rows
      // for the same game — and, once groups exist, into the group's.
      for (final (slug, filename) in installedFilenames) {
        detached += await txn.rawUpdate(
          'UPDATE $_tableName SET provider_config = NULL, url = NULL '
          'WHERE systemSlug = ? AND filename = ? AND $where',
          [slug, filename, ...whereArgs],
        );
      }
      for (final (slug, filename) in orphanFilenames) {
        deleted += await txn.delete(
          _tableName,
          where: 'systemSlug = ? AND filename = ? AND $where',
          whereArgs: [slug, filename, ...whereArgs],
        );
      }
    });
    debugPrint(
      'purgeOrDetachSource($sourceId): detached=$detached deleted=$deleted',
    );
    return (detached: detached, deleted: deleted);
  }

  /// Returns true when [filename] (or its extracted folder counterpart)
  /// exists in [folder]. Mirrors the install-detection used by the UI:
  /// archive files like `.zip`/`.7z` are also considered installed when
  /// their extracted folder is present.
  static bool _isFilenameOnDisk(String folder, String filename) {
    try {
      final direct = File('$folder/$filename');
      if (direct.existsSync()) return true;
      final lower = filename.toLowerCase();
      const archives = ['.zip', '.7z', '.rar'];
      for (final ext in archives) {
        if (lower.endsWith(ext)) {
          final stripped = filename.substring(0, filename.length - ext.length);
          if (Directory('$folder/$stripped').existsSync()) return true;
          if (File('$folder/$stripped').existsSync()) return true;
        }
      }
    } catch (e) {
      debugPrint('_isFilenameOnDisk: $folder/$filename: $e');
    }
    return false;
  }

  Future<void> deleteGame(String systemSlug, String filename) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(
        _tableName,
        where: 'systemSlug = ? AND filename = ?',
        whereArgs: [systemSlug, filename],
      );
      // Cascade: remove orphaned metadata and RA matches
      await txn.delete(
        'game_metadata',
        where: 'system_slug = ? AND filename = ?',
        whereArgs: [systemSlug, filename],
      );
      await txn.delete(
        'ra_matches',
        where: 'system_slug = ? AND game_filename = ?',
        whereArgs: [systemSlug, filename],
      );
    });
  }

  static String _escapeLike(String input) =>
      input.replaceAll('\\', '\\\\').replaceAll('%', '\\%').replaceAll('_', '\\_');

  Future<List<Map<String, dynamic>>> getAllGames({
    String? orderBy,
    String? searchQuery,
    List<String>? systemSlugs,
  }) async {
    final db = await database;
    String? where;
    List<dynamic>? whereArgs;

    final conditions = <String>[];
    final args = <dynamic>[];

    if (searchQuery != null && searchQuery.isNotEmpty) {
      final escaped = _escapeLike(searchQuery);
      conditions.add("displayName LIKE ? ESCAPE '\\'");
      args.add('%$escaped%');
    }
    if (systemSlugs != null && systemSlugs.isNotEmpty) {
      final placeholders = List.filled(systemSlugs.length, '?').join(', ');
      conditions.add('systemSlug IN ($placeholders)');
      args.addAll(systemSlugs);
    }

    if (conditions.isNotEmpty) {
      where = conditions.join(' AND ');
      whereArgs = args;
    }

    return db.query(
      _tableName,
      where: where,
      whereArgs: whereArgs,
      orderBy: orderBy ?? 'displayName ASC',
    );
  }

  Future<bool> hasCache(String systemSlug) async {
    final db = await database;
    final result = await db.query(
      _tableName,
      where: 'systemSlug = ?',
      whereArgs: [systemSlug],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  /// Returns the set of system slugs (from [slugs]) that have at least one
  /// cached game. Single query instead of N individual hasCache() calls.
  Future<Set<String>> systemsWithCache(List<String> slugs) async {
    if (slugs.isEmpty) return {};
    final db = await database;
    final placeholders = List.filled(slugs.length, '?').join(',');
    final result = await db.rawQuery(
      'SELECT DISTINCT systemSlug FROM $_tableName WHERE systemSlug IN ($placeholders)',
      slugs,
    );
    return result.map((r) => r['systemSlug'] as String).toSet();
  }

  Future<void> clearCache() async {
    final db = await database;
    await db.delete(_tableName);
  }

  static ProviderConfig? _decodeProviderConfig(String? json) {
    if (json == null) return null;
    try {
      return ProviderConfig.fromJson(
          jsonDecode(json) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('Failed to decode provider config: $e');
      return null;
    }
  }

  static final _regionPattern = RegExp(
    r'\((USA|U|Europe|E|Japan|J|Germany|France|Spain|Italy|World)\)',
  );

  static const _regionMap = {
    'USA': 'USA', 'U': 'USA',
    'Europe': 'Europe', 'E': 'Europe',
    'Japan': 'Japan', 'J': 'Japan',
    'Germany': 'Germany',
    'France': 'France',
    'Spain': 'Spain',
    'Italy': 'Italy',
    'World': 'World',
  };

  String _extractRegion(String filename) {
    final match = _regionPattern.firstMatch(filename);
    if (match == null) return 'Unknown';
    return _regionMap[match.group(1)] ?? 'Unknown';
  }

  // ---------------------------------------------------------------------------
  // Game metadata (RomM / IGDB)
  // ---------------------------------------------------------------------------

  Future<void> saveGameMetadata(
      String systemSlug, List<GameMetadataInfo> metadata) async {
    if (metadata.isEmpty) return;
    final db = await database;
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final m in metadata) {
        batch.insert('game_metadata', m.toDbRow(),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    });
  }

  Future<GameMetadataInfo?> getGameMetadata(
      String filename, String systemSlug) async {
    final db = await database;
    final rows = await db.query(
      'game_metadata',
      where: 'filename = ? AND system_slug = ?',
      whereArgs: [filename, systemSlug],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return GameMetadataInfo.fromDbRow(rows.first);
  }

  Future<Map<String, GameMetadataInfo>> getMetadataForSystem(
      String systemSlug) async {
    final db = await database;
    final rows = await db.query(
      'game_metadata',
      where: 'system_slug = ?',
      whereArgs: [systemSlug],
    );
    return {
      for (final row in rows)
        row['filename'] as String: GameMetadataInfo.fromDbRow(row),
    };
  }

  // ---------------------------------------------------------------------------
  // RetroAchievements cache
  // ---------------------------------------------------------------------------

  Future<void> saveRaGames(int consoleId, List<RaGame> games) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.transaction((txn) async {
      // Clear existing games for this console
      await txn.delete('ra_games',
          where: 'console_id = ?', whereArgs: [consoleId]);
      // Also clear hashes for games of this console (cascading cleanup)
      await txn.rawDelete('''
        DELETE FROM ra_hashes WHERE ra_game_id NOT IN (
          SELECT ra_game_id FROM ra_games
        )
      ''');

      final batch = txn.batch();
      for (final game in games) {
        batch.insert(
          'ra_games',
          {
            'ra_game_id': game.raGameId,
            'console_id': consoleId,
            'title': game.title,
            'num_achievements': game.numAchievements,
            'points': game.points,
            'image_icon': game.imageIcon,
            'normalized_title': RaNameMatcher.normalize(game.title),
            'last_updated': now,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        // Also save inline hashes from GetGameList
        for (final hash in game.hashes) {
          batch.insert(
            'ra_hashes',
            {
              'hash': hash,
              'ra_game_id': game.raGameId,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
      await batch.commit(noResult: true);
    });
  }

  Future<List<RaGame>> getRaGames(int consoleId) async {
    final db = await database;
    final rows = await db.query(
      'ra_games',
      where: 'console_id = ?',
      whereArgs: [consoleId],
    );
    return rows
        .map((row) => RaGame(
              raGameId: row['ra_game_id'] as int,
              title: row['title'] as String,
              consoleId: row['console_id'] as int,
              numAchievements: row['num_achievements'] as int? ?? 0,
              points: row['points'] as int? ?? 0,
              imageIcon: row['image_icon'] as String?,
            ))
        .toList();
  }

  Future<RaGame?> getRaGame(int raGameId) async {
    final db = await database;
    final rows = await db.query(
      'ra_games',
      where: 'ra_game_id = ?',
      whereArgs: [raGameId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    return RaGame(
      raGameId: row['ra_game_id'] as int,
      title: row['title'] as String,
      consoleId: row['console_id'] as int,
      numAchievements: row['num_achievements'] as int? ?? 0,
      points: row['points'] as int? ?? 0,
      imageIcon: row['image_icon'] as String?,
    );
  }

  Future<void> saveRaHashes(
      int raGameId, List<RaHashEntry> hashes) async {
    final db = await database;
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final entry in hashes) {
        if (entry.md5.isEmpty) continue;
        batch.insert(
          'ra_hashes',
          {
            'hash': entry.md5,
            'ra_game_id': raGameId,
            'rom_name': entry.name,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  /// Look up a game ID by ROM hash.
  Future<int?> lookupRaGameByHash(String hash) async {
    final db = await database;
    final rows = await db.query(
      'ra_hashes',
      columns: ['ra_game_id'],
      where: 'hash = ?',
      whereArgs: [hash],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['ra_game_id'] as int;
  }

  /// Get ROM filenames from the hash table, grouped by game ID.
  Future<Map<int, List<String>>> getRaRomNames(int consoleId) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT h.ra_game_id, h.rom_name
      FROM ra_hashes h
      INNER JOIN ra_games g ON h.ra_game_id = g.ra_game_id
      WHERE g.console_id = ? AND h.rom_name IS NOT NULL
    ''', [consoleId]);

    final map = <int, List<String>>{};
    for (final row in rows) {
      final gameId = row['ra_game_id'] as int;
      final name = row['rom_name'] as String;
      (map[gameId] ??= []).add(name);
    }
    return map;
  }

  Future<void> saveRaMatch(
    String filename,
    String systemSlug,
    RaMatchResult match,
  ) async {
    final db = await database;
    // MAX preserves existing is_mastered=1 so sync never accidentally un-masters
    await db.rawInsert('''
      INSERT INTO ra_matches (game_filename, system_slug, ra_game_id, match_type, is_mastered, last_updated)
      VALUES (?, ?, ?, ?, ?, ?)
      ON CONFLICT(game_filename, system_slug) DO UPDATE SET
        ra_game_id = excluded.ra_game_id,
        match_type = excluded.match_type,
        is_mastered = MAX(ra_matches.is_mastered, excluded.is_mastered),
        last_updated = excluded.last_updated
    ''', [
      filename,
      systemSlug,
      match.raGameId,
      match.type.name,
      match.isMastered ? 1 : 0,
      DateTime.now().millisecondsSinceEpoch,
    ]);
  }

  /// Explicitly set the mastered flag for a game match.
  /// Unlike [saveRaMatch], this can both master and un-master.
  Future<void> updateRaMastered(
    String filename,
    String systemSlug,
    bool isMastered,
  ) async {
    final db = await database;
    await db.update(
      'ra_matches',
      {
        'is_mastered': isMastered ? 1 : 0,
        'last_updated': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'game_filename = ? AND system_slug = ?',
      whereArgs: [filename, systemSlug],
    );
  }

  Future<Map<String, RaMatchResult>> getRaMatchesForSystem(
      String systemSlug) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT m.game_filename, m.match_type, m.ra_game_id, m.is_mastered,
             g.title, g.num_achievements, g.points, g.image_icon
      FROM ra_matches m
      LEFT JOIN ra_games g ON m.ra_game_id = g.ra_game_id
      WHERE m.system_slug = ?
    ''', [systemSlug]);

    final map = <String, RaMatchResult>{};
    for (final row in rows) {
      final filename = row['game_filename'] as String;
      final typeName = row['match_type'] as String;
      map[filename] = RaMatchResult(
        type: RaMatchType.values.firstWhere(
          (e) => e.name == typeName,
          orElse: () => RaMatchType.none,
        ),
        raGameId: row['ra_game_id'] as int?,
        raTitle: row['title'] as String?,
        achievementCount: row['num_achievements'] as int?,
        points: row['points'] as int?,
        imageIcon: row['image_icon'] as String?,
        isMastered: (row['is_mastered'] as int?) == 1,
      );
    }
    return map;
  }

  /// Look up the RA image icon path for a single game.
  /// Returns the raw path (e.g. "/Images/090065.png") or null.
  Future<String?> getRaImageIconForGame(
    String filename,
    String systemSlug,
  ) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT g.image_icon
      FROM ra_matches m
      INNER JOIN ra_games g ON m.ra_game_id = g.ra_game_id
      WHERE m.game_filename = ? AND m.system_slug = ?
        AND m.match_type != 'none'
        AND g.image_icon IS NOT NULL AND g.image_icon != ''
      LIMIT 1
    ''', [filename, systemSlug]);
    if (rows.isEmpty) return null;
    return rows.first['image_icon'] as String?;
  }

  Future<bool> hasRaCache(int consoleId) async {
    final db = await database;
    final result = await db.query(
      'ra_games',
      where: 'console_id = ?',
      whereArgs: [consoleId],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  Future<void> clearRaCache() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('ra_matches');
      await txn.delete('ra_hashes');
      await txn.delete('ra_games');
    });
  }
}
