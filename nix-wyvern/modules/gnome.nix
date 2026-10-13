# GNOME look and feel, all declarative.
#
# layout has a macos feel but stays gnome underneath (top bar, overview,
# quick settings, workspaces are stock):
# - dock fixed at the bottom, one dot per running app, click to focus
#   (dash-to-dock); tray icons in the top bar (appindicator)
# - super+space opens overview search like spotlight (normally the input
#   source switcher, so that binding is cleared)
# - window buttons on the left, new windows centered, super+q closes, super+h
#   hides (gnome default), shift+super+3/4/5 screenshots
# - trackpad: tap to click, two-finger right click, natural scrolling
#
# look is a pastel rice built around monet's "impression, sunrise": the
# rose pine moon palette (lilac, foam, peach on deep indigo) recolors
# libadwaita/gtk3 through gtk.css and the shell through a small user theme
# layered on gnome's own dark stylesheet. frosted panel/dock (blur-my-shell),
# rounded corners on non-libadwaita windows, colloid icons, rose pine cursor.
#
# no sleep on AC: wyvern serves honcho around the clock.
{
  pkgs,
  lib,
  ...
}: let
  wallpaper = pkgs.fetchurl {
    name = "monet-impression-sunrise.jpg";
    url = "https://w.wallhaven.cc/full/83/wallhaven-83vw51.jpg";
    hash = "sha256-ktwDcAtwtpLif5KAWgg/Y187PAf/YtGcUEWr8VO+EY0=";
  };

  icons = pkgs.colloid-icon-theme.override {
    schemeVariants = ["catppuccin"];
    colorVariants = ["purple"];
  };

  # rose pine moon
  base = "#232136";
  surface = "#2a273f";
  overlay = "#393552";
  muted = "#6e6a86";
  text = "#e0def4";
  love = "#eb6f92";
  gold = "#f6c177";
  rose = "#ea9a97";
  pine = "#3e8fb0";
  foam = "#9ccfd8";
  iris = "#c4a7e7";
  # st (the shell's css engine) has no alpha(); translucent shell colors are
  # spelled out as rgba of the same palette entries
  irisA = a: "rgba(196, 167, 231, ${a})";
  surfaceA = a: "rgba(42, 39, 63, ${a})";
  overlayA = a: "rgba(57, 53, 82, ${a})";

  gtk4Css = ''
    @define-color accent_color ${iris};
    @define-color accent_bg_color ${iris};
    @define-color accent_fg_color ${base};
    @define-color destructive_color ${love};
    @define-color destructive_bg_color ${love};
    @define-color destructive_fg_color ${base};
    @define-color success_color ${foam};
    @define-color success_bg_color ${pine};
    @define-color warning_color ${gold};
    @define-color warning_bg_color ${gold};
    @define-color warning_fg_color ${base};
    @define-color error_color ${love};
    @define-color error_bg_color ${love};
    @define-color error_fg_color ${base};
    @define-color window_bg_color ${base};
    @define-color window_fg_color ${text};
    @define-color view_bg_color ${surface};
    @define-color view_fg_color ${text};
    @define-color headerbar_bg_color ${surface};
    @define-color headerbar_fg_color ${text};
    @define-color headerbar_backdrop_color ${base};
    @define-color sidebar_bg_color ${surface};
    @define-color sidebar_fg_color ${text};
    @define-color sidebar_backdrop_color ${base};
    @define-color secondary_sidebar_bg_color ${base};
    @define-color secondary_sidebar_fg_color ${text};
    @define-color card_bg_color alpha(${overlay}, 0.6);
    @define-color card_fg_color ${text};
    @define-color dialog_bg_color ${surface};
    @define-color dialog_fg_color ${text};
    @define-color popover_bg_color ${surface};
    @define-color popover_fg_color ${text};
    @define-color thumbnail_bg_color ${overlay};
    @define-color thumbnail_fg_color ${text};

    :root {
      --accent-bg-color: ${iris};
      --accent-fg-color: ${base};
      --accent-color: ${iris};
      --window-bg-color: ${base};
      --window-fg-color: ${text};
      --view-bg-color: ${surface};
      --view-fg-color: ${text};
      --headerbar-bg-color: ${surface};
      --headerbar-fg-color: ${text};
      --headerbar-backdrop-color: ${base};
      --sidebar-bg-color: ${surface};
      --sidebar-fg-color: ${text};
      --sidebar-backdrop-color: ${base};
      --card-bg-color: alpha(${overlay}, 0.6);
      --card-fg-color: ${text};
      --dialog-bg-color: ${surface};
      --dialog-fg-color: ${text};
      --popover-bg-color: ${surface};
      --popover-fg-color: ${text};
      --destructive-bg-color: ${love};
      --success-bg-color: ${pine};
      --warning-bg-color: ${gold};
      --error-bg-color: ${love};
    }
  '';

  gtk3Css = ''
    @define-color theme_bg_color ${base};
    @define-color theme_fg_color ${text};
    @define-color theme_base_color ${surface};
    @define-color theme_text_color ${text};
    @define-color theme_selected_bg_color ${iris};
    @define-color theme_selected_fg_color ${base};
    @define-color insensitive_bg_color ${base};
    @define-color insensitive_fg_color ${muted};
    @define-color borders ${overlay};
    @define-color accent_color ${iris};
    @define-color accent_bg_color ${iris};
    @define-color accent_fg_color ${base};
    @define-color window_bg_color ${base};
    @define-color window_fg_color ${text};
    @define-color view_bg_color ${surface};
    @define-color view_fg_color ${text};
    @define-color headerbar_bg_color ${surface};
    @define-color headerbar_fg_color ${text};
    @define-color popover_bg_color ${surface};
    @define-color popover_fg_color ${text};
  '';

  shellCss = ''
    @import url("resource:///org/gnome/shell/theme/gnome-shell-dark.css");

    /* top bar: frosted strip (blur-my-shell) with pill-shaped buttons */
    #panel { background-color: transparent; }
    #panel .panel-button {
      color: ${text};
      border-radius: 99px;
      margin: 3px 2px;
    }
    #panel .panel-button:hover,
    #panel .panel-button:active,
    #panel .panel-button:checked {
      background-color: ${irisA "0.22"};
      color: ${text};
    }
    #panel .clock { font-weight: 700; }
    .workspace-dot { background-color: ${iris}; }

    /* menus, quick settings, calendar, notifications */
    .popup-menu-content,
    .quick-settings,
    .candidate-popup-content {
      background-color: ${surfaceA "0.96"};
      color: ${text};
      border: 1px solid ${irisA "0.25"};
      border-radius: 20px;
    }
    .popup-menu-item:hover,
    .popup-menu-item:focus { background-color: ${irisA "0.18"}; }
    .quick-toggle,
    .quick-menu-toggle .quick-toggle,
    .quick-slider .slider-bin,
    .message,
    .events-button,
    .world-clocks-button,
    .weather-button {
      background-color: ${overlayA "0.7"};
      color: ${text};
    }
    .quick-toggle:checked,
    .quick-menu-toggle .quick-toggle:checked,
    .quick-menu-toggle .quick-toggle-arrow:checked {
      background-color: ${iris};
      color: ${base};
    }
    .slider { color: ${iris}; -barlevel-active-background-color: ${iris}; }
    .calendar-today, .calendar-today:hover {
      background-color: ${rose};
      color: ${base};
    }
    .notification-banner,
    .osd-window,
    .switcher-list,
    .modal-dialog {
      background-color: ${surfaceA "0.96"};
      color: ${text};
      border: 1px solid ${irisA "0.25"};
    }
    .switcher-list .item-box:selected,
    .switcher-list .item-box:focus { background-color: ${irisA "0.25"}; }

    /* overview search, the spotlight */
    .search-entry {
      background-color: ${overlayA "0.85"};
      color: ${text};
      border-radius: 99px;
      border: 1px solid ${irisA "0.35"};
    }
    .search-entry:focus { border-color: ${iris}; }

    /* dock */
    #dashtodockContainer .dash-background {
      background-color: ${surfaceA "0.55"};
      border: 1px solid ${irisA "0.2"};
      border-radius: 22px;
    }
    #dashtodockContainer .app-well-app-running-dot,
    #dashtodockContainer .app-grid-running-dot { background-color: ${foam}; }
  '';

  shellTheme = pkgs.writeTextDir "share/themes/Monet/gnome-shell/gnome-shell.css" shellCss;
in {
  home.packages = with pkgs; [
    gnomeExtensions.dash-to-dock
    gnomeExtensions.appindicator
    gnomeExtensions.blur-my-shell
    gnomeExtensions.user-themes
    gnomeExtensions.rounded-window-corners-reborn
    icons
    rose-pine-cursor
    nerd-fonts.jetbrains-mono
  ];

  xdg.dataFile."themes/Monet".source = "${shellTheme}/share/themes/Monet";
  xdg.configFile."gtk-4.0/gtk.css".text = gtk4Css;
  xdg.configFile."gtk-3.0/gtk.css".text = gtk3Css;

  # gnome 50 opens the overview at login and ignores both dash-to-dock's
  # disable-overview-on-startup and just-perfection's startup-status; close
  # it once the shell is up so login lands on the desktop like macos.
  xdg.configFile."autostart/desktop-at-login.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=Desktop at login
    Exec=sh -c "sleep 3; ${pkgs.glib}/bin/gdbus call --session --dest org.gnome.Shell --object-path /org/gnome/Shell --method org.freedesktop.DBus.Properties.Set org.gnome.Shell OverviewActive '<false>'"
    OnlyShowIn=GNOME;
    NoDisplay=true
  '';

  dconf.settings = {
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
      accent-color = "purple";
      icon-theme = "Colloid-Purple-Catppuccin-Dark";
      cursor-theme = "BreezeX-RosePine-Linux";
      cursor-size = 24;
      monospace-font-name = "JetBrainsMono Nerd Font 11";
      clock-show-weekday = true;
      show-battery-percentage = true;
      enable-hot-corners = false;
    };
    "org/gnome/desktop/background" = {
      picture-uri = "file://${wallpaper}";
      picture-uri-dark = "file://${wallpaper}";
      picture-options = "zoom";
    };
    "org/gnome/desktop/screensaver".picture-uri = "file://${wallpaper}";
    "org/gnome/desktop/peripherals/touchpad" = {
      natural-scroll = true;
      tap-to-click = true;
      click-method = "fingers";
    };
    "org/gnome/mutter".center-new-windows = true;
    "org/gnome/settings-daemon/plugins/power".sleep-inactive-ac-type = "nothing";
    "org/gnome/shell" = {
      favorite-apps = ["kitty.desktop" "org.gnome.Nautilus.desktop" "firefox.desktop"];
      disable-user-extensions = false;
      enabled-extensions = with pkgs.gnomeExtensions; [
        dash-to-dock.extensionUuid
        appindicator.extensionUuid
        blur-my-shell.extensionUuid
        user-themes.extensionUuid
        rounded-window-corners-reborn.extensionUuid
      ];
    };
    "org/gnome/shell/extensions/user-theme".name = "Monet";
    "org/gnome/shell/extensions/dash-to-dock" = {
      dock-position = "BOTTOM";
      dock-fixed = true;
      extend-height = false;
      dash-max-icon-size = 48;
      custom-theme-shrink = true;
      apply-custom-theme = false;
      transparency-mode = "DEFAULT";
      show-trash = false;
      show-mounts = false;
      running-indicator-style = "DOT";
      click-action = "focus-or-appspread";
      disable-overview-on-startup = true;
      hot-keys = false;
    };
    "org/gnome/desktop/wm/preferences".button-layout = "close,minimize,maximize:";
    "org/gnome/desktop/wm/keybindings" = {
      close = ["<Super>q" "<Alt>F4"];
      switch-input-source = lib.hm.gvariant.mkEmptyArray lib.hm.gvariant.type.string;
      switch-input-source-backward = lib.hm.gvariant.mkEmptyArray lib.hm.gvariant.type.string;
    };
    "org/gnome/shell/keybindings" = {
      toggle-overview = ["<Super>space"];
      screenshot = ["<Shift>Print" "<Shift><Super>3"];
      show-screenshot-ui = ["Print" "<Shift><Super>4" "<Shift><Super>5"];
      screenshot-window = ["<Alt>Print"];
    };
  };
}
