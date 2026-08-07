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

### `lib/features/game_list/widgets/game_grid.dart`
- [R-Shop analyze 六項](FIX_LOGS.md)

### `lib/features/game_list/{game_list_screen.dart,logic/game_list_controller.dart}`
- [R-Shop 來源群組](FIX_LOGS.md)

### `lib/features/home/home_view.dart`
- [R-Shop 目前來源](FIX_LOGS.md)
- [備援接進同步](FIX_LOGS.md)
- [同步不知道是哪一台](FIX_LOGS.md)
- [標頭高度與誤讀的按鍵字](FIX_LOGS.md)
- [使用中與顯示分家](FIX_LOGS.md)
- [R-Shop 來源群組](FIX_LOGS.md)
- [R-Shop 備援架構重構](FIX_LOGS.md)

### `lib/features/library/library_screen.dart`
- [R-Shop analyze 六項](FIX_LOGS.md)

### `lib/features/onboarding/widgets/romm_legacy_login_screen.dart`
- [R-Shop analyze 六項](FIX_LOGS.md)

### `lib/features/onboarding/widgets/welcome_chooser_step.dart`
- [R-Shop analyze 六項](FIX_LOGS.md)

### `lib/features/settings/sources_screen.dart`
- [R-Shop 目前來源](FIX_LOGS.md)
- [浮層只做了手把](FIX_LOGS.md)
- [黃色條與雙入口](FIX_LOGS.md)
- [標頭高度與誤讀的按鍵字](FIX_LOGS.md)
- [來源清單快捷鍵](FIX_LOGS.md)
- [使用中與顯示分家](FIX_LOGS.md)
- [R-Shop 來源群組](FIX_LOGS.md)
- [R-Shop 群組浮層焦點](FIX_LOGS.md)
- [R-Shop 備援架構重構](FIX_LOGS.md)

### `lib/features/sources/endpoint_edit_screen.dart`
- [R-Shop 連線路由](FIX_LOGS.md)
- [R-Shop 自動選最優路線](FIX_LOGS.md)

### `lib/features/sources/endpoint_picker_overlay.dart`
- [R-Shop 連線路由](FIX_LOGS.md)
- [連線方式共用憑證](FIX_LOGS.md)
- [同步不知道是哪一台](FIX_LOGS.md)
- [浮層只做了手把](FIX_LOGS.md)
- [R-Shop 自動選最優路線](FIX_LOGS.md)
- [R-Shop 來源群組](FIX_LOGS.md)
- [R-Shop 浮層操作形狀](FIX_LOGS.md)
- [R-Shop 連線方式對齊群組](FIX_LOGS.md)
- [R-Shop 模式收成打勾](FIX_LOGS.md)

### `lib/features/sources/fallback_picker_overlay.dart`
- [R-Shop 來源備援](FIX_LOGS.md)
- [浮層只做了手把](FIX_LOGS.md)
- [R-Shop 備援架構重構](FIX_LOGS.md)

### `lib/features/sources/group_picker_overlay.dart`
- [R-Shop 來源群組](FIX_LOGS.md)
- [R-Shop 群組合併卡住](FIX_LOGS.md)
- [R-Shop 群組浮層焦點](FIX_LOGS.md)
- [R-Shop 浮層操作形狀](FIX_LOGS.md)
- [R-Shop 模式收成打勾](FIX_LOGS.md)

### `lib/features/sources/manual_source_add_screen.dart`
- [R-Shop analyze 六項](FIX_LOGS.md)

### `lib/l10n/app_*.arb`
- [連線方式共用憑證](FIX_LOGS.md)
- [同步不知道是哪一台](FIX_LOGS.md)
- [來源清單快捷鍵](FIX_LOGS.md)
- [R-Shop 自動選最優路線](FIX_LOGS.md)
- [R-Shop 連線方式對齊群組](FIX_LOGS.md)
- [R-Shop 模式收成打勾](FIX_LOGS.md)

### `lib/l10n/app_{de,en,es,fr,ja,pt,zh}.arb`
- [R-Shop 來源群組](FIX_LOGS.md)

### `lib/l10n/app_{de,es,fr,ja,pt}.arb`
- [R-Shop onboarding 五語系缺字串](FIX_LOGS.md)

### `lib/models/config/app_config.dart`
- [R-Shop 目前來源](FIX_LOGS.md)
- [使用中與顯示分家](FIX_LOGS.md)
- [R-Shop 來源群組](FIX_LOGS.md)
- [R-Shop 備援架構重構](FIX_LOGS.md)

### `lib/models/config/provider_config.dart`
- [R-Shop 連線路由](FIX_LOGS.md)

### `lib/models/config/source.dart`
- [R-Shop 連線路由](FIX_LOGS.md)
- [R-Shop 來源備援](FIX_LOGS.md)
- [連線方式共用憑證](FIX_LOGS.md)
- [R-Shop 路線各自驗證](FIX_LOGS.md)
- [R-Shop 自動選最優路線](FIX_LOGS.md)
- [R-Shop 備援架構重構](FIX_LOGS.md)

### `lib/providers/app_providers.dart`
- [同步不知道是哪一台](FIX_LOGS.md)

### `lib/services/database_service.dart`
- [R-Shop 連線路由](FIX_LOGS.md)
- [R-Shop 路線各自驗證](FIX_LOGS.md)
- [R-Shop 來源群組](FIX_LOGS.md)
- [R-Shop 群組合併卡住](FIX_LOGS.md)

### `lib/services/device_info_service.dart`
- [R-Shop Channel 名稱硬編](FIX_LOGS.md)

### `lib/services/disk_space_service.dart`
- [R-Shop Channel 名稱硬編](FIX_LOGS.md)

### `lib/services/download_service.dart`
- [R-Shop Channel 名稱硬編](FIX_LOGS.md)

### `lib/services/endpoint_probe_service.dart`
- [R-Shop 連線路由](FIX_LOGS.md)
- [備援接進同步](FIX_LOGS.md)
- [R-Shop 自動選最優路線](FIX_LOGS.md)
- [R-Shop 來源群組](FIX_LOGS.md)
- [R-Shop 備援架構重構](FIX_LOGS.md)

### `lib/services/library_sync_service.dart`
- [R-Shop 來源群組](FIX_LOGS.md)

### `lib/services/native_smb_service.dart`
- [R-Shop Channel 名稱硬編](FIX_LOGS.md)

### `lib/services/platform_channels.dart`
- [R-Shop Channel 名稱硬編](FIX_LOGS.md)

### `lib/services/provider_factory.dart`
- [R-Shop ProviderFactory 隱式初始化](FIX_LOGS.md)

### `lib/services/source_failover.dart`
- [R-Shop 來源備援](FIX_LOGS.md)
- [備援接進同步](FIX_LOGS.md)
- [使用中與顯示分家](FIX_LOGS.md)
- [R-Shop 來源群組](FIX_LOGS.md)
- [R-Shop 同步路線解算](FIX_LOGS.md)
- [R-Shop 備援架構重構](FIX_LOGS.md)

### `lib/services/source_resolver.dart`
- [R-Shop 連線路由](FIX_LOGS.md)
- [R-Shop 目前來源](FIX_LOGS.md)
- [R-Shop 備援架構重構](FIX_LOGS.md)

### `lib/services/sources_notifier.dart`
- [R-Shop 連線路由](FIX_LOGS.md)
- [R-Shop 目前來源](FIX_LOGS.md)
- [R-Shop 來源備援](FIX_LOGS.md)
- [使用中與顯示分家](FIX_LOGS.md)
- [R-Shop 路線各自驗證](FIX_LOGS.md)
- [R-Shop 自動選最優路線](FIX_LOGS.md)
- [R-Shop 來源群組](FIX_LOGS.md)
- [R-Shop 備援架構重構](FIX_LOGS.md)

### `lib/widgets/console_dialog.dart`
- [R-Shop analyze 六項](FIX_LOGS.md)

### `lib/widgets/sync_badge.dart`
- [同步不知道是哪一台](FIX_LOGS.md)
- [R-Shop 來源群組](FIX_LOGS.md)

### `scripts/build_fix_by_file.py`
- [R-Shop 反查不到](FIX_LOGS.md)

### `test/active_source_test.dart`
- [使用中與顯示分家](FIX_LOGS.md)

### `test/database_service_merge_perf_test.dart`
- [R-Shop 群組合併卡住](FIX_LOGS.md)

### `test/database_service_routes_test.dart`
- [R-Shop 路線各自驗證](FIX_LOGS.md)

### `test/database_service_v15_migration_test.dart`
- [R-Shop 路線各自驗證](FIX_LOGS.md)

### `test/endpoint_probe_service_test.dart`
- [R-Shop 自動選最優路線](FIX_LOGS.md)
- [R-Shop 備援架構重構](FIX_LOGS.md)

### `test/l10n_completeness_test.dart`
- [R-Shop onboarding 五語系缺字串](FIX_LOGS.md)

### `test/source_endpoint_test.dart`
- [R-Shop 路線各自驗證](FIX_LOGS.md)
- [R-Shop 自動選最優路線](FIX_LOGS.md)

### `test/source_failover_choice_test.dart`
- [R-Shop 備援架構重構](FIX_LOGS.md)

### `test/source_failover_sync_test.dart`
- [使用中與顯示分家](FIX_LOGS.md)
- [R-Shop 同步路線解算](FIX_LOGS.md)
- [R-Shop 備援架構重構](FIX_LOGS.md)

### `test/source_resolver_test.dart`
- [R-Shop 路線各自驗證](FIX_LOGS.md)

### `test/sources_notifier_endpoints_test.dart`
- [R-Shop 路線各自驗證](FIX_LOGS.md)
- [R-Shop 自動選最優路線](FIX_LOGS.md)

### `test/widgets/endpoint_picker_overlay_test.dart`
- [R-Shop 自動選最優路線](FIX_LOGS.md)
- [R-Shop 連線方式對齊群組](FIX_LOGS.md)

### `test/widgets/sources_screen_test.dart`
- [來源清單快捷鍵](FIX_LOGS.md)

### `test/widgets/{endpoint_picker_overlay,group_picker_overlay}_test.dart`
- [R-Shop 浮層操作形狀](FIX_LOGS.md)
- [R-Shop 模式收成打勾](FIX_LOGS.md)

### `test/{database_service_v16_migration,sources_notifier_groups,widgets/group_picker_overlay}_test.dart`
- [R-Shop 來源群組](FIX_LOGS.md)

---

## 尚未指明檔案的條目

這些條目沒有可反查的檔案。**多數是正確狀態**——環境診斷、部署作業、需求判定本來就沒有程式碼變更，`**檔案**` 欄寫的是「無程式碼變更」。

只有標成「待補」的才是真的欠一份說明。

- R-Shop 測試基準
- R-Shop 實機重裝
- R-Shop 自動選最快
- R-Shop ƴsب^
- R-Shop 來源停用快取
- R-Shop QR碼手把導覽
- R-Shop QR碼手把導覽
- R-Shop 語系鎖定詞彙統一
- R-Shop 主頁面移除來源切換
