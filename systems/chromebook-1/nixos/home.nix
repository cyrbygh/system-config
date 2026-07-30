{ pkgs, ... }:

{
  home.stateVersion = "26.05";

  imports = [
    ../../_shared/home/base.nix
    ../../_shared/home/nixos.nix
  ];

  home.file.".ssh/id_ed25519.pub".source = ../ssh/id_ed25519.pub;
}
