import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

/// Hash methods supported per system for RetroAchievements.
enum RaHashMethod {
  simpleMd5,
  nesStrip,
  snesStrip,
  lynxStrip,
  atari7800Strip,
  ndsHash,
}

class RaHashService {
  /// Returns the hash method for a system, or null if not supported.
  static RaHashMethod? getHashMethod(String systemId) {
    return switch (systemId) {
      'gb' ||
      'gbc' ||
      'gba' ||
      'megadrive' ||
      'mastersystem' ||
      'gamegear' ||
      'sega32x' ||
      'atari2600' =>
        RaHashMethod.simpleMd5,
      'nes' => RaHashMethod.nesStrip,
      'snes' => RaHashMethod.snesStrip,
      'lynx' => RaHashMethod.lynxStrip,
      'atari7800' => RaHashMethod.atari7800Strip,
      'nds' => RaHashMethod.ndsHash,
      _ => null,
    };
  }

  /// Computes the RA-compatible hash for a ROM file.
  /// Returns null if the system is not supported or the file doesn't exist.
  /// Runs in an isolate to avoid blocking the UI.
  static Future<String?> computeHash(String filePath, String systemId) async {
    final method = getHashMethod(systemId);
    if (method == null) return null;

    return compute(_computeHashIsolate, _HashRequest(filePath, method));
  }

  static String? _computeHashIsolate(_HashRequest request) {
    // NDS uses random-access reads (ROMs can be 512MB+)
    if (request.method == RaHashMethod.ndsHash) {
      return _computeNdsHash(request.filePath);
    }

    final file = File(request.filePath);
    if (!file.existsSync()) return null;

    final bytes = file.readAsBytesSync();
    if (bytes.isEmpty) return null;

    final hashInput = _prepareBytes(bytes, request.method);
    return md5.convert(hashInput).toString();
  }

  /// NDS hash per rcheevos algorithm: MD5 of header + ARM9 + ARM7 + icon.
  /// Uses RandomAccessFile to avoid loading the entire ROM into memory.
  static String? _computeNdsHash(String filePath) {
    final file = File(filePath);
    if (!file.existsSync()) return null;

    final raf = file.openSync();
    try {
      final fileLength = raf.lengthSync();
      if (fileLength < 0x160) return null;

      // Check for SuperCard header (512 bytes prepended)
      int baseOffset = 0;
      if (fileLength >= 0x200) {
        final probe = Uint8List(0xB4);
        raf.readIntoSync(probe);
        if (probe[0x00] == 0x2E &&
            probe[0x01] == 0x00 &&
            probe[0x02] == 0x00 &&
            probe[0x03] == 0xEA &&
            probe[0xB0] == 0x44 &&
            probe[0xB1] == 0x46 &&
            probe[0xB2] == 0x96 &&
            probe[0xB3] == 0x00) {
          baseOffset = 0x200;
        }
      }

      if (fileLength < baseOffset + 0x160) return null;

      // Read NDS header (0x160 bytes)
      raf.setPositionSync(baseOffset);
      final header = Uint8List(0x160);
      raf.readIntoSync(header);

      // Parse offsets from header (little-endian uint32)
      final arm9Offset = _readUint32LE(header, 0x20) + baseOffset;
      final arm9Size = _readUint32LE(header, 0x2C);
      final arm7Offset = _readUint32LE(header, 0x30) + baseOffset;
      final arm7Size = _readUint32LE(header, 0x3C);
      final iconOffset = _readUint32LE(header, 0x68) + baseOffset;

      // Sanity check: combined ARM code must not exceed 16MB
      if (arm9Size + arm7Size > 16 * 1024 * 1024) return null;

      // Read ARM9 binary
      final arm9 = Uint8List(arm9Size);
      if (arm9Size > 0 && arm9Offset + arm9Size <= fileLength) {
        raf.setPositionSync(arm9Offset);
        raf.readIntoSync(arm9);
      }

      // Read ARM7 binary
      final arm7 = Uint8List(arm7Size);
      if (arm7Size > 0 && arm7Offset + arm7Size <= fileLength) {
        raf.setPositionSync(arm7Offset);
        raf.readIntoSync(arm7);
      }

      // Read icon/title data (0xA00 bytes, pad with zeros if file too short)
      const iconSize = 0xA00;
      final icon = Uint8List(iconSize);
      if (iconOffset < fileLength) {
        raf.setPositionSync(iconOffset);
        final readable = min(fileLength - iconOffset, iconSize);
        if (readable > 0) {
          raf.readIntoSync(icon, 0, readable);
        }
      }

      // MD5 of: header + ARM9 + ARM7 + icon
      final buffer = BytesBuilder(copy: false);
      buffer.add(header);
      buffer.add(arm9);
      buffer.add(arm7);
      buffer.add(icon);
      return md5.convert(buffer.takeBytes()).toString();
    } catch (e) {
      debugPrint('RaHashService: NDS hash failed for $filePath: $e');
      return null;
    } finally {
      raf.closeSync();
    }
  }

  /// Reads a little-endian uint32 from [bytes] at [offset].
  static int _readUint32LE(Uint8List bytes, int offset) {
    return bytes[offset] |
        (bytes[offset + 1] << 8) |
        (bytes[offset + 2] << 16) |
        (bytes[offset + 3] << 24);
  }

  static Uint8List _prepareBytes(Uint8List bytes, RaHashMethod method) {
    switch (method) {
      case RaHashMethod.simpleMd5:
        return bytes;

      case RaHashMethod.nesStrip:
        // Strip 16-byte iNES header if present (magic: NES\x1a)
        if (bytes.length > 16 &&
            bytes[0] == 0x4E &&
            bytes[1] == 0x45 &&
            bytes[2] == 0x53 &&
            bytes[3] == 0x1A) {
          return Uint8List.sublistView(bytes, 16);
        }
        return bytes;

      case RaHashMethod.snesStrip:
        // Strip 512-byte copier header if file size mod 1024 == 512
        if (bytes.length > 512 && bytes.length % 1024 == 512) {
          return Uint8List.sublistView(bytes, 512);
        }
        return bytes;

      case RaHashMethod.lynxStrip:
        // Strip 64-byte Lynx header if present (magic: LYNX\x00)
        if (bytes.length > 64 &&
            bytes[0] == 0x4C &&
            bytes[1] == 0x59 &&
            bytes[2] == 0x4E &&
            bytes[3] == 0x58 &&
            bytes[4] == 0x00) {
          return Uint8List.sublistView(bytes, 64);
        }
        return bytes;

      case RaHashMethod.atari7800Strip:
        // Strip 128-byte A78 header if present (magic: \x01ATARI7800)
        if (bytes.length > 128 &&
            bytes[0] == 0x01 &&
            bytes[1] == 0x41 && // A
            bytes[2] == 0x54 && // T
            bytes[3] == 0x41 && // A
            bytes[4] == 0x52 && // R
            bytes[5] == 0x49 && // I
            bytes[6] == 0x37 && // 7
            bytes[7] == 0x38 && // 8
            bytes[8] == 0x30 && // 0
            bytes[9] == 0x30) {
          // 0
          return Uint8List.sublistView(bytes, 128);
        }
        return bytes;

      case RaHashMethod.ndsHash:
        // Handled separately via _computeNdsHash (random-access)
        return bytes;
    }
  }
}

class _HashRequest {
  final String filePath;
  final RaHashMethod method;
  const _HashRequest(this.filePath, this.method);
}
