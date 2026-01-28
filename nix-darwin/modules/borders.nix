{
  config,
  pkgs,
  lib,
  ...
}: {
  options.borders = {
    enable = lib.mkEnableOption "jankyborders window borders";
  };

  config = lib.mkIf config.borders.enable {
    home.file.".config/borders/bordersrc".text = ''
      #!/bin/bash

      # Use ax_focus for faster window detection (requires accessibility permissions)
      options=(
      	style=round
      	width=6.0
      	hidpi=off
      	ax_focus=on
      	active_color=0xffe2e2e3
      	inactive_color=0xff414550
      	blacklist="Confirmo"
      )

      borders "''${options[@]}"
    '';

    home.file.".config/borders/bordersrc".executable = true;
  };
}
