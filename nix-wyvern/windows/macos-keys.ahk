; macos-style shortcuts on windows: alt sits where cmd sits on a mac keyboard, so alt does cmd's job.
; autohotkey v2, started at sign-in with admin rights (so it also reaches admin windows) by the
; "macos-keys" task that windows/macos-keys.ps1 registers. alt+space (search) is flow launcher's own.
#Requires AutoHotkey v2.0
#SingleInstance Force
; hook-based hotkeys only, so a key this script sends never fires one of its own hotkeys
#UseHook
SetTitleMatchMode 2

; games read raw input and riot vanguard watches injected keys: hands off while they are in front
GroupAdd "games", "ahk_exe VALORANT-Win64-Shipping.exe"
GroupAdd "games", "ahk_exe cs2.exe"
GroupAdd "terminal", "ahk_exe WindowsTerminal.exe"

#HotIf !WinActive("ahk_group games")

; window and app
!q::WinClose "A"            ; quit (the app's own close, so it can still ask to save)
!h::WinMinimize "A"
!m::WinMinimize "A"

; screenshots, like cmd+shift+3/4/5
!+3::Send "{PrintScreen}"   ; whole screen to the clipboard (and the snip notification)
!+4::Send "#+s"             ; region
!+5::Run "ms-screenclip:"   ; the snipping overlay

; text navigation, like cmd+arrows and cmd+backspace
!Left::Send "{Home}"
!Right::Send "{End}"
!+Left::Send "+{Home}"
!+Right::Send "+{End}"
!Up::Send "^{Home}"
!Down::Send "^{End}"
!+Up::Send "^+{Home}"
!+Down::Send "^+{End}"
!Backspace::Send "+{Home}{Delete}"

; back and forward, like cmd+[ and cmd+]
![::Send "!{Left}"
!]::Send "!{Right}"

; in windows terminal the shell keeps alt as meta (fish, vim), so only the cmd keys a mac
; terminal would take are mapped there; copy and paste go to terminal's ctrl+shift ones
#HotIf WinActive("ahk_group terminal")
!c::Send "^+c"
!v::Send "^+v"
!t::Send "^+t"
!w::Send "^+w"
!n::Send "^+n"
!f::Send "^+f"

; everywhere else alt+letter is cmd+letter
#HotIf !WinActive("ahk_group games") && !WinActive("ahk_group terminal")
!c::Send "^c"
!v::Send "^v"
!x::Send "^x"
!a::Send "^a"
!z::Send "^z"
!+z::Send "^y"
!s::Send "^s"
!+s::Send "^+s"
!f::Send "^f"
!r::Send "^r"
!p::Send "^p"
!t::Send "^t"
!+t::Send "^+t"
!w::Send "^w"
!n::Send "^n"
!+n::Send "^+n"
!l::Send "^l"
!o::Send "^o"
!b::Send "^b"
!i::Send "^i"
!u::Send "^u"
!k::Send "^k"
!d::Send "^d"
!y::Send "^y"
!=::Send "^{=}"
!-::Send "^{-}"
!0::Send "^0"
!,::Send "^,"

#HotIf
