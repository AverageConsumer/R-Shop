# check.ps1 — analyze + test，並且只回報「真正的回歸」。
#
# 為什麼有這支：`flutter test` 全跑本來就會有六個失敗（Windows 環境與需要真的
# RomM 在跑的 smoke test），每次人工比對「這次的失敗和上次一樣嗎」既慢又容易
# 看漏。基準清單收在 scripts/test_baseline.txt，這支只印出**不在清單上**的失敗，
# 以及清單上**現在會過**的項目（那代表基準過期了，要更新）。
#
# 用法：
#   powershell -ExecutionPolicy Bypass -File scripts/check.ps1
#   ... -SkipAnalyze          只跑測試
#   ... -Only test/foo_test.dart   只跑單一檔案（不比對基準）
#
# 注意：單檔測試是秒級的，全跑約 1.5 分鐘。改一個檔就全跑是這個專案最容易
# 浪費掉的時間，開發中用 -Only，收尾再全跑一次。

param(
  [switch]$SkipAnalyze,
  [string]$Only = ''
)

$ErrorActionPreference = 'Stop'
# Windows PowerShell 5.1 prints this file's Chinese as mojibake unless the
# console is told the output is UTF-8. The file itself needs the BOM for the
# same reason — without it the parser reads it as ANSI and the strings break.
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$flutter = 'D:\flutter\bin\flutter.bat'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

if (-not (Test-Path $flutter)) {
  Write-Error "flutter not found at $flutter — 路徑會隨機器變，見 GLOBAL_DEV_NOTES.md"
}

if (-not $SkipAnalyze) {
  Write-Host '== analyze =='
  $analyze = & $flutter analyze 2>&1
  $issues = $analyze | Select-String 'error -|warning -|info -'
  if ($issues) {
    $issues | ForEach-Object { Write-Host $_ }
    Write-Host ('analyze: {0} issues' -f $issues.Count)
  } else {
    Write-Host 'analyze: clean'
  }
}

Write-Host '== test =='
if ($Only) {
  & $flutter test $Only
  exit $LASTEXITCODE
}

$out = & $flutter test -r expanded 2>&1

# 總數：最後一行 "+N -M" 就是結果。
$totals = ($out | Select-String -Pattern '\+\d+( -\d+)?: (Some tests failed|All tests passed)' |
  Select-Object -Last 1)
if ($totals) {
  Write-Host ('totals: {0}' -f $totals.ToString().Trim())
} else {
  Write-Host 'totals: (not found — did the run crash?)'
}

# 失敗清單。PowerShell 的坑：$array -notmatch 'x' 是**過濾**不是判斷，
# 所以這裡一律走 Where-Object，不要寫成 if ($fails -notmatch ...)。
$fails = $out |
  Select-String -Pattern '\[E\]$' |
  ForEach-Object { $_.ToString() -replace '^\d\d:\d\d \+\d+ -\d+: ', '' -replace ' \[E\]$', '' } |
  ForEach-Object { $_ -replace '^.*R-Shop[\\/]', '' } |
  Sort-Object -Unique

$baselineFile = Join-Path $PSScriptRoot 'test_baseline.txt'
$baseline = @()
if (Test-Path $baselineFile) {
  $baseline = Get-Content $baselineFile | Where-Object { $_ -and -not $_.StartsWith('#') }
}

$new = $fails | Where-Object { $baseline -notcontains $_ }
$fixed = $baseline | Where-Object { $fails -notcontains $_ }

if ($new) {
  Write-Host ''
  Write-Host '!! 不在基準上的失敗（當成回歸看）:' -ForegroundColor Red
  $new | ForEach-Object { Write-Host "   $_" }
} else {
  Write-Host 'no regressions (每個失敗都在基準清單上)'
}

if ($fixed) {
  Write-Host ''
  Write-Host '基準上的項目現在會過了，請更新 scripts/test_baseline.txt:' -ForegroundColor Yellow
  $fixed | ForEach-Object { Write-Host "   $_" }
}

# game_list_controller 那幾條是時序敏感的，全跑時偶爾會多失敗一兩個，
# 單獨跑就會過。單次失敗不足以認定回歸——連跑三次再說。
if ($new -and ($new -join "`n") -match 'game_list_controller') {
  Write-Host ''
  Write-Host '提示：game_list_controller 會偶發失敗，先用 -Only 單跑三次再判斷。'
}

if ($new) { exit 1 } else { exit 0 }
