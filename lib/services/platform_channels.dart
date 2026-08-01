/// Single source of truth for every Android platform-channel name.
///
/// ## Why this file exists
///
/// The channel names are namespaced by the Android `applicationId`, which
/// differs between branches: upstream `main` uses `com.retro.rshop`, this
/// branch (`main-zh`) uses `com.retro.rshop.tw`. The names used to be
/// hard-coded in 20 places across Kotlin, Dart and the tests. Merging upstream
/// and picking only one side still compiled fine but blew up at runtime with
/// `MissingPluginException` on every native call — and
/// `NativeSmbService.testConnection` swallows `PlatformException` into a
/// generic "connection failed", which makes it very hard to diagnose.
///
/// ## When merging upstream
///
/// [kChannelPrefix] below is the **only** place on the Dart side that needs
/// adjusting. On the Kotlin side the prefix is derived from
/// `BuildConfig.APPLICATION_ID`
/// (`android/app/src/main/kotlin/com/retro/rshop/tw/MainActivity.kt`), which
/// tracks `applicationId` in `android/app/build.gradle.kts` automatically.
///
/// **The two must stay identical.** If `applicationId` changes, change
/// [kChannelPrefix] to match in the same commit, otherwise every native
/// feature (zip extraction, storage/disk info, SMB) silently stops working.
///
/// The suffixes (`/zip`, `/storage`, `/zip_progress`, `/smb`, `/smb_progress`)
/// must never change — they are the contract with `MainActivity.kt`.
library;

/// Must equal `applicationId` in `android/app/build.gradle.kts`.
const String kChannelPrefix = 'com.retro.rshop.tw';

/// MethodChannel — zip extraction (`DownloadService`).
const String kZipChannel = '$kChannelPrefix/zip';

/// EventChannel — zip extraction progress (`DownloadService`).
const String kZipProgressChannel = '$kChannelPrefix/zip_progress';

/// MethodChannel — free disk space & device memory
/// (`DiskSpaceService`, `DeviceInfoService`).
const String kStorageChannel = '$kChannelPrefix/storage';

/// MethodChannel — native SMB client (`NativeSmbService`).
const String kSmbChannel = '$kChannelPrefix/smb';

/// EventChannel — native SMB transfer progress (`NativeSmbService`).
const String kSmbProgressChannel = '$kChannelPrefix/smb_progress';
