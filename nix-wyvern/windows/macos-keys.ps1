# installs windows/macos-keys.ahk: copies it next to the user's profile and starts it at every
# sign-in with admin rights, so the shortcuts also reach admin windows. admin powershell:
#   powershell -ExecutionPolicy Bypass -File macos-keys.ps1
$ahk = (Get-ChildItem "$env:ProgramFiles\AutoHotkey\v2\AutoHotkey64.exe", "$env:LOCALAPPDATA\Programs\AutoHotkey\v2\AutoHotkey64.exe" -ErrorAction SilentlyContinue | Select-Object -First 1).FullName
if (-not $ahk) { throw "autohotkey v2 is not installed: winget install AutoHotkey.AutoHotkey" }
$dir = "$env:APPDATA\macos-keys"
New-Item -ItemType Directory -Path $dir -Force | Out-Null
Copy-Item "$PSScriptRoot\macos-keys.ahk" "$dir\macos-keys.ahk" -Force

$action = New-ScheduledTaskAction -Execute $ahk -Argument "`"$dir\macos-keys.ahk`""
$trigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit 0
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Highest
Register-ScheduledTask -TaskName "macos-keys" -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Force | Out-Null

# (re)start it now
Get-Process AutoHotkey64 -ErrorAction SilentlyContinue | Stop-Process -Force
Start-ScheduledTask -TaskName "macos-keys"
Start-Sleep 2
"macos-keys running: " + [bool](Get-Process AutoHotkey64 -ErrorAction SilentlyContinue)
