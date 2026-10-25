# speed for wyvern's host without touching the looks (agreed 2026-10-25). admin powershell:
#   powershell -ExecutionPolicy Bypass -File perf.ps1
# then reboot. logs to %TEMP%\perf.log. visual effects, animations and transparency stay as they are.
# defender needs tamper protection off first (windows security > virus & threat protection >
# manage settings); no script can switch that, so the defender part is skipped while it is on.
# undo: defender services back to Start=2/3, the policies below, FeatureSettingsOverride removed.
Start-Transcript -Path "$env:TEMP\perf.log" -Force | Out-Null

function Set-Reg($path, $name, $value, $type = "DWord") {
  if (-not (Test-Path $path)) { New-Item -Path $path -Force | Out-Null }
  Set-ItemProperty -Path $path -Name $name -Value $value -Type $type
}

"== defender: protection off, services disabled"
if ((Get-MpComputerStatus).IsTamperProtected) {
  "SKIPPED: tamper protection is still on"
} else {
  Set-MpPreference -DisableRealtimeMonitoring $true -DisableBehaviorMonitoring $true -DisableIOAVProtection $true `
    -DisableScriptScanning $true -MAPSReporting Disabled -SubmitSamplesConsent NeverSend -ErrorAction SilentlyContinue
  $wd = "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender"
  Set-Reg $wd DisableAntiSpyware 1
  Set-Reg "$wd\Real-Time Protection" DisableRealtimeMonitoring 1
  Set-Reg "$wd\Real-Time Protection" DisableBehaviorMonitoring 1
  Set-Reg "$wd\Real-Time Protection" DisableOnAccessProtection 1
  Set-Reg "$wd\Real-Time Protection" DisableScanOnRealtimeEnable 1
  Set-Reg "$wd\Real-Time Protection" DisableIOAVProtection 1
  Set-Reg "$wd\Spynet" SpynetReporting 0
  Set-Reg "$wd\Spynet" SubmitSamplesConsent 2
  # no "virus protection is off" nags, no tray icon
  Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender Security Center\Notifications" DisableNotifications 1
  Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender Security Center\Notifications" DisableEnhancedNotifications 1
  Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run" SecurityHealth ([byte[]](3,0,0,0,0,0,0,0,0,0,0,0)) Binary
  # smartscreen
  Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" EnableSmartScreen 0
  Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" SmartScreenEnabled "Off" String
  Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\AppHost" EnableWebContentEvaluation 0
  Get-ScheduledTask -TaskPath "\Microsoft\Windows\Windows Defender\" -ErrorAction SilentlyContinue | Disable-ScheduledTask | Out-Null

  # the services cannot be disabled while windows runs normally: wdfilter guards their keys even
  # from trustedinstaller. so the reboot after this script goes through safe mode once, where
  # wdfilter is not loaded; a runonce job there disables them, restores normal boot and restarts
  $cmd = "$env:TEMP\safe-defender.cmd"
  Set-Content -Path $cmd -Encoding ascii -Value @(
    "@echo off",
    "for %%s in (WinDefend WdNisSvc WdNisDrv WdFilter WdBoot MDCoreSvc) do reg add `"HKLM\SYSTEM\CurrentControlSet\Services\%%s`" /v Start /t REG_DWORD /d 4 /f",
    "bcdedit /deletevalue {current} safeboot",
    "shutdown /r /t 5"
  )
  Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce" -Name "*wyvern-defender-off" -Value "cmd.exe /c `"$cmd`""
  bcdedit /set "{current}" safeboot minimal | Out-Null
  "the next reboot passes through safe mode once (no network for a few minutes, sign in if it asks)"
}

"== power: high performance on ac (this laptop hides it, so it is made from the built-in template)"
$plan = (powercfg /duplicatescheme 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c) -replace ".*GUID: ([0-9a-f-]+).*", '$1'
powercfg /changename $plan "High Performance (wyvern)"
powercfg /setactive $plan
# the same host settings windows-setup.ps1 gave the old plan: never sleep on ac, the lid does nothing on ac
powercfg /change standby-timeout-ac 0
powercfg /change hibernate-timeout-ac 0
powercfg /setacvalueindex $plan SUB_BUTTONS LIDACTION 0
powercfg /setactive $plan
"active plan: " + (powercfg /getactivescheme)

"== gpu: hardware scheduling on, games pinned to the rtx 2060"
Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" HwSchMode 2
$prefs = "HKCU:\Software\Microsoft\DirectX\UserGpuPreferences"
foreach ($exe in "C:\Riot Games\VALORANT\live\ShooterGame\Binaries\Win64\VALORANT-Win64-Shipping.exe",
                 "C:\Riot Games\Riot Client\RiotClientServices.exe",
                 "C:\Program Files (x86)\Steam\steamapps\common\Counter-Strike Global Offensive\game\bin\win64\cs2.exe",
                 "C:\Program Files (x86)\Steam\steam.exe") {
  if (Test-Path $exe) { "high performance gpu: $exe"; Set-Reg $prefs $exe "GpuPreference=2;" String }
}
Set-Reg "HKCU:\Software\Microsoft\GameBar" AutoGameModeEnabled 1

"== scheduling: games get the high multimedia profile, background reserves less"
$mm = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
Set-Reg $mm SystemResponsiveness 10
Set-Reg "$mm\Tasks\Games" "GPU Priority" 8
Set-Reg "$mm\Tasks\Games" Priority 6
Set-Reg "$mm\Tasks\Games" "Scheduling Category" "High" String
Set-Reg "$mm\Tasks\Games" "SFIO Priority" "High" String

"== memory: no compression, no sysmain (40gb of ram)"
Disable-MMAgent -MemoryCompression
Stop-Service SysMain -Force -ErrorAction SilentlyContinue
Set-Service SysMain -StartupType Disabled

"== startup: no built-in delay before startup apps"
Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Serialize" StartupDelayInMSec 0

"== spectre / meltdown mitigations off"
$mmk = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"
Set-Reg $mmk FeatureSettingsOverride 3
Set-Reg $mmk FeatureSettingsOverrideMask 3

"== wyvern: 10 of 12 threads, 2 always left for windows and games"
$wslconfig = "$env:USERPROFILE\.wslconfig"
(Get-Content $wslconfig) -replace "^processors=\d+", "processors=10" | Set-Content $wslconfig -Encoding ascii
Get-Content $wslconfig | Select-String processors

"done, reboot to apply"
Stop-Transcript | Out-Null
