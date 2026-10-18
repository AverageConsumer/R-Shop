import 'package:flutter_test/flutter_test.dart';
import 'package:retro_eshop/models/system_model.dart';

void main() {
  group('Xbox systems', () {
    test('original Xbox is in the catalog', () {
      final xbox =
          SystemModel.supportedSystems.firstWhere((s) => s.id == 'xbox');
      expect(xbox.name, 'Xbox');
      expect(xbox.manufacturer, 'Microsoft');
      expect(xbox.isZipped, isFalse);
      expect(xbox.libretroId, 'Microsoft_-_Xbox');
      expect(xbox.romExtensions, containsAll(['.iso', '.xiso', '.xbe']));
      expect(xbox.iconName, 'xbox_original.svg');
    });

    test('Xbox 360 is in the catalog', () {
      final xbox360 =
          SystemModel.supportedSystems.firstWhere((s) => s.id == 'xbox360');
      expect(xbox360.name, 'Xbox 360');
      expect(xbox360.manufacturer, 'Microsoft');
      expect(xbox360.isZipped, isFalse);
      expect(xbox360.libretroId, 'Microsoft_-_Xbox_360');
      expect(xbox360.romExtensions,
          containsAll(['.iso', '.xex', '.god', '.zar', '.xbla']));
      expect(xbox360.iconName, 'xbox_360.svg');
    });

    test('Xbox ids are unique', () {
      final ids = SystemModel.supportedSystems.map((s) => s.id).toList();
      expect(ids.toSet().length, ids.length);
      expect(ids, containsAll(['xbox', 'xbox360']));
      expect(ids.length, 69);
    });
  });

  test('Neo Geo MVS can be configured separately from generic Arcade', () {
    final mvs =
        SystemModel.supportedSystems.firstWhere((s) => s.id == 'neogeomvs');
    expect(mvs.name, 'Neo Geo MVS');
    expect(mvs.romExtensions, contains('.zip'));
    expect(mvs.id, isNot('arcade'));
  });
}
