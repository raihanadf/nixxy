# GNOME look and feel, all declarative.
#
# layout has a macos feel but stays gnome underneath (top bar, overview,
# quick settings, workspaces are stock):
# - dock fixed at the bottom, one dot per running app, click to focus
#   (dash-to-dock); tray icons in the top bar (appindicator)
# - alt is the cmd key: alt+space opens vicinae, a spotlight-style launcher
#   centered on screen (its companion gnome extension gives it clipboard and
#   window access), alt+q closes, alt+h/alt+m minimize, alt+shift+3/4/5
#   screenshots, alt+ctrl+f fullscreen, alt+ctrl+q locks, alt+tab / alt+`
#   switch apps and windows (gnome default). alt+space normally opens the
#   window menu, so that binding is cleared. copy/paste inside apps stays on
#   ctrl. the overview stays on super.
# - window buttons on the left as macos traffic lights, new windows centered
# - trackpad: tap to click, two-finger right click, natural scrolling
#
# look is neutral like macos dark mode: graphite greys with the system blue
# accent recolor libadwaita/gtk3 through gtk.css and the shell through a
# small user theme layered on gnome's own dark stylesheet. frosted top bar
# (blur-my-shell); the dock keeps gnome's own dash styling so it looks like
# the overview dash. rounded corners on non-libadwaita windows, caffeine in
# the top bar to keep the laptop awake on demand,
# whitesur icons (top bar status icons stay gnome's own adwaita symbolic:
# whitesur's are thin, coloured and incomplete there), capitaine cursor,
# monet's "impression, sunrise" behind it. qt apps run through xwayland so
# mutter frames them with the same traffic lights, and borrow gtk3 colors.
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

  # whitesur-dark without its status icons, falling back to adwaita for those
  icons = pkgs.runCommand "whitesur-wyvern-icons" {nativeBuildInputs = [pkgs.gtk3];} ''
    mkdir -p $out/share/icons
    cp -rL ${pkgs.whitesur-icon-theme}/share/icons/WhiteSur-dark $out/share/icons/WhiteSur-Wyvern
    chmod -R u+w $out/share/icons/WhiteSur-Wyvern
    cd $out/share/icons/WhiteSur-Wyvern
    rm -rf status status@2x icon-theme.cache
    sed -i -e 's/^Name=.*/Name=WhiteSur-Wyvern/' -e 's/^Inherits=.*/Inherits=Adwaita,hicolor/' index.theme
    gtk-update-icon-cache -f -t .
  '';

  # macos dark mode
  bg = "#1e1e1e";
  surface = "#2a2a2a";
  raised = "#3a3a3a";
  muted = "#98989d";
  text = "#ececec";
  accent = "#0a84ff";
  red = "#ff453a";
  yellow = "#ffd60a";
  green = "#32d74b";
  # traffic lights, the window-control shades rather than the system ones
  trafficClose = "#ff5f57";
  trafficMinimize = "#febc2e";
  trafficMaximize = "#28c840";
  # st (the shell's css engine) has no alpha(); translucent shell colors are
  # spelled out as rgba of the same palette entries
  accentA = a: "rgba(10, 132, 255, ${a})";
  surfaceA = a: "rgba(42, 42, 42, ${a})";
  raisedA = a: "rgba(58, 58, 58, ${a})";
  whiteA = a: "rgba(255, 255, 255, ${a})";

  gtk4Css = ''
    @define-color accent_color ${accent};
    @define-color accent_bg_color ${accent};
    @define-color accent_fg_color #ffffff;
    @define-color destructive_color ${red};
    @define-color destructive_bg_color ${red};
    @define-color destructive_fg_color #ffffff;
    @define-color success_color ${green};
    @define-color success_bg_color ${green};
    @define-color warning_color ${yellow};
    @define-color warning_bg_color ${yellow};
    @define-color warning_fg_color ${bg};
    @define-color error_color ${red};
    @define-color error_bg_color ${red};
    @define-color error_fg_color #ffffff;
    @define-color window_bg_color ${bg};
    @define-color window_fg_color ${text};
    @define-color view_bg_color ${bg};
    @define-color view_fg_color ${text};
    @define-color headerbar_bg_color ${surface};
    @define-color headerbar_fg_color ${text};
    @define-color headerbar_backdrop_color ${bg};
    @define-color sidebar_bg_color ${surface};
    @define-color sidebar_fg_color ${text};
    @define-color sidebar_backdrop_color ${bg};
    @define-color secondary_sidebar_bg_color ${bg};
    @define-color secondary_sidebar_fg_color ${text};
    @define-color card_bg_color alpha(${raised}, 0.6);
    @define-color card_fg_color ${text};
    @define-color dialog_bg_color ${surface};
    @define-color dialog_fg_color ${text};
    @define-color popover_bg_color ${surface};
    @define-color popover_fg_color ${text};
    @define-color thumbnail_bg_color ${raised};
    @define-color thumbnail_fg_color ${text};

    :root {
      --accent-bg-color: ${accent};
      --accent-fg-color: #ffffff;
      --accent-color: ${accent};
      --window-bg-color: ${bg};
      --window-fg-color: ${text};
      --view-bg-color: ${bg};
      --view-fg-color: ${text};
      --headerbar-bg-color: ${surface};
      --headerbar-fg-color: ${text};
      --headerbar-backdrop-color: ${bg};
      --sidebar-bg-color: ${surface};
      --sidebar-fg-color: ${text};
      --sidebar-backdrop-color: ${bg};
      --card-bg-color: alpha(${raised}, 0.6);
      --card-fg-color: ${text};
      --dialog-bg-color: ${surface};
      --dialog-fg-color: ${text};
      --popover-bg-color: ${surface};
      --popover-fg-color: ${text};
      --destructive-bg-color: ${red};
      --success-bg-color: ${green};
      --warning-bg-color: ${yellow};
      --error-bg-color: ${red};
    }

    /* traffic lights: red/yellow/green dots, glyphs only on hover, grey
       when the window is in the background */
    windowcontrols { border-spacing: 8px; }
    windowcontrols > button {
      min-width: 14px;
      min-height: 14px;
      padding: 0;
      margin: 0;
      background: none;
      box-shadow: none;
    }
    windowcontrols > button > image {
      min-width: 14px;
      min-height: 14px;
      padding: 0;
      border-radius: 99px;
      -gtk-icon-size: 10px;
      color: transparent;
      background-color: ${raised};
      box-shadow: inset 0 0 0 1px rgba(0, 0, 0, 0.18);
    }
    windowcontrols > button.close > image { background-color: ${trafficClose}; }
    windowcontrols > button.minimize > image { background-color: ${trafficMinimize}; }
    windowcontrols > button.maximize > image { background-color: ${trafficMaximize}; }
    windowcontrols > button:backdrop:not(:hover) > image { background-color: ${raised}; }
    windowcontrols:hover > button > image { color: rgba(0, 0, 0, 0.6); }
    windowcontrols > button:active > image { filter: brightness(0.85); }
  '';

  gtk3Css = ''
    @define-color theme_bg_color ${bg};
    @define-color theme_fg_color ${text};
    @define-color theme_base_color ${bg};
    @define-color theme_text_color ${text};
    @define-color theme_selected_bg_color ${accent};
    @define-color theme_selected_fg_color #ffffff;
    @define-color insensitive_bg_color ${bg};
    @define-color insensitive_fg_color ${muted};
    @define-color borders ${raised};
    @define-color accent_color ${accent};
    @define-color accent_bg_color ${accent};
    @define-color accent_fg_color #ffffff;
    @define-color window_bg_color ${bg};
    @define-color window_fg_color ${text};
    @define-color view_bg_color ${bg};
    @define-color view_fg_color ${text};
    @define-color headerbar_bg_color ${surface};
    @define-color headerbar_fg_color ${text};
    @define-color popover_bg_color ${surface};
    @define-color popover_fg_color ${text};

    /* traffic lights, same as gtk4 */
    headerbar button.titlebutton,
    .titlebar button.titlebutton {
      min-width: 14px;
      min-height: 14px;
      padding: 0;
      margin: 0 4px;
      border: none;
      border-radius: 99px;
      background-image: none;
      box-shadow: inset 0 0 0 1px rgba(0, 0, 0, 0.18);
      color: transparent;
      -gtk-icon-shadow: none;
    }
    button.titlebutton.close { background-color: ${trafficClose}; }
    button.titlebutton.minimize { background-color: ${trafficMinimize}; }
    button.titlebutton.maximize { background-color: ${trafficMaximize}; }
    button.titlebutton:backdrop { background-color: ${raised}; }
    headerbar:hover button.titlebutton,
    .titlebar:hover button.titlebutton { color: rgba(0, 0, 0, 0.6); }
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
      background-color: ${whiteA "0.14"};
      color: ${text};
    }
    #panel .clock { font-weight: 700; }
    .workspace-dot { background-color: ${text}; }

    /* menus, quick settings, calendar, notifications */
    .popup-menu-content,
    .quick-settings,
    .candidate-popup-content {
      background-color: ${surfaceA "0.96"};
      color: ${text};
      border: 1px solid ${whiteA "0.1"};
      border-radius: 20px;
    }
    .popup-menu-item:hover,
    .popup-menu-item:focus { background-color: ${whiteA "0.1"}; }
    .quick-toggle,
    .quick-menu-toggle .quick-toggle,
    .quick-slider .slider-bin,
    .message,
    .events-button,
    .world-clocks-button,
    .weather-button {
      background-color: ${raisedA "0.7"};
      color: ${text};
    }
    .quick-toggle:checked,
    .quick-menu-toggle .quick-toggle:checked,
    .quick-menu-toggle .quick-toggle-arrow:checked {
      background-color: ${accent};
      color: #ffffff;
    }
    .slider { color: ${accent}; -barlevel-active-background-color: ${accent}; }
    .calendar-today, .calendar-today:hover {
      background-color: ${accent};
      color: #ffffff;
    }
    .notification-banner,
    .osd-window,
    .switcher-list,
    .modal-dialog {
      background-color: ${surfaceA "0.96"};
      color: ${text};
      border: 1px solid ${whiteA "0.1"};
    }
    .switcher-list .item-box:selected,
    .switcher-list .item-box:focus { background-color: ${accentA "0.35"}; }

    /* overview search */
    .search-entry {
      background-color: ${raisedA "0.85"};
      color: ${text};
      border-radius: 99px;
      border: 1px solid ${whiteA "0.12"};
    }
    .search-entry:focus { border-color: ${accent}; }
  '';

  shellTheme = pkgs.writeTextDir "share/themes/Wyvern/gnome-shell/gnome-shell.css" shellCss;
in {
  home.packages = with pkgs; [
    gnomeExtensions.dash-to-dock
    gnomeExtensions.appindicator
    gnomeExtensions.blur-my-shell
    gnomeExtensions.user-themes
    gnomeExtensions.rounded-window-corners-reborn
    gnomeExtensions.vicinae
    gnomeExtensions.caffeine
    icons
    nerd-fonts.jetbrains-mono
    # kitty's font (dotfiles kitty.conf: CaskaydiaCove NF)
    nerd-fonts.caskaydia-cove
  ];

  # spotlight: gnome has no layer shell, so vicinae runs as a normal centered
  # window; daemon starts with the session so alt+space is instant. compact
  # mode shows just the search bar until you type, like macos spotlight.
  programs.vicinae = {
    enable = true;
    systemd.enable = true;
    settings = {
      launcher_window = {
        layer_shell.enabled = false;
        compact_mode.enabled = true;
        rounding = 16;
      };
      theme = {
        dark.name = "vicinae-dark";
        light.name = "vicinae-dark";
      };
    };
  };

  # cursor everywhere: gnome (dconf below), plus XCURSOR_* and ~/.icons/default
  # so xwayland apps (kitty, steam, minecraft) get the same theme and size.
  # x11.enable would append to ~/.Xresources, which the dotfiles own.
  home.pointerCursor = {
    name = "capitaine-cursors";
    package = pkgs.capitaine-cursors;
    size = 32;
  };
  # pointerCursor only exports XCURSOR_* to shells; the gnome session (and
  # every app launched from the dock) reads environment.d instead
  systemd.user.sessionVariables = {
    XCURSOR_THEME = "capitaine-cursors";
    XCURSOR_SIZE = "32";
    # qt's own wayland decorations ignore gtk.css; under xwayland mutter
    # draws the frame with gtk4, so traffic lights apply to qt apps too
    QT_QPA_PLATFORM = "xcb";
    QT_QPA_PLATFORMTHEME = "gtk3";
    # same for kitty: its own wayland titlebar is a thin bar with right-side
    # glyphs; under xwayland it gets the gnome frame and traffic lights
    KITTY_DISABLE_WAYLAND = "1";
  };

  xdg.dataFile."themes/Wyvern".source = "${shellTheme}/share/themes/Wyvern";
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
      accent-color = "blue";
      icon-theme = "WhiteSur-Wyvern";
      cursor-theme = "capitaine-cursors";
      cursor-size = 32;
      # between 1x and the panel's smallest fractional step (1.25x): native
      # 1x display scale with text bumped up instead
      text-scaling-factor = 1.15;
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
        vicinae.extensionUuid
        caffeine.extensionUuid
      ];
    };
    "org/gnome/shell/extensions/user-theme".name = "Wyvern";
    # vicinae draws its own rounded window and keeps a transparent full-size
    # surface in compact mode; a corner/shadow around that would show as a
    # ghost frame under the search bar
    "org/gnome/shell/extensions/rounded-window-corners-reborn".blacklist = ["vicinae"];
    # blur-my-shell's dock blur trails the dock during overview transitions
    "org/gnome/shell/extensions/blur-my-shell/dash-to-dock".blur = false;
    # caffeine: quick settings toggle, top bar cup while active, survives
    # logout/reboot once switched on
    "org/gnome/shell/extensions/caffeine".restore-state = true;
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
      close = ["<Alt>q" "<Alt>F4"];
      minimize = ["<Alt>h" "<Alt>m"];
      toggle-fullscreen = ["<Control><Alt>f"];
      activate-window-menu = lib.hm.gvariant.mkEmptyArray lib.hm.gvariant.type.string;
    };
    "org/gnome/settings-daemon/plugins/media-keys" = {
      screensaver = ["<Control><Alt>q" "<Super>l"];
      custom-keybindings = ["/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/vicinae/"];
    };
    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/vicinae" = {
      name = "Vicinae";
      command = "vicinae toggle";
      binding = "<Alt>space";
    };
    "org/gnome/shell/keybindings" = {
      screenshot = ["<Shift>Print" "<Shift><Alt>3"];
      show-screenshot-ui = ["Print" "<Shift><Alt>4" "<Shift><Alt>5"];
      screenshot-window = ["<Alt>Print"];
    };
  };
}
