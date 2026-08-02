# R-Shop 檔案 → 紀錄 反查表

> **自動產生，不要手改。** 來源是 [FIX_LOGS.md](FIX_LOGS.md) 每條的 `**檔案**` 欄。
> 新增紀錄後重跑：`python scripts/build_fix_by_file.py`
>
> 用途與 [FIX_INDEX.md](FIX_INDEX.md) 相反：索引是「症狀 → 條目」，這裡是
> **「我要改這個檔 → 它身上以前發生過什麼」**。改檔案前先查這裡，
> 命中的條目多半就是會再踩一次的坑。

### `.agents/skills/rshop-build-deploy/SKILL.md`
- [R-Shop 建置環境失聯](FIX_LOGS.md)
- [R-Shop 建置 JDK 不相容](FIX_LOGS.md)

### `AGENTS.md`
- [R-Shop 建置環境失聯](FIX_LOGS.md)

### `android/app/build.gradle.kts`
- [AppID 衝突](FIX_LOGS.md)
- [R-Shop Channel 名稱硬編](FIX_LOGS.md)

### `android/app/src/main/kotlin/com/retro/rshop/tw/MainActivity.kt`
- [AppID 衝突](FIX_LOGS.md)
- [R-Shop Channel 名稱硬編](FIX_LOGS.md)

### `lib/features/home/home_view.dart`
- [R-Shop 目前來源](FIX_LOGS.md)
- [備援接進同步](FIX_LOGS.md)
- [同步不知道是哪一台](FIX_LOGS.md)
- [標頭高度與誤讀的按鍵字](FIX_LOGS.md)

### `lib/features/settings/sources_screen.dart`
- [R-Shop 目前來源](FIX_LOGS.md)
- [浮層只做了手把](FIX_LOGS.md)
- [黃色條與雙入口](FIX_LOGS.md)
- [標頭高度與誤讀的按鍵字](FIX_LOGS.md)
- [來源清單快捷鍵](FIX_LOGS.md)

### `lib/features/sources/endpoint_edit_screen.dart`
- [R-Shop 連線路由](FIX_LOGS.md)

### `lib/features/sources/endpoint_picker_overlay.dart`
- [R-Shop 連線路由](FIX_LOGS.md)
- [連線方式共用憑證](FIX_LOGS.md)
- [同步不知道是哪一台](FIX_LOGS.md)
- [浮層只做了手把](FIX_LOGS.md)

### `lib/features/sources/fallback_picker_overlay.dart`
- [R-Shop 來源備援](FIX_LOGS.md)
- [浮層只做了手把](FIX_LOGS.md)

### `lib/l10n/app_*.arb`
- [連線方式共用憑證](FIX_LOGS.md)
- [同步不知道是哪一台](FIX_LOGS.md)
- [來源清單快捷鍵](FIX_LOGS.md)

### `lib/models/config/app_config.dart`
- [R-Shop 目前來源](FIX_LOGS.md)

### `lib/models/config/provider_config.dart`
- [R-Shop 連線路由](FIX_LOGS.md)

### `lib/models/config/source.dart`
- [R-Shop 連線路由](FIX_LOGS.md)
- [R-Shop 來源備援](FIX_LOGS.md)
- [連線方式共用憑證](FIX_LOGS.md)

### `lib/providers/app_providers.dart`
- [同步不知道是哪一台](FIX_LOGS.md)

### `lib/services/database_service.dart`
- [R-Shop 連線路由](FIX_LOGS.md)

### `lib/services/device_info_service.dart`
- [R-Shop Channel 名稱硬編](FIX_LOGS.md)

### `lib/services/disk_space_service.dart`
- [R-Shop Channel 名稱硬編](FIX_LOGS.md)

### `lib/services/download_service.dart`
- [R-Shop Channel 名稱硬編](FIX_LOGS.md)

### `lib/services/endpoint_probe_service.dart`
- [R-Shop 連線路由](FIX_LOGS.md)
- [備援接進同步](FIX_LOGS.md)

### `lib/services/native_smb_service.dart`
- [R-Shop Channel 名稱硬編](FIX_LOGS.md)

### `lib/services/platform_channels.dart`
- [R-Shop Channel 名稱硬編](FIX_LOGS.md)

### `lib/services/provider_factory.dart`
- [R-Shop ProviderFactory 隱式初始化](FIX_LOGS.md)

### `lib/services/source_failover.dart`
- [R-Shop 來源備援](FIX_LOGS.md)
- [備援接進同步](FIX_LOGS.md)

### `lib/services/source_resolver.dart`
- [R-Shop 連線路由](FIX_LOGS.md)
- [R-Shop 目前來源](FIX_LOGS.md)

### `lib/services/sources_notifier.dart`
- [R-Shop 連線路由](FIX_LOGS.md)
- [R-Shop 目前來源](FIX_LOGS.md)
- [R-Shop 來源備援](FIX_LOGS.md)

### `lib/widgets/sync_badge.dart`
- [同步不知道是哪一台](FIX_LOGS.md)

### `test/widgets/sources_screen_test.dart`
- [來源清單快捷鍵](FIX_LOGS.md)

---

## 尚未指明檔案的條目

這些條目的 `**檔案**` 欄缺漏或標為待補，所以無法反查。補上之後重跑即可。

- R-Shop 測試基準
- R-Shop 實機重裝
