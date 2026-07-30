{ pkgs, ... }:

{
  home.stateVersion = "26.05";

  imports = [
    ../../_shared/home/base.nix
    ../../_shared/home/nixos.nix
  ];
}
