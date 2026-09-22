{ ... }:

{
  imports = [
    ../../_shared/home/base.nix
    ../../_shared/home/nixos.nix
  ];

  home.stateVersion = "26.05";

  home.file = {
    ".ssh/id_ed25519.pub".source   = ../ssh/id_ed25519.pub;
    ".config/sway/config".source   = ../sway;
    ".config/waybar".source        = ../waybar;
    ".config/kitty/kitty.conf".source = ../kitty.conf;
    ".config/mako/config".source   = ../mako.conf;
  };

  programs.zsh = {
    shellAliases = {
      icat = "kitty +kitten icat --align left";
      vcat = "mpv --vo=kitty";
    };
    initContent = ''
      if [[ "$TERM" == "xterm-kitty" ]]; then
        alias ssh='kitty +kitten ssh'
      fi
      export XDG_DATA_DIRS="$XDG_DATA_DIRS:/var/lib/flatpak/exports/share/applications/"
    '';
  };
}
