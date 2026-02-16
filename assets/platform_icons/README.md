# Platform Icons Directory

This directory contains custom icons for the GUI platform selector.

## Quick Start

1. Add square PNG/JPG images here (recommended: 96x96, 128x128, or 256x256)
2. Name them to match your platform keys (e.g., `NES.png`, `SNES.png`, `PS1.png`)
3. They'll automatically appear in the GUI instead of border images

## Example

```
platform_icons/
├── NES.png          # Clean NES console or logo
├── SNES.png         # SNES console image
├── PS1.png          # PlayStation logo
├── GAMECUBE.png     # GameCube icon
└── ...
```

## Tips

- Use clean console/logo images (not border overlays)
- Square aspect ratio works best
- High contrast for dark GUI background
- Transparent PNG recommended
- If no custom icon exists, GUI will use border image as fallback

## Full Documentation

See [PLATFORM_ICONS_GUIDE.md](../docs/PLATFORM_ICONS_GUIDE.md) for complete documentation including:
- Design guidelines
- Configuration options
- Icon sources
- Troubleshooting
- Advanced features

## Free Icon Sources

- **Wikipedia/Wikimedia** - Console photos (CC licensed)
- **IconArchive** - Gaming console icons
- **FlatIcon** - Gaming/console icon packs
- Google "console name logo transparent"
