{pkgs, ...}: {
  programs.fish = {
    enable = true;

    # Plugins - replaces Fisher entirely
    plugins = [
      {
        name = "grc";
        src = pkgs.fishPlugins.grc.src;
      }
      {
        name = "autopair";
        src = pkgs.fishPlugins.autopair.src;
      }
      {
        name = "fzf-fish";
        src = pkgs.fishPlugins.fzf-fish.src;
      }
      {
        name = "plugin-git";
        src = pkgs.fishPlugins.plugin-git.src;
      }
    ];

    # Aliases
    shellAliases = {
      # Simple aliases
      c = "clear";
      q = "exit";
      cq = "clear && exit";
      nnn = "nnn -de";
      sl = "sl -a -w -l";
      sizedir = "du -h -d 1";
      ls = "ls -G";
      la = "ls -laG";
      l = "ls -d .* -G";

      # Edit configs
      zshalias = "nvim $HOME/.zsh_aliases";
      zshplugin = "nvim $HOME/.dotfiles/dots/zsh_plugins";
      zshconfig = "nvim $HOME/.zshrc";
      vimconfig = "nvim $HOME/.vimrc";
      nvimconfig = "nvim $HOME/.config/nvim/init.lua";

      # Better apps
      vi = "nvim";
      leetcode = "nvim leetcode.nvim";
      py = "python3";

      # Directories
      nginxdir = "cd $nginxdir";
      nvimdir = "cd $nvimdir";

      # Android mount
      androidmount = "aft-mtp-mount $HOME/MountHere";
      androidumount = "umount $HOME/MountHere";

      # Network
      wifi = "networksetup -listallhardwareports";

      # Misc
      killmyself = "pkill -KILL -u (whoami)";
      record = "ffmpeg -f avfoundation -framerate 60 -i \"1\" $HOME/Videos/now-recorded.mp4";
      gitzip = "git archive HEAD -o (basename $PWD).zip";
      sail = "[ -f sail ]; and sh sail; or sh vendor/bin/sail";
      emulator = "$ANDROID_HOME/emulator/emulator";
      myip = "ipconfig getifaddr en0";
    };

    # Abbreviations
    shellAbbrs = {
      "!!" = "sudo $history[1]";
    };

    # Functions
    functions = {
      mkcd = "mkdir -p -- $argv[1]; and cd $argv[1]";
      batcat = ''
        if type -q bat
          bat $argv
        else
          cat $argv
        end
      '';
    };

    # Interactive shell init
    interactiveShellInit = ''
      # No greeting
      set -g fish_greeting ""

      # Vi keybindings
      fish_vi_key_bindings insert

      # FZF configuration
      set -g fzf_fd_opts \
        --follow \
        --exclude=.git \
        --exclude=node_modules \
        --exclude=Library \
        --exclude=Music \
        --exclude=.cache \
        --exclude=.npm \
        --exclude=.cargo \
        --exclude=.Trash \
        --exclude=.localized \
        --exclude=Applications

      set -gx FZF_DEFAULT_OPTS '--height 40% --layout=reverse --border --inline-info'
      fzf_configure_bindings --directory=\ec --variables=\ev
    '';

    # Shell init (PATH)
    shellInit = ''
      fish_add_path /opt/homebrew/bin
      fish_add_path $HOME/.spicetify
      fish_add_path $HOME/.volta/bin
      fish_add_path $HOME/.local/bin
      fish_add_path $HOME/.antigravity/antigravity/bin
      fish_add_path $HOME/.opencode/bin
      fish_add_path $HOME/.cargo/bin
    '';
  };
}
