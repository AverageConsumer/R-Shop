# R-Shop Release Guide

## 1. Vorbereitung

```bash
cd ~/Dokumente/r_shop
```

Sicherstellen dass alles committet ist:

```bash
git add -A
git status
```

Commit erstellen:

```bash
git commit -m "Release v0.9.8 Beta"
```

Push:

```bash
git push origin main
```

---

## 2. Release-APK bauen

```bash
flutter clean
flutter pub get
flutter build apk --release
```

APK liegt unter:

```
build/app/outputs/flutter-apk/app-release.apk
```

Kopieren und umbenennen:

```bash
cp build/app/outputs/flutter-apk/app-release.apk ~/R-Shop-v0.9.8-beta.apk
```

---

## 3a. GitHub Release erstellen (mit `gh` CLI)

```bash
gh release create v0.9.8-beta \
  ~/R-Shop-v0.9.8-beta.apk \
  --title "v0.9.8 Beta" \
  --prerelease \
  --notes "$(cat <<'EOF'
## What's New in v0.9.8

### Highlights
- **Crash Log Service** — local error log with export via share sheet (Settings > Export Error Log)
- **HTTP download depth guard** — prevents infinite recursion on resume-restart
- **Overlay priority crash fix** — no more Riverpod state modification errors during screen transitions
- **Detail screen overflow fix** — system badge no longer clips on narrow layouts
- **Zone mismatch fix** — startup warning eliminated
- **Reduced log noise** — cleaner debug output in production

### Full Changelog
See [CHANGELOG.md](CHANGELOG.md) for all details.

### Install
Download the APK below and install manually, or add this repo to [Obtainium](https://github.com/ImranR98/Obtainium) for automatic updates.
EOF
)"
```

---

## 3b. GitHub Release manuell (Browser)

1. Gehe zu: **https://github.com/AverageConsumer/R-Shop/releases/new**
2. **Tag:** `v0.9.8-beta` (neu erstellen, Target: `main`)
3. **Title:** `v0.9.8 Beta`
4. **Description** (kopieren):

```
## What's New in v0.9.8

### Highlights
- **Crash Log Service** — local error log with export via share sheet (Settings > Export Error Log)
- **HTTP download depth guard** — prevents infinite recursion on resume-restart
- **Overlay priority crash fix** — no more Riverpod state modification errors during screen transitions
- **Detail screen overflow fix** — system badge no longer clips on narrow layouts
- **Zone mismatch fix** — startup warning eliminated
- **Reduced log noise** — cleaner debug output in production

### Full Changelog
See [CHANGELOG.md](CHANGELOG.md) for all details.

### Install
Download the APK below and install manually, or add this repo to [Obtainium](https://github.com/ImranR98/Obtainium) for automatic updates.
```

5. **APK hochladen:** `R-Shop-v0.9.8-beta.apk` als Asset anhängen
6. **Haken setzen:** "Set as a pre-release"
7. **Publish release**

---

## Checkliste

- [ ] Alle Änderungen committet und gepusht
- [ ] `pubspec.yaml` Version ist `0.9.8+1`
- [ ] `README.md` Badge zeigt `0.9.8`
- [ ] `CHANGELOG.md` hat `[0.9.8]` Eintrag
- [ ] `flutter analyze` — keine Fehler
- [ ] `flutter test` — alle Tests grün
- [ ] Release-APK gebaut (`--release`)
- [ ] GitHub Release erstellt mit Pre-Release-Flag
- [ ] APK als Asset angehängt
