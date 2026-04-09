import 'package:flutter/material.dart';

import '../../models/config/source.dart';

/// Maps a [Source] to the dot color used in game card overlays.
/// Borrowed sources always render light blue regardless of type.
Color sourceDotColorFor(Source source) {
  if (source.borrowed) return Colors.lightBlueAccent;
  switch (source.type) {
    case SourceType.romm:
      return Colors.greenAccent;
    case SourceType.smb:
      return Colors.amberAccent;
    case SourceType.ftp:
      return Colors.purpleAccent;
    case SourceType.web:
      return Colors.tealAccent;
    case SourceType.local:
      return Colors.white70;
  }
}
