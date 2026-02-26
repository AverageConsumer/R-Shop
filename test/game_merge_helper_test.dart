import 'package:flutter_test/flutter_test.dart';
import 'package:retro_eshop/models/game_item.dart';
import 'package:retro_eshop/models/system_model.dart';
import 'package:retro_eshop/utils/game_merge_helper.dart';

final _nes = SystemModel.supportedSystems.firstWhere((s) => s.id == 'nes');
final _psx = SystemModel.supportedSystems.firstWhere((s) => s.id == 'psx');

GameItem _game(String filename, {String url = '', String? displayName}) {
  return GameItem(
    filename: filename,
    displayName: displayName ?? GameItem.cleanDisplayName(filename),
    url: url,
  );
}

void main() {
  group('Basic merge', () {
    test('remote only returns remote games sorted', () {
      final remote = [
        _game('Zelda (USA).zip', url: 'http://r/zelda.zip'),
        _game('Mario (USA).zip', url: 'http://r/mario.zip'),
      ];
      final result = GameMergeHelper.merge(remote, [], _nes);
      expect(result.length, 2);
      expect(result.first.displayName.toLowerCase().compareTo(
          result.last.displayName.toLowerCase()), lessThan(0));
      expect(result.every((g) => g.url.isNotEmpty), true);
    });

    test('local only returns local games sorted', () {
      final local = [
        _game('Zelda.nes'),
        _game('Mario.nes'),
      ];
      final result = GameMergeHelper.merge([], local, _nes);
      expect(result.length, 2);
      expect(result.first.displayName.toLowerCase().compareTo(
          result.last.displayName.toLowerCase()), lessThan(0));
    });

    test('mixed returns remote + non-colliding locals', () {
      final remote = [_game('Mario (USA).zip', url: 'http://r/mario.zip')];
      final local = [_game('Contra.nes')];
      final result = GameMergeHelper.merge(remote, local, _nes);
      expect(result.length, 2);
      expect(result.map((g) => g.filename).toSet(),
          {'Mario (USA).zip', 'Contra.nes'});
    });
  });

  group('Collision handling', () {
    test('same filename: remote wins', () {
      final remote = [_game('Mario.zip', url: 'http://r/mario.zip')];
      final local = [_game('Mario.zip')];
      final result = GameMergeHelper.merge(remote, local, _nes);
      expect(result.length, 1);
      expect(result.first.url, 'http://r/mario.zip');
    });

    test('archive target match: remote .zip shadows local .nes', () {
      // NES: .zip → stripped + .nes → "Game (USA).nes"
      final remote = [_game('Game (USA).zip', url: 'http://r/game.zip')];
      final local = [_game('Game (USA).nes')];
      final result = GameMergeHelper.merge(remote, local, _nes);
      expect(result.length, 1);
      expect(result.first.filename, 'Game (USA).zip');
    });

    test('multi-file archive: remote .zip shadows local folder', () {
      // PSX has multiFileExtensions ['.bin', '.cue']
      // extractGameName("Game.zip") → "Game" (folder name)
      final remote = [_game('Game.zip', url: 'http://r/game.zip')];
      final local = [_game('Game')];
      final result = GameMergeHelper.merge(remote, local, _psx);
      expect(result.length, 1);
      expect(result.first.filename, 'Game.zip');
    });

    test('no collision: both kept', () {
      final remote = [_game('Mario.zip', url: 'http://r/mario.zip')];
      final local = [_game('Zelda.nes')];
      final result = GameMergeHelper.merge(remote, local, _nes);
      expect(result.length, 2);
    });
  });

  group('Sorting', () {
    test('result sorted alphabetically by displayName', () {
      final remote = [
        _game('Zelda.zip', url: 'http://r/z.zip'),
        _game('Mario.zip', url: 'http://r/m.zip'),
        _game('Contra.zip', url: 'http://r/c.zip'),
      ];
      final result = GameMergeHelper.merge(remote, [], _nes);
      final names = result.map((g) => g.displayName.toLowerCase()).toList();
      expect(names, List.from(names)..sort());
    });

    test('case-insensitive sorting', () {
      final remote = [
        _game('zelda.zip', url: 'http://r/z.zip'),
        _game('Mario.zip', url: 'http://r/m.zip'),
      ];
      final result = GameMergeHelper.merge(remote, [], _nes);
      expect(result.first.filename, 'Mario.zip');
    });
  });

  group('Edge cases', () {
    test('both lists empty returns empty', () {
      final result = GameMergeHelper.merge([], [], _nes);
      expect(result, isEmpty);
    });

    test('remote game without URL: local enrichment kept', () {
      final remote = [_game('Game.zip', url: '')];
      final local = [_game('Other.nes')];
      final result = GameMergeHelper.merge(remote, local, _nes);
      expect(result.length, 2);
    });

    test('system without multiFileExtensions: no folder match', () {
      // NES has no multiFileExtensions
      final remote = [_game('Game.zip', url: 'http://r/game.zip')];
      final local = [_game('Game')];
      final result = GameMergeHelper.merge(remote, local, _nes);
      // "Game" (folder) is NOT in remoteTargetNames because NES has no multiFileExtensions
      expect(result.length, 2);
    });
  });
}
