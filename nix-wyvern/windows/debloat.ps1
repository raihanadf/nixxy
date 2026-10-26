# windows 10 debloat for wyvern's host (as far as it goes, agreed 2026-10-25). admin powershell:
#   powershell -ExecutionPolicy Bypass -File debloat.ps1
# makes a restore point first and logs everything to %TEMP%\debloat.log.
# never touches: wsl / virtual machine platform / hyper-v compute, task scheduler and the
# wyvern-wsl task, riot vanguard, nvidia / realtek / intel drivers, webview2 (and edgeupdate,
# which only keeps webview2 current; the new teams needs it), windows update, the store,
# app installer (winget), windows terminal, teams, photos, calculator, snipping tool, print to pdf.
# undo: the restore point, store apps reinstall from the store, startup items re-enable in
# task manager, services and policies are listed below.
$ErrorActionPreference = "Continue"
Start-Transcript -Path "$env:TEMP\debloat.log" -Force | Out-Null

function Set-Reg($path, $name, $value, $type = "DWord") {
  if (-not (Test-Path $path)) { New-Item -Path $path -Force | Out-Null }
  Set-ItemProperty -Path $path -Name $name -Value $value -Type $type
}

function Snapshot($label) {
  $os = Get-CimInstance Win32_OperatingSystem
  $vm = (Get-Process vmmem -ErrorAction SilentlyContinue | Measure-Object WorkingSet64 -Sum).Sum
  "{0}: windows ram {1:N2} GB (without vmmem), services running {2}, store apps {3}" -f $label,
    ((($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) * 1KB - $vm) / 1GB),
    (Get-Service | Where-Object Status -eq Running).Count,
    (Get-AppxPackage -AllUsers | Where-Object { -not $_.IsFramework -and $_.SignatureKind -eq "Store" }).Count
}

Snapshot "before"

"== uac: stays on (store apps need it) but admin elevates without a prompt, so wyvern can admin from afar"
Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" ConsentPromptBehaviorAdmin 0
Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" PromptOnSecureDesktop 0

"== restore point"
Enable-ComputerRestore -Drive "C:\"
# windows allows one restore point a day by default; let this one through
Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore" SystemRestorePointCreationFrequency 0
Checkpoint-Computer -Description "before debloat" -RestorePointType MODIFY_SETTINGS

"== store apps"
$apps = @(
  "Microsoft.549981C3F5F10",            # cortana
  "Microsoft.BingSearch", "Microsoft.BingWeather",
  "Microsoft.GetHelp", "Microsoft.Getstarted",
  "Microsoft.Microsoft3DViewer", "Microsoft.MSPaint",
  "Microsoft.MicrosoftSolitaireCollection", "Microsoft.MicrosoftStickyNotes",
  "Microsoft.MixedReality.Portal",
  "Microsoft.Office.OneNote", "Microsoft.OutlookForWindows", "microsoft.windowscommunicationsapps",
  "Microsoft.People", "Microsoft.SkypeApp", "Microsoft.Wallet",
  "Microsoft.Windows.DevHome", "Microsoft.WindowsAlarms", "Microsoft.WindowsCamera",
  "Microsoft.WindowsFeedbackHub", "Microsoft.WindowsMaps", "Microsoft.WindowsSoundRecorder",
  "Microsoft.YourPhone", "MicrosoftWindows.CrossDevice",
  "Microsoft.ZuneMusic", "Microsoft.ZuneVideo",
  "Microsoft.XboxApp", "Microsoft.Xbox.TCUI", "Microsoft.XboxGameOverlay", "Microsoft.XboxGamingOverlay",
  "Microsoft.XboxIdentityProvider", "Microsoft.XboxSpeechToTextOverlay",
  # not all of these are installed here; a missing one is skipped
  "Microsoft.MicrosoftOfficeHub", "Microsoft.Todos", "Microsoft.PowerAutomateDesktop", "Clipchamp.Clipchamp",
  "MicrosoftCorporationII.QuickAssist", "Microsoft.Windows.Ai.Copilot.Provider", "Microsoft.Copilot",
  "Microsoft.MicrosoftJournal", "Microsoft.549981C3F5F10", "Microsoft.MicrosoftEdge.Stable",
  "Microsoft.MicrosoftEdgeDevToolsClient", "MicrosoftWindows.Client.WebExperience", "Microsoft.Windows.PeopleExperienceHost",
  "Microsoft.MicrosoftEdge"   # legacy edge, a system app: windows may refuse, that is fine
)
# per user: -AllUsers fails with 0x80070002 on 22h2. then from the image, so a new user or a
# feature update does not bring it back
$prov = Get-AppxProvisionedPackage -Online
foreach ($a in $apps) {
  foreach ($pkg in Get-AppxPackage -Name $a) {
    try { Remove-AppxPackage -Package $pkg.PackageFullName -ErrorAction Stop; "removed $a" } catch { "could not remove $a (system app?)" }
  }
  $prov | Where-Object DisplayName -eq $a | ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName | Out-Null; "deprovisioned $a" }
}

"== onedrive (desktop, documents and pictures are local, the onedrive folder is empty)"
Stop-Process -Name OneDrive -Force -ErrorAction SilentlyContinue
Start-Process "$env:SystemRoot\SysWOW64\OneDriveSetup.exe" -ArgumentList "/uninstall" -Wait
Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive" DisableFileSyncNGSC 1
Remove-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -Name OneDrive -ErrorAction SilentlyContinue

"== startup: teams, steam, riot, edge off (same switch as task manager's disable)"
$approved = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run"
$off = [byte[]](3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
$run = Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
foreach ($name in $run.PSObject.Properties.Name | Where-Object { $_ -match "^(Teams|Steam|RiotClient|MicrosoftEdgeAutoLaunch)" }) {
  "startup off: $name"
  Set-Reg $approved $name $off Binary
}

"== edge: uninstall the browser for good (webview2 and edgeupdate stay)"
Get-Process msedge, MicrosoftEdgeUpdate -ErrorAction SilentlyContinue | Stop-Process -Force
# setup refuses (exit 93) unless the legacy edge exists, so a stub stands in for it while it runs.
# exit 19 is success. the eea flag and a region switch were tried first and were not enough
$legacy = "$env:SystemRoot\SystemApps\Microsoft.MicrosoftEdge_8wekyb3d8bbwe"
New-Item -ItemType Directory -Path $legacy -Force | Out-Null
$stub = -not (Test-Path "$legacy\MicrosoftEdge.exe")
if ($stub) { New-Item -ItemType File -Path "$legacy\MicrosoftEdge.exe" | Out-Null }
foreach ($setup in Get-ChildItem "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\*\Installer\setup.exe" -ErrorAction SilentlyContinue) {
  $p = Start-Process $setup.FullName -ArgumentList "--uninstall --system-level --force-uninstall" -Wait -PassThru
  "edge setup exit code $($p.ExitCode)"
}
Remove-Item "$env:LOCALAPPDATA\Microsoft\Edge" -Recurse -Force -ErrorAction SilentlyContinue
if (Test-Path "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe") { "EDGE IS STILL INSTALLED" } else { "edge removed" }
# never again: edgeupdate may not install or reinstall the browser
Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\EdgeUpdate" "Install{56EB18F8-B008-4CBD-B6D2-8C97FE7E9062}" 0
Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\EdgeUpdate" "Update{56EB18F8-B008-4CBD-B6D2-8C97FE7E9062}" 0
Set-Reg "HKLM:\SOFTWARE\Microsoft\EdgeUpdate" DoNotUpdateToEdgeWithChromium 1
Get-ChildItem "$env:PUBLIC\Desktop", "$env:USERPROFILE\Desktop", "$env:ProgramData\Microsoft\Windows\Start Menu\Programs",
  "$env:APPDATA\Microsoft\Windows\Start Menu\Programs", "$env:APPDATA\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar" `
  -Filter "Microsoft Edge*.lnk" -Recurse -ErrorAction SilentlyContinue | Remove-Item -Force
Get-ScheduledTask -TaskName "MicrosoftEdgeUpdateBrowserReplacementTask" -ErrorAction SilentlyContinue | Disable-ScheduledTask | Out-Null

"== copilot app: edgeupdate installs it on its own (edge-based, not a store app), so out and blocked too"
Get-Process copilotapp, copilotapphost -ErrorAction SilentlyContinue | Stop-Process -Force
New-Item -ItemType File -Path "$legacy\MicrosoftEdge.exe" -Force | Out-Null
foreach ($setup in Get-ChildItem "${env:ProgramFiles(x86)}\Microsoft\Copilot\Application\*\Installer\copilot_setup.exe" -ErrorAction SilentlyContinue) {
  $p = Start-Process $setup.FullName -ArgumentList "--uninstall --mscopilot --channel=stable --system-level --force-uninstall" -Wait -PassThru
  "copilot setup exit code $($p.ExitCode)"
}
if ($stub) { Remove-Item "$legacy\MicrosoftEdge.exe" -Force }
Remove-Item "${env:ProgramFiles(x86)}\Microsoft\Copilot", "$env:LOCALAPPDATA\Microsoft\Copilot" -Recurse -Force -ErrorAction SilentlyContinue
Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\EdgeUpdate" "Install{C50565E9-CCCF-44B4-BA15-5AC5C6569197}" 0
Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\EdgeUpdate" "Update{C50565E9-CCCF-44B4-BA15-5AC5C6569197}" 0
Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" ShowCopilotButton 0
# the office key (ctrl+alt+shift+win, and +w/t/o/l/x/... per office app) and win+c fall back to
# microsoft 365 / copilot in the browser when nothing handles their links: a do-nothing handler does
foreach ($proto in "ms-officeapp", "ms-copilot") {
  Set-Reg "HKCU:\Software\Classes\$proto" "(default)" "URL:$proto (disabled)" String
  Set-Reg "HKCU:\Software\Classes\$proto" "URL Protocol" "" String
  Set-Reg "HKCU:\Software\Classes\$proto\shell\open\command" "(default)" "rundll32" String
}

"== windows 11: stay on windows 10 22h2, no upgrade offers or end-of-support nags"
$wu = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
Set-Reg $wu TargetReleaseVersion 1
Set-Reg $wu ProductVersion "Windows 10" String
Set-Reg $wu TargetReleaseVersionInfo "22H2" String
Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Gwx" DisableGwx 1
Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\EOSNotify" DiscontinueEOS 1
Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement" ScoobeSystemSettingEnabled 0
foreach ($t in Get-ScheduledTask -TaskPath "\Microsoft\Windows\Setup\" -ErrorAction SilentlyContinue | Where-Object TaskName -match "EOSNotify") {
  "disable task $($t.TaskName)"; Disable-ScheduledTask -InputObject $t | Out-Null
}
Get-Package -Name "Windows PC Health Check" -ErrorAction SilentlyContinue | ForEach-Object { "remove pc health check"; Uninstall-Package -InputObject $_ -Force | Out-Null }

"== windows features nobody here uses (print to pdf stays)"
foreach ($f in "Internet-Explorer-Optional-amd64", "WindowsMediaPlayer", "WorkFolders-Client", "Printing-XPSServices-Features",
               "FaxServicesClientPackage", "MicrosoftWindowsPowerShellV2Root", "MicrosoftWindowsPowerShellV2") {
  if ((Get-WindowsOptionalFeature -Online -FeatureName $f -ErrorAction SilentlyContinue).State -eq "Enabled") {
    "disable feature $f"; Disable-WindowsOptionalFeature -Online -FeatureName $f -NoRestart | Out-Null
  }
}
foreach ($c in Get-WindowsCapability -Online | Where-Object { $_.State -eq "Installed" -and $_.Name -match "^(MathRecognizer|App.StepsRecorder|App.Support.QuickAssist|Hello.Face|Browser.InternetExplorer|Media.WindowsMediaPlayer|Microsoft.Windows.WordPad)" }) {
  "remove capability $($c.Name)"; Remove-WindowsCapability -Online -Name $c.Name | Out-Null
}

"== telemetry, ads, suggestions, web search, widgets, background apps"
Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" AllowTelemetry 1   # 1 is the floor on pro
Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" DoNotShowFeedbackNotifications 1
Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo" DisabledByGroupPolicy 1
Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" DisableWindowsConsumerFeatures 1
Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" DisableSoftLanding 1
Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" DisableTailoredExperiencesWithDiagnosticData 1
Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" AllowCortana 0
Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" DisableWebSearch 1
Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" ConnectedSearchUseWeb 0
Set-Reg "HKCU:\Software\Policies\Microsoft\Windows\Explorer" DisableSearchBoxSuggestions 1
Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Feeds" EnableFeeds 0         # news and interests
Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" PublishUserActivities 0     # activity history
Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" EnableActivityFeed 0
# store-style apps may not run in the background, except the new teams (notifications) and terminal
Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy" LetAppsRunInBackground 2
Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy" LetAppsRunInBackground_ForceAllowTheseApps @("MSTeams_8wekyb3d8bbwe", "Microsoft.WindowsTerminal_8wekyb3d8bbwe") MultiString
Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR" AllowGameDVR 0
Set-Reg "HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot" TurnOffWindowsCopilot 1
Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" TurnOffWindowsCopilot 1
Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" HideSCAMeetNow 1
Set-Reg "HKCU:\Software\Policies\Microsoft\Windows\Explorer" HidePeopleBar 1
Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization" DODownloadMode 0   # no p2p uploads
Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting" Disabled 1
Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" DisableCloudOptimizedContent 1
Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" DisableWindowsSpotlightFeatures 1
Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings\Windows.SystemToast.Suggested" Enabled 0
Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy" TailoredExperiencesWithDiagnosticDataEnabled 0
$cdm = "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
foreach ($n in "SilentInstalledAppsEnabled", "SystemPaneSuggestionsEnabled", "SoftLandingEnabled", "PreInstalledAppsEnabled",
               "OemPreInstalledAppsEnabled", "SubscribedContent-338388Enabled", "SubscribedContent-338389Enabled",
               "SubscribedContent-353694Enabled", "SubscribedContent-353696Enabled", "SubscribedContent-310093Enabled") {
  Set-Reg $cdm $n 0
}

"== services"
# disabled: telemetry, wap push, maps, retail demo, insider, xbox
# WSearch too: start still finds apps without the index, it just stops crawling the disk
foreach ($s in "DiagTrack", "dmwappushservice", "MapsBroker", "RetailDemo", "wisvc", "WSearch",
               "XblAuthManager", "XblGameSave", "XboxNetApiSvc", "XboxGipSvc", "Fax", "WMPNetworkSvc") {
  if (Get-Service $s -ErrorAction SilentlyContinue) { "disable $s"; Stop-Service $s -Force -ErrorAction SilentlyContinue; Set-Service $s -StartupType Disabled }
}
# manual: they start themselves when something needs them
# (SharedAccess stays: wsl2's nat networking can depend on it)
foreach ($s in "lfsvc", "PhoneSvc", "WbioSrvc", "TrkWks", "PcaSvc", "WerSvc") {
  if (Get-Service $s -ErrorAction SilentlyContinue) { "manual $s"; Set-Service $s -StartupType Manual }
}

"== telemetry scheduled tasks"
foreach ($t in "\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser",
               "\Microsoft\Windows\Application Experience\ProgramDataUpdater",
               "\Microsoft\Windows\Customer Experience Improvement Program\Consolidator",
               "\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip",
               "\Microsoft\Windows\Feedback\Siuf\DmClient",
               "\Microsoft\Windows\Feedback\Siuf\DmClientOnScenarioDownload",
               "\Microsoft\Windows\Windows Error Reporting\QueueReporting",
               "\Microsoft\Windows\Maps\MapsUpdateTask", "\Microsoft\Windows\Maps\MapsToastTask",
               "\Microsoft\XblGameSave\XblGameSaveTask") {
  $path = $t.Substring(0, $t.LastIndexOf("\") + 1); $name = $t.Substring($t.LastIndexOf("\") + 1)
  if (Get-ScheduledTask -TaskPath $path -TaskName $name -ErrorAction SilentlyContinue) { "disable task $t"; Disable-ScheduledTask -TaskPath $path -TaskName $name | Out-Null }
}

"== defender: keep it, but stop it scanning every file wyvern touches"
Add-MpPreference -ExclusionPath "C:\WSL"
foreach ($p in "wsl.exe", "wslhost.exe", "wslservice.exe", "vmmem", "vmwp.exe") { Add-MpPreference -ExclusionProcess $p }

"== leftovers after comparing with atlasos"
# fast startup on, for a quick cold boot after a shutdown (restarts are always full boots).
# it only needs the reduced hibernation file; the laptop itself never hibernates on ac
powercfg /hibernate on
powercfg /hibernate /type reduced
powercfg /change hibernate-timeout-ac 0
Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power" HiberbootEnabled 1
# no boot menu wait: the 30s timeout was left over from dual booting nixos
bcdedit /timeout 0 | Out-Null
"reserved storage: " + ((DISM /Online /Set-ReservedStorageState /State:Disabled) -match "completed|Error" | Select-Object -First 1)
Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\Maintenance" MaintenanceDisabled 1
Set-Reg "HKLM:\SOFTWARE\Microsoft\FTH" Enabled 0
# devices never power down on ac. wi-fi above all: windows switching it off drops tailscale and wyvern with it
powercfg /setacvalueindex SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0
powercfg /setacvalueindex SCHEME_CURRENT 19cbb8fa-5279-450e-9fac-8a3d5fedd0c1 12bbebe6-58d6-4636-95bb-3217ef867c1a 0
powercfg /setactive SCHEME_CURRENT
# Disable-NetAdapterPowerManagement does not stick on the intel wi-fi driver; PnPCapabilities=24 is the
# device manager checkbox itself ("allow the computer to turn off this device" unticked)
$class = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}"
foreach ($a in Get-NetAdapter -Physical) {
  $key = Get-ChildItem $class -ErrorAction SilentlyContinue | Where-Object { (Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue).NetCfgInstanceId -eq $a.InterfaceGuid }
  if ($key) { "no power saving: $($a.Name)"; Set-ItemProperty $key.PSPath -Name PnPCapabilities -Value 24 -Type DWord }
}
# windows update keeps its hands off drivers (the nvidia one especially)
Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" ExcludeWUDriversInQualityUpdate 1
Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" HideFileExt 0
# legacy name resolution nobody here needs: llmnr and netbios
Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient" EnableMulticast 0
Get-ChildItem "HKLM:\SYSTEM\CurrentControlSet\Services\NetBT\Parameters\Interfaces" | ForEach-Object { Set-ItemProperty $_.PSPath -Name NetbiosOptions -Value 2 }
# mouse acceleration off (games use raw input anyway, this is the desktop cursor)
Set-ItemProperty "HKCU:\Control Panel\Mouse" -Name MouseSpeed -Value "0"
Set-ItemProperty "HKCU:\Control Panel\Mouse" -Name MouseThreshold1 -Value "0"
Set-ItemProperty "HKCU:\Control Panel\Mouse" -Name MouseThreshold2 -Value "0"
# printing is gone, print to pdf with it
Remove-Printer -Name "Fax" -ErrorAction SilentlyContinue
# diagnostics, mail sync, connected devices, intel me helpers, netbios helper, smb file server,
# msi nahimic, printing. the per-user ones (OneSyncSvc, CDPUserSvc) are templates, set in the registry
foreach ($s in "DPS", "WdiServiceHost", "WdiSystemHost", "CDPSvc", "LMS", "jhi_service", "lmhosts", "LanmanServer", "NahimicService", "Spooler") {
  if (Get-Service $s -ErrorAction SilentlyContinue) { "disable $s"; Stop-Service $s -Force -ErrorAction SilentlyContinue; Set-Service $s -StartupType Disabled }
}
foreach ($s in "OneSyncSvc", "CDPUserSvc") { "disable $s (per user)"; Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\$s" Start 4 }
foreach ($s in "SstpSvc", "RasMan") { "manual $s"; Set-Service $s -StartupType Manual }
Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object { $_.TaskName -match "Nahimic|A-Volute" } | ForEach-Object { "disable task $($_.TaskName)"; Disable-ScheduledTask -InputObject $_ | Out-Null }

"== tray icon cache: the removed apps leave stale entries that slow explorer down at boot"
# christitustech/winutil#1642, henrypp/simplewall#1695. only forgets which tray icons were shown or hidden
Remove-ItemProperty "HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\CurrentVersion\TrayNotify" -Name IconStreams, PastIconsStream -ErrorAction SilentlyContinue

Snapshot "after (a reboot frees more)"
Stop-Transcript | Out-Null
