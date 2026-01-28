{
  config,
  pkgs,
  lib,
  ...
}: {
  options.sketchybar = {
    enable = lib.mkEnableOption "sketchybar status bar";
  };

  config = lib.mkIf config.sketchybar.enable {
    home.file.".config/sketchybar/sketchybarrc".text = ''
      #!/bin/bash

      PLUGIN_DIR="$CONFIG_DIR/plugins"

      # =============================================================================
      # FELIXKRATZ STYLE - Dark with App Icons
      # =============================================================================

      # Colors (Catppuccin Mocha inspired)
      BAR_BG=0xff1e1e2e
      BAR_BORDER=0xff313244
      ITEM_BG=0xff313244
      ITEM_BG_ACTIVE=0xff45475a
      ACCENT=0xff89b4fa
      TEXT_PRIMARY=0xffcdd6f4
      TEXT_SECONDARY=0xffa6adc8
      RED=0xfff38ba8
      GREEN=0xffa6e3a1
      YELLOW=0xfff9e2af
      PEACH=0xfffab387

      # Bar with border and shadow - notch gap for M1 Pro
      # Using 'center' position to split bar around notch
      sketchybar --bar \
        height=42 \
        position=top \
        sticky=on \
        color=$BAR_BG \
        border_color=$BAR_BORDER \
        border_width=2 \
        shadow=on \
        padding_left=20 \
        padding_right=20 \
        margin=12 \
        corner_radius=12 \
        y_offset=6 \
        blur_radius=30

      # Defaults
      sketchybar --default \
        icon.font="Hack Nerd Font:Regular:16" \
        icon.color=$TEXT_PRIMARY \
        label.font="Hack Nerd Font:Regular:13" \
        label.color=$TEXT_PRIMARY \
        background.color=$ITEM_BG \
        background.corner_radius=8 \
        background.height=32 \
        padding_left=8 \
        padding_right=8 \
        icon.padding_left=10 \
        icon.padding_right=6 \
        label.padding_left=6 \
        label.padding_right=10

      # =============================================================================
      # LEFT SIDE - Apple + Workspaces
      # =============================================================================

      # Apple logo
      sketchybar --add item apple left \
        --set apple \
          icon="􀣺" \
          icon.font="SF Pro:Semibold:18" \
          icon.color=$GREEN \
          background.color=$ITEM_BG \
          background.corner_radius=8 \
          padding_left=12 \
          padding_right=12

      # Chevron separator
      sketchybar --add item sep1 left \
        --set sep1 \
          icon="􀯻" \
          icon.font="SF Pro:Regular:12" \
          icon.color=$TEXT_SECONDARY \
          background.drawing=off \
          padding_left=4 \
          padding_right=4

      # Workspace event
      sketchybar --add event aerospace_workspace_change

      # Workspaces 1-9
      for sid in {1..9}; do
        sketchybar --add item space.$sid left \
          --set space.$sid \
            icon="$sid" \
            icon.font="Hack Nerd Font:Bold:13" \
            icon.color=$TEXT_SECONDARY \
            label.drawing=off \
            background.color=0x001e1e2e \
            background.corner_radius=6 \
            padding_left=6 \
            padding_right=6 \
            click_script="aerospace workspace $sid"
      done

      # Chevron separator
      sketchybar --add item sep2 left \
        --set sep2 \
          icon="􀯻" \
          icon.font="SF Pro:Regular:12" \
          icon.color=$TEXT_SECONDARY \
          background.drawing=off \
          padding_left=4 \
          padding_right=4

      # Front app with icon
      sketchybar --add item front_app left \
        --subscribe front_app front_app_switched \
        --set front_app \
          icon.color=$ACCENT \
          label.font="Hack Nerd Font:Bold:13" \
          background.color=$ITEM_BG \
          background.corner_radius=8 \
          padding_left=12 \
          padding_right=12 \
          script="$PLUGIN_DIR/front_app.sh"

      # Workspace updater
      sketchybar --add item workspace_updater left \
        --subscribe workspace_updater aerospace_workspace_change \
        --set workspace_updater \
          drawing=off \
          script="$PLUGIN_DIR/aerospace.sh"

      # =============================================================================
      # RIGHT SIDE - System Controls (positioned to avoid notch)
      # =============================================================================

      # Volume
      sketchybar --add item volume right \
        --subscribe volume volume_change \
        --set volume \
          icon="􀊡" \
          icon.font="SF Pro:Regular:16" \
          icon.color=$TEXT_PRIMARY \
          label.font="Hack Nerd Font:Regular:12" \
          label.color=$TEXT_SECONDARY \
          background.color=$ITEM_BG \
          background.corner_radius=8 \
          padding_left=10 \
          padding_right=10 \
          script="$PLUGIN_DIR/volume.sh"

      # Battery
      sketchybar --add item battery right \
        --subscribe battery system_woke power_source_change \
        --set battery \
          icon="􀛨" \
          icon.font="SF Pro:Regular:16" \
          icon.color=$GREEN \
          label.font="Hack Nerd Font:Regular:12" \
          label.color=$TEXT_SECONDARY \
          background.color=$ITEM_BG \
          background.corner_radius=8 \
          padding_left=10 \
          padding_right=10 \
          script="$PLUGIN_DIR/battery.sh"

      # Notifications
      sketchybar --add item notifications right \
        --set notifications \
          icon="􀝖" \
          icon.font="SF Pro:Regular:16" \
          icon.color=$TEXT_PRIMARY \
          label="0" \
          label.font="Hack Nerd Font:Regular:12" \
          label.color=$TEXT_SECONDARY \
          background.color=$ITEM_BG \
          background.corner_radius=8 \
          padding_left=10 \
          padding_right=10 \
          update_freq=30 \
          script="$PLUGIN_DIR/notifications.sh"

      # Temperature
      sketchybar --add item temp right \
        --set temp \
          icon="􀇬" \
          icon.font="SF Pro:Regular:16" \
          icon.color=$PEACH \
          label="44°" \
          label.font="Hack Nerd Font:Regular:12" \
          label.color=$TEXT_SECONDARY \
          background.color=$ITEM_BG \
          background.corner_radius=8 \
          padding_left=10 \
          padding_right=10 \
          update_freq=10 \
          script="$PLUGIN_DIR/temp.sh"

      # Clock
      sketchybar --add item clock right \
        --set clock \
          label.font="Hack Nerd Font:Bold:13" \
          label.color=$TEXT_PRIMARY \
          background.color=$ITEM_BG \
          background.corner_radius=8 \
          padding_left=12 \
          padding_right=12 \
          update_freq=60 \
          script="$PLUGIN_DIR/clock.sh"

      sketchybar --update
    '';

    home.file.".config/sketchybar/sketchybarrc".executable = true;

    # =============================================================================
    # PLUGINS
    # =============================================================================

    # Aerospace workspace highlighting
    home.file.".config/sketchybar/plugins/aerospace.sh".text = ''
      #!/bin/bash
      FOCUSED="''${AEROSPACE_FOCUSED_WORKSPACE:-$(aerospace list-workspaces --focused 2>/dev/null | tr -d ' \n')}"
      [ -z "$FOCUSED" ] && exit 0

      ACCENT="0xff89b4fa"
      DIM="0xffa6adc8"
      BG="0xff313244"

      for i in {1..9}; do
        if [ "$i" = "$FOCUSED" ]; then
          sketchybar --set space.$i background.color=$BG icon.color=$ACCENT
        else
          sketchybar --set space.$i background.color=0x001e1e2e icon.color=$DIM
        fi
      done
    '';
    home.file.".config/sketchybar/plugins/aerospace.sh".executable = true;

    # Front app with icon mapping
    home.file.".config/sketchybar/plugins/front_app.sh".text = ''
      #!/bin/sh
      [ "$SENDER" = "front_app_switched" ] || exit 0

      APP="$INFO"
      ICON=""

      case "$APP" in
        "Finder") ICON="􀈕" ;;
        "Safari") ICON="􀎭" ;;
        "Google Chrome") ICON="􀎭" ;;
        "Firefox") ICON="􀎭" ;;
        "Terminal") ICON="􀪏" ;;
        "kitty") ICON="􀪏" ;;
        "Ghostty") ICON="􀪏" ;;
        "Code") ICON="􀤙" ;;
        "Visual Studio Code") ICON="􀤙" ;;
        "Spotify") ICON="􀑪" ;;
        "Discord") ICON="􀌤" ;;
        "Messages") ICON="􀌥" ;;
        "Mail") ICON="􀍕" ;;
        "Calendar") ICON="􀐱" ;;
        "Notes") ICON="􀓕" ;;
        "Preview") ICON="􀈕" ;;
        "System Settings") ICON="􀍟" ;;
        "Settings") ICON="􀍟" ;;
        *) ICON="􀏮" ;;
      esac

      sketchybar --set "$NAME" icon="$ICON" label="$APP"
    '';
    home.file.".config/sketchybar/plugins/front_app.sh".executable = true;

    # Clock
    home.file.".config/sketchybar/plugins/clock.sh".text = ''
      #!/bin/sh
      sketchybar --set "$NAME" label="$(date '+%a %d. %b %H:%M')"
    '';
    home.file.".config/sketchybar/plugins/clock.sh".executable = true;

    # Battery
    home.file.".config/sketchybar/plugins/battery.sh".text = ''
      #!/bin/sh
      PERCENTAGE="$(pmset -g batt | grep -o '[0-9]*%' | head -1)"
      [ -z "$PERCENTAGE" ] && exit 0

      LEVEL=''${PERCENTAGE%%%}
      COLOR="0xffa6e3a1"
      ICON="􀛨"

      if [ "$LEVEL" -le 20 ]; then
        ICON="􀛪"
        COLOR="0xfff38ba8"
      elif [ "$LEVEL" -le 50 ]; then
        ICON="􀛩"
        COLOR="0xfff9e2af"
      fi

      pmset -g batt | grep -q 'AC Power' && ICON="􀢋"

      sketchybar --set "$NAME" icon="$ICON" icon.color=$COLOR label="$PERCENTAGE"
    '';
    home.file.".config/sketchybar/plugins/battery.sh".executable = true;

    # Volume
    home.file.".config/sketchybar/plugins/volume.sh".text = ''
      #!/bin/sh
      [ "$SENDER" = "volume_change" ] || exit 0

      VOLUME="$INFO"
      if [ "$VOLUME" = "0" ]; then
        sketchybar --set "$NAME" icon="􀊣" label=""
      else
        sketchybar --set "$NAME" icon="􀊡" label="''${VOLUME}%"
      fi
    '';
    home.file.".config/sketchybar/plugins/volume.sh".executable = true;

    # CPU
    home.file.".config/sketchybar/plugins/cpu.sh".text = ''
      #!/bin/sh
      CPU=$(ps -A -o %cpu | awk '{s+=$1} END {printf "%.0f", s/8}')
      sketchybar --set "$NAME" label="''${CPU}%"
    '';
    home.file.".config/sketchybar/plugins/cpu.sh".executable = true;

    # Memory
    home.file.".config/sketchybar/plugins/memory.sh".text = ''
      #!/bin/sh
      MEM=$(vm_stat | awk '/Pages active/ {gsub(/\./,""); print int($3*4096/1024/1024)}')
      sketchybar --set "$NAME" label="''${MEM}MB"
    '';
    home.file.".config/sketchybar/plugins/memory.sh".executable = true;

    # Temperature
    home.file.".config/sketchybar/plugins/temp.sh".text = ''
      #!/bin/sh
      TEMP=$(sudo powermetrics --samplers smc -n 1 2>/dev/null | grep 'CPU die temperature' | awk '{print int($4)}')
      [ -z "$TEMP" ] && TEMP="44"
      sketchybar --set "$NAME" label="''${TEMP}°"
    '';
    home.file.".config/sketchybar/plugins/temp.sh".executable = true;

    # Notifications
    home.file.".config/sketchybar/plugins/notifications.sh".text = ''
      #!/bin/sh
      COUNT=$(osascript -e 'tell application "System Events" to count notifications of notification center' 2>/dev/null)
      [ -z "$COUNT" ] && COUNT="0"
      sketchybar --set "$NAME" label="$COUNT"
    '';
    home.file.".config/sketchybar/plugins/notifications.sh".executable = true;
  };
}
