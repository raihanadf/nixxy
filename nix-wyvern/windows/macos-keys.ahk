; macos-style shortcuts on windows: alt sits where cmd sits on a mac keyboard, so alt does cmd's job.
; autohotkey v2, started at sign-in with admin rights (so it also reaches admin windows) by the
; "macos-keys" task that windows/macos-keys.ps1 registers. alt+space (search) is flow launcher's own.
#Requires AutoHotkey v2.0
#SingleInstance Force
; hook-based hotkeys only, so a key this script sends never fires one of its own hotkeys
#UseHook
SetTitleMatchMode 2
; releasing alt for a send taps this key to stop the menu bar; never ctrl, since ctrl+alt+shift+win
; is windows' "office key", which opens microsoft 365 / copilot in the browser
A_MenuMaskKey := "vkE8"

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
; no win key is ever sent: with alt+shift still held it adds up to the office key
!+3::Send "{PrintScreen}"   ; whole screen to the clipboard
!+4::Run "ms-screenclip:"   ; region snip overlay
!+5::Run "ms-screensketch:" ; snip & sketch

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

; in windows terminal the shell keeps alt as meta (fish, vim): fzf's alt+c (directories) and
; alt+v (variables), fish's alt+f (forward word). so only tabs and windows are mapped there; copy is
; copy-on-select (or ctrl+shift+c), paste is ctrl+shift+v or a right click
#HotIf WinActive("ahk_group terminal")
!t::Send "^+t"
!w::Send "^+w"
!n::Send "^+n"

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
