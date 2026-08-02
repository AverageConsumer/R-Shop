# Build R-Shop and put it on the AYN Thor.
#
# The same six steps were being typed out by hand every time, including the
# JDK check that is easy to skip and expensive to skip — see
# .agents/skills/rshop-build-deploy/SKILL.md.
#
#   scripts\deploy.ps1              analyze, build, install, launch, check
#   scripts\deploy.ps1 -SkipAnalyze skip the analyze step
#   scripts\deploy.ps1 -NoLaunch    install without starting the app
#   scripts\deploy.ps1 -Release     build the release APK instead

param(
    [switch]$SkipAnalyze,
    [switch]$NoLaunch,
    [switch]$Release,
    [string]$Serial
)

$ErrorActionPreference = 'Stop'

$flutter = 'D:\flutter\bin\flutter.bat'
$jdk     = 'C:\Program Files\Java\jdk-21'
$adb     = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
$pkg     = 'com.retro.rshop.tw'
$root    = Split-Path -Parent $PSScriptRoot

foreach ($tool in @($flutter, $adb)) {
    if (-not (Test-Path $tool)) { throw "not found: $tool" }
}
Set-Location $root

# --- Step 0: the JDK pointer, which empties itself -------------------------
# Gradle 8.14 cannot parse Java 25 and reports it as a bare "25.0.2", which
# reads like anything but a JDK mismatch. Checking costs a second.
$settings = Join-Path $env:APPDATA '.flutter_settings'
$jdkDir = $null
if (Test-Path $settings) {
    $jdkDir = (Get-Content $settings -Raw | ConvertFrom-Json).'jdk-dir'
}
if ($jdkDir -ne $jdk) {
    Write-Host "jdk-dir is '$jdkDir' — setting it to $jdk" -ForegroundColor Yellow
    & $flutter config --jdk-dir $jdk | Out-Null
    # A daemon started under the old JVM survives the config change.
    & (Join-Path $root 'android\gradlew.bat') --stop 2>&1 | Out-Null
}

# --- Step 1: analyze -------------------------------------------------------
# Green here means nothing about focus, touch, overflow or layout. Those only
# show up on the device — see .agents/skills/rshop-touch-and-gamepad.
if (-not $SkipAnalyze) {
    Write-Host '== analyze ==' -ForegroundColor Cyan
    $analyze = & $flutter analyze lib 2>&1
    $issues = $analyze | Select-String -Pattern '^\s*(error|warning|info) -'
    $errors = $issues | Select-String -Pattern '^\s*error -'
    if ($errors) {
        $errors | ForEach-Object { Write-Host $_.Line -ForegroundColor Red }
        throw 'analyze found errors'
    }
    Write-Host "  $($issues.Count) issues, no errors"
}

# --- Step 2: build ---------------------------------------------------------
Write-Host '== build ==' -ForegroundColor Cyan
$mode = if ($Release) { '--release' } else { '--debug' }
& $flutter build apk $mode 2>&1 | Select-Object -Last 1
if ($LASTEXITCODE -ne 0) { throw 'build failed' }
$apk = if ($Release) {
    'build\app\outputs\flutter-apk\app-release.apk'
} else {
    'build\app\outputs\flutter-apk\app-debug.apk'
}

# --- Step 3: install -------------------------------------------------------
Write-Host '== install ==' -ForegroundColor Cyan
$target = if ($Serial) { @('-s', $Serial) } else { @() }
$out = & $adb @target install -r $apk 2>&1
# Joined first: -match against an array filters it instead of testing it, so
# the array form is truthy whenever any line fails to match — which is every
# successful install, since adb also prints "Performing Streamed Install".
if (($out -join "`n") -notmatch 'Success') {
    $out | ForEach-Object { Write-Host $_ -ForegroundColor Red }
    # A differently-signed APK refuses to install with no build-time warning.
    throw 'install failed — if the signature differs, uninstall first (ASK before doing that: it takes the data with it)'
}

if ($NoLaunch) { Write-Host 'installed, not launched'; exit 0 }

# --- Step 4: launch and look --------------------------------------------
& $adb @target logcat -c
& $adb @target shell am start -n "$pkg/.MainActivity" | Out-Null
Start-Sleep -Seconds 6

$appPid = (& $adb @target shell pidof $pkg).Trim()
if (-not $appPid) { throw 'app is not running after launch' }
Write-Host "running, pid $appPid" -ForegroundColor Green

# Layout overflow is the yellow-and-black stripe. logcat catches it; a
# screenshot on this device grabs the wrong panel.
$bad = & $adb @target logcat -d -s 'flutter:*' 'AndroidRuntime:E' |
    Select-String -Pattern 'RenderFlex|overflowed|Exception'
if ($bad) {
    Write-Host '-- logcat --' -ForegroundColor Yellow
    $bad | Select-Object -First 10 | ForEach-Object { Write-Host $_.Line }
} else {
    Write-Host 'logcat clean (no overflow, no exceptions)'
}
