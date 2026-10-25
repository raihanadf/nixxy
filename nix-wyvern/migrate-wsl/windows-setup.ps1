# step 2 of migrate-wsl/README.md, in windows 10, in an admin powershell:
#   powershell -ExecutionPolicy Bypass -File windows-setup.ps1
# safe to run again. it turns windows into a host that keeps wyvern up:
# wsl installed and current, no sleep or hibernation on ac, the lid does nothing on ac,
# fast startup off (so nixos can still write to C: for the backup), no surprise restarts
# for updates while signed in, a memory cap for the vm, and a task that keeps the
# NixOS distro running from sign-in.
$ErrorActionPreference = "Stop"

# wsl itself. the store version is the one with systemd, which nixos needs
wsl --install --no-distribution
wsl --update

# power: never sleep or hibernate on ac, closing the lid on ac does nothing
powercfg /change standby-timeout-ac 0
powercfg /change hibernate-timeout-ac 0
powercfg /setacvalueindex SCHEME_CURRENT SUB_BUTTONS LIDACTION 0
powercfg /setactive SCHEME_CURRENT
# hibernation off also turns fast startup off, which would leave C: dirty for linux while
# nixos still lived next to it. once it is gone, debloat.ps1 turns fast startup back on
powercfg /hibernate off

# jakarta time, same as wyvern's Asia/Jakarta (windows' utc+7 zone covers bangkok, hanoi, jakarta).
# the time service runs always, so a 24/7 host never drifts
Set-TimeZone -Id "SE Asia Standard Time"
Set-Service W32Time -StartupType Automatic
Start-Service W32Time
w32tm /config /manualpeerlist:"time.windows.com,0x9 pool.ntp.org,0x9" /syncfromflags:manual /update | Out-Null

# windows update: download and install, but never restart while someone is signed in
$au = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
New-Item -Path $au -Force | Out-Null
Set-ItemProperty -Path $au -Name NoAutoRebootWithLoggedOnUsers -Value 1 -Type DWord

# the vm: 38GB machine, leave windows ~10GB. give memory back to windows when idle
@"
[wsl2]
memory=28GB
swap=8GB
processors=12

[experimental]
autoMemoryReclaim=gradual
"@ | Set-Content -Path "$env:USERPROFILE\.wslconfig" -Encoding ascii

# keep NixOS running: wsl stops a distro once nothing is attached to it, so a
# `sleep infinity` holds it open from sign-in. wscript runs it with no window (style 0).
# needs automatic sign-in (README step 2)
$keepalive = "$env:USERPROFILE\wyvern-wsl.vbs"
'CreateObject("WScript.Shell").Run "wsl.exe -d NixOS --exec /run/current-system/sw/bin/sleep infinity", 0, True' | Set-Content -Path $keepalive -Encoding ascii
$action = New-ScheduledTaskAction -Execute "wscript.exe" -Argument "`"$keepalive`""
$trigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
# 30s after sign-in: nixos booting docker, honcho and lerd at the same moment as the desktop made
# the first half minute after a (fast startup) boot feel slow; the desktop settles first now
$trigger.Delay = "PT30S"
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit 0 -RestartCount 999 -RestartInterval (New-TimeSpan -Minutes 1) -Hidden
Register-ScheduledTask -TaskName "wyvern-wsl" -Action $action -Trigger $trigger -Settings $settings -Force | Out-Null

Write-Host "done. reboot once so wsl finishes installing, then set up automatic sign-in (README step 2)."
