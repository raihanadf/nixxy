{
  config,
  pkgs,
  lib,
  ...
}: {
  options.aerospace = {
    enable = lib.mkEnableOption "aerospace window manager";
  };

  config = lib.mkIf config.aerospace.enable {
    home.file.".aerospace.toml".text = ''
      # Notify Sketchybar about workspace change - async to avoid blocking
      # exec-on-workspace-change = ['/bin/bash', '-c', '(sketchybar --trigger aerospace_workspace_change FOCUSED_WORKSPACE=$AEROSPACE_FOCUSED_WORKSPACE &)']

      # Start Sketchybar and JankyBorders when AeroSpace starts
      after-startup-command = [
        # 'exec-and-forget sketchybar',
        # 'exec-and-forget borders blacklist="Screen Studio"'
      ]

      # Config version for compatibility and deprecations
      config-version = 2

      # Start AeroSpace at login
      start-at-login = false

      # Normalizations - disabled to prevent unwanted stacking
      enable-normalization-flatten-containers = false
      enable-normalization-opposite-orientation-for-nested-containers = false

      # Layouts
      accordion-padding = 30
      default-root-container-layout = 'tiles'
      default-root-container-orientation = 'auto'

      # Mouse follows focus
      on-focused-monitor-changed = ['move-mouse monitor-lazy-center']

      # Unhide macOS hidden apps
      automatically-unhide-macos-hidden-apps = true

      # Persistent workspaces
      persistent-workspaces = ["1", "2", "3", "4", "5", "6", "7", "8", "9"]

      # Key mapping
      [key-mapping]
          preset = 'qwerty'

      [gaps]
          inner.horizontal = 10
          inner.vertical =   10
          outer.left =       10
          outer.bottom =     5
          outer.top =        5
          outer.right =      10

      # Main binding mode
      [mode.main.binding]
          # Terminal
          alt-shift-enter = 'exec-and-forget open -na ghostty'

          # Layouts
          alt-slash = 'layout tiles horizontal vertical'
          alt-comma = 'layout accordion horizontal vertical'

          # Focus
          alt-h = 'focus left'
          alt-j = 'focus down'
          alt-k = 'focus up'
          alt-l = 'focus right'

          # Move
          alt-shift-h = 'move left'
          alt-shift-j = 'move down'
          alt-shift-k = 'move up'
          alt-shift-l = 'move right'

          # Resize
          alt-minus = 'resize smart -50'
          alt-equal = 'resize smart +50'

          # Workspace
          alt-1 = 'workspace 1'
          alt-2 = 'workspace 2'
          alt-3 = 'workspace 3'
          alt-4 = 'workspace 4'
          alt-5 = 'workspace 5'
          alt-6 = 'workspace 6'
          alt-7 = 'workspace 7'
          alt-8 = 'workspace 8'
          alt-9 = 'workspace 9'

          # Move node to workspace
          alt-shift-1 = 'move-node-to-workspace 1'
          alt-shift-2 = 'move-node-to-workspace 2'
          alt-shift-3 = 'move-node-to-workspace 3'
          alt-shift-4 = 'move-node-to-workspace 4'
          alt-shift-5 = 'move-node-to-workspace 5'
          alt-shift-6 = 'move-node-to-workspace 6'
          alt-shift-7 = 'move-node-to-workspace 7'
          alt-shift-8 = 'move-node-to-workspace 8'
          alt-shift-9 = 'move-node-to-workspace 9'

          # Workspace Back and Forth
          alt-tab = 'workspace-back-and-forth'
          alt-shift-tab = 'move-workspace-to-monitor --wrap-around next'

          # Service Mode
          alt-shift-semicolon = 'mode service'

      # Service binding mode
      [mode.service.binding]
          esc = ['reload-config', 'mode main']
          r = ['flatten-workspace-tree', 'mode main']
          f = ['layout floating tiling', 'mode main']
          backspace = ['close-all-windows-but-current', 'mode main']
          # q = ['exec-and-forget killall sketchybar', 'exec-and-forget killall borders', 'exec-and-forget pkill -9 AeroSpace']
          q = ['exec-and-forget killall borders', 'exec-and-forget pkill -9 AeroSpace']

          alt-shift-h = ['join-with left', 'mode main']
          alt-shift-j = ['join-with down', 'mode main']
          alt-shift-k = ['join-with up', 'mode main']
          alt-shift-l = ['join-with right', 'mode main']

      # Window Rules
      # TablePlus - floating in workspace 6 (MUST be before generic layout tiles rule)
      [[on-window-detected]]
      if.app-id = 'com.tinyapp.TablePlus'
      run = ['move-node-to-workspace 6', 'layout floating']

      # TablePlus SetApp version
      [[on-window-detected]]
      if.app-id = 'com.tinyapp.TablePlus-setapp'
      run = ['move-node-to-workspace 6', 'layout floating']

      # Force all windows to use tiles layout by default
      [[on-window-detected]]
      run = ['layout tiles']

      # Ignore confirmo app completely - keep it floating on current workspace
      [[on-window-detected]]
      if.app-id = 'com.confirmo.app'
      run = ['layout floating']

      [[on-window-detected]]
      if.app-id = 'com.mitchellh.ghostty'
      run = ['move-node-to-workspace 1']

      [[on-window-detected]]
      if.app-id = 'org.mozilla.firefox'
      run = ['move-node-to-workspace 3']

      # Microsoft Teams - move to workspace 9 and make floating
      [[on-window-detected]]
      if.app-id = 'com.microsoft.teams2'
      run = ['move-node-to-workspace 9', 'layout floating']

      # Ignore Microsoft Teams call windows - keep them unmanaged/floating
      [[on-window-detected]]
      if.app-id = 'com.microsoft.teams2'
      if.window-title-regex-substring = 'call|meeting|Teams Call'
      run = ['layout floating']
    '';
  };
}
