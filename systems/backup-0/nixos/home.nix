{ lib, pkgs, ... }:

{
  home.stateVersion = "26.05";

  imports = [
    ../../_shared/home/base.nix
    ../../_shared/home/nixos.nix
  ];

  # No SSH key on this host — override base.nix settings to drop the SSH URL
  # rewrite so HTTPS pulls work.
  programs.git.settings = lib.mkForce {
    commit.gpgsign = false;
  };
}
