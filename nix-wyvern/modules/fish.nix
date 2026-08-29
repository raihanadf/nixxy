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
      ls = "ls --color=auto";
      la = "ls -la --color=auto";
      l = "ls -d .* --color=auto";

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

      # Misc
      killmyself = "pkill -KILL -u (whoami)";
      gitzip = "git archive HEAD -o (basename $PWD).zip";
      sail = "[ -f sail ]; and sh sail; or sh vendor/bin/sail";
      emulator = "$ANDROID_HOME/emulator/emulator";
      myip = "ip route get 1 | awk '{print $7; exit}'";
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
      # Manage the self-hosted honcho stack: ollama (local inference) + docker
      # compose (API/deriver/redis/postgres, project "honcho-local") + the
      # local MCP worker + the tailnet forwards for loong. Shadows the
      # honcho-cli binary on PATH -- `command honcho` still reaches the CLI.
      # `restore [dumpfile]` loads a pg_dump from ~/.honcho/backups (or the
      # given file) into an empty database.
      honcho = ''
        function honcho
            set -l cmd $argv[1]
            set -l project_dir $HOME/.honcho/profiles/local
            set -l units honcho-mcp.service honcho-mcp-tailnet.service honcho-tailnet.service

            switch "$cmd"
                case start
                    # ollama first: it pins VRAM (GPU leaves D3cold), so it
                    # only runs while the stack is wanted
                    sudo systemctl start ollama
                    for i in (seq 1 60)
                        if wget -q -O /dev/null http://127.0.0.1:11434/api/tags
                            break
                        end
                        sleep 1
                    end
                    docker compose -p honcho-local --project-directory $project_dir up -d
                    or return 1
                    # worker is useless until the API is healthy; postgres
                    # needs a few seconds on a cold start
                    for i in (seq 1 30)
                        if test (docker inspect -f '{{.State.Health.Status}}' honcho-local-api-1 2>/dev/null) = healthy
                            break
                        end
                        sleep 1
                    end
                    sudo systemctl start $units
                case stop
                    sudo systemctl stop $units
                    docker compose -p honcho-local --project-directory $project_dir stop
                    sudo systemctl stop ollama
                case restart
                    honcho stop
                    or return 1
                    honcho start
                case restore
                    if not docker ps --format '{{.Names}}' | grep -q '^honcho-local-database-1$'
                        echo "honcho: stack not running; run 'honcho start' first" >&2
                        return 1
                    end
                    set -l dump $argv[2]
                    if test -z "$dump"
                        set dump (ls -1t $HOME/.honcho/backups/honcho-*.sql.gz 2>/dev/null | head -1)
                    end
                    if test -z "$dump"
                        echo "honcho: no backup found in ~/.honcho/backups" >&2
                        return 1
                    end
                    if not test -f "$dump"
                        echo "honcho: no such file: $dump" >&2
                        return 1
                    end
                    echo "honcho: restoring $dump (drops the current database)"
                    docker stop honcho-local-api-1
                    docker exec honcho-local-database-1 psql -U postgres -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public;" >/dev/null
                    gunzip -c "$dump" | docker exec -i honcho-local-database-1 psql -U postgres postgres
                    docker start honcho-local-api-1
                case '*'
                    echo "usage: honcho {start,stop,restart,restore [dumpfile]}" >&2
                    return 1
            end
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
        --exclude=.cache \
        --exclude=.npm \
        --exclude=.cargo \
        --exclude=.Trash

      set -gx FZF_DEFAULT_OPTS '--height 40% --layout=reverse --border --inline-info'
      fzf_configure_bindings --directory=\ec --variables=\ev
    '';

    # Shell init (PATH)
    shellInit = ''
      fish_add_path $HOME/.spicetify
      fish_add_path $HOME/.volta/bin
      fish_add_path $HOME/.local/bin
      fish_add_path $HOME/.antigravity/antigravity/bin
      fish_add_path $HOME/.opencode/bin
      fish_add_path $HOME/.cargo/bin
      fish_add_path $HOME/.nix-profile/bin
      fish_add_path /nix/var/nix/profiles/default/bin
    '';
  };
}
