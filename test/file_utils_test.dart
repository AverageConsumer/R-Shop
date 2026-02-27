import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:retro_eshop/utils/file_utils.dart';

void main() {
  group('moveFile', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('moveFile_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('moves file via rename on same filesystem', () async {
      final source = File('${tempDir.path}/source.bin');
      await source.writeAsBytes([1, 2, 3, 4]);
      final targetPath = '${tempDir.path}/target.bin';

      await moveFile(source, targetPath);

      expect(await File(targetPath).exists(), isTrue);
      expect(await File(targetPath).readAsBytes(), [1, 2, 3, 4]);
      expect(await source.exists(), isFalse);
    });

    test('overwrites existing target file', () async {
      final source = File('${tempDir.path}/source.bin');
      await source.writeAsBytes([5, 6, 7]);
      final target = File('${tempDir.path}/target.bin');
      await target.writeAsBytes([0, 0]);

      await moveFile(source, target.path);

      expect(await target.readAsBytes(), [5, 6, 7]);
      expect(await source.exists(), isFalse);
    });

    test('creates target in nested directory', () async {
      final source = File('${tempDir.path}/source.bin');
      await source.writeAsBytes([10, 20]);
      final targetPath = '${tempDir.path}/sub/dir/target.bin';
      await Directory('${tempDir.path}/sub/dir').create(recursive: true);

      await moveFile(source, targetPath);

      expect(await File(targetPath).exists(), isTrue);
      expect(await File(targetPath).readAsBytes(), [10, 20]);
    });

    test('no staging file remains after successful move', () async {
      final source = File('${tempDir.path}/source.rom');
      await source.writeAsBytes(List.filled(1024, 0xAB));
      final targetPath = '${tempDir.path}/target.rom';

      await moveFile(source, targetPath);

      // Staging file must not linger
      final stagingFile = File('$targetPath$stagingSuffix');
      expect(await stagingFile.exists(), isFalse);
      // Target is complete
      expect(await File(targetPath).readAsBytes(), List.filled(1024, 0xAB));
    });

    test('cleans up leftover staging file from previous crash', () async {
      final targetPath = '${tempDir.path}/game.rom';
      // Simulate a leftover staging file from a crashed move
      final leftoverStaging = File('$targetPath$stagingSuffix');
      await leftoverStaging.writeAsBytes([0xFF, 0xFF]);

      final source = File('${tempDir.path}/source.rom');
      await source.writeAsBytes([1, 2, 3]);

      await moveFile(source, targetPath);

      // Leftover staging is gone, target has correct content
      expect(await leftoverStaging.exists(), isFalse);
      expect(await File(targetPath).readAsBytes(), [1, 2, 3]);
      expect(await source.exists(), isFalse);
    });
  });

  group('stagingSuffix', () {
    test('has expected value', () {
      expect(stagingSuffix, '.rshop_staging');
    });
  });
}
