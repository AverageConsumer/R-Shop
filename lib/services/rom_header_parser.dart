import 'dart:io';
import 'dart:convert';

import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../models/system_model.dart';

/// Utility to read internal game names directly from standard ROM header offsets.
/// This acts as a "magic" approach to rapidly identify games without full-file hashing.
class RomHeaderParser {
  /// Maps System IDs to their expected internal title offsets and lengths.
  /// Note: Offsets are generally for unheadered ROMs.
  static final Map<String, ({int offset, int length})> _systemOffsets = {
    'gb': (offset: 0x0134, length: 15),
    'gbc': (offset: 0x0134, length: 15),
    'gba': (offset: 0x00A0, length: 12),
    'nds': (offset: 0x0000, length: 12),
    // SNES has multiple common header locations for internal names
    'snes': (offset: 0x7FC0, length: 21), // LoROM mostly
  };

  /// Attempts to parse the internal title from a local ROM file based on its system.
  /// 
  /// Supports raw ROM files and `.zip` archives.
  /// Returns the parsed title, or `null` if the system is not supported, the file
  /// is too small, or parsing fails.
  static Future<String?> parseInternalTitle(File file, SystemModel system) async {
    final spec = _systemOffsets[system.id];
    if (spec == null) return null;

    final ext = p.extension(file.path).toLowerCase();
    if (ext == '.zip') {
      return _parseZipHeader(file, system, spec);
    }

    RandomAccessFile? raf;
    try {
      raf = await file.open(mode: FileMode.read);
      final length = await raf.length();
      
      // Ensure file is large enough to contain the header at the expected offset
      if (length < spec.offset + spec.length) {
        return null;
      }

      // SNES requires special handling because LoROM and HiROM have different offsets
      if (system.id == 'snes') {
        final loromTitle = await _readString(raf, 0x7FC0, 21);
        // Basic heuristic: check if it's mostly printable ASCII
        if (_isPrintable(loromTitle)) {
           return loromTitle;
        }
        
        // Try HiROM
        if (length >= 0xFFC0 + 21) {
           final hiromTitle = await _readString(raf, 0xFFC0, 21);
           if (_isPrintable(hiromTitle)) {
             return hiromTitle;
           }
        }
        return null; // Failed to find a valid SNES title
      }

      // Standard offset reading
      final title = await _readString(raf, spec.offset, spec.length);
      return _isPrintable(title) ? title : null;
      
    } catch (e) {
      debugPrint('Error parsing ROM header for ${file.path}: $e');
      return null;
    } finally {
      await raf?.close();
    }
  }

  static Future<String> _readString(RandomAccessFile raf, int offset, int length) async {
    await raf.setPosition(offset);
    final Uint8List buffer = await raf.read(length);
    
    // Stop at the first null byte (0x00) or non-printable garbage that might terminate a string early
    int actualLength = 0;
    for (int i = 0; i < buffer.length; i++) {
      if (buffer[i] == 0) break;
      actualLength++;
    }
    
    // Attempt ASCII decoding, replace unmappable chars just in case
    return ascii.decode(buffer.sublist(0, actualLength), allowInvalid: true).trim();
  }
  
  static Future<String?> _parseZipHeader(File file, SystemModel system, ({int offset, int length}) spec) async {
    try {
      final inputStream = InputFileStream(file.path);
      final archive = ZipDecoder().decodeBuffer(inputStream);
      final romExts = system.romExtensions.map((e) => e.toLowerCase()).toList();

      ArchiveFile? targetEntry;
      for (final f in archive.files) {
         if (f.isFile) {
           final fExt = p.extension(f.name).toLowerCase();
           if (romExts.contains(fExt)) {
             targetEntry = f;
             break;
           }
         }
      }

      if (targetEntry == null) return null;

      // Extract the target file's bytes into memory.
      // This is blazing fast for small 8/16-bit retro consoles (< 32MB).
      final content = targetEntry.content as List<int>;
      if (content.length < spec.offset + spec.length) return null;

      if (system.id == 'snes') {
        final loromTitle = _readStringFromBuffer(content, 0x7FC0, 21);
        if (_isPrintable(loromTitle)) return loromTitle;
        if (content.length >= 0xFFC0 + 21) {
          final hiromTitle = _readStringFromBuffer(content, 0xFFC0, 21);
          if (_isPrintable(hiromTitle)) return hiromTitle;
        }
        return null; // Failed to find a valid SNES title
      }

      final title = _readStringFromBuffer(content, spec.offset, spec.length);
      return _isPrintable(title) ? title : null;
    } catch (e) {
      debugPrint('Error parsing ZIP header for ${file.path}: $e');
      return null;
    }
  }

  static String _readStringFromBuffer(List<int> buffer, int offset, int length) {
    if (offset >= buffer.length) return '';
    int actualLength = 0;
    for (int i = 0; i < length; i++) {
      if (offset + i >= buffer.length) break;
      if (buffer[offset + i] == 0) break;
      actualLength++;
    }
    return ascii.decode(buffer.sublist(offset, offset + actualLength), allowInvalid: true).trim();
  }

  static final _printableRegex = RegExp(r'^[\x20-\x7E]+$');

  static bool _isPrintable(String str) {
     if (str.isEmpty) return false;
     return _printableRegex.hasMatch(str);
  }
}
