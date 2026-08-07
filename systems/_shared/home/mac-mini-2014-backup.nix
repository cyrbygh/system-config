{ lib, pkgs, ... }:

{
  home.stateVersion = "26.05";

  imports = [
    ./base.nix
    ./nixos.nix
  ];

  # No SSH key on this host — override base.nix settings to drop the SSH URL
  # rewrite so HTTPS pulls work.
  programs.git.settings = lib.mkForce {
    commit.gpgsign = false;
  };
}
