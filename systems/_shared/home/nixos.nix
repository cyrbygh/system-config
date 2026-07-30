{ ... }:

{
  programs.zsh.shellAliases = {
    nixos-apply          = "sudo nixos-rebuild switch --flake ~/git/system-config/systems/_shared/nixos";
    nixos-edit           = "vim ~/git/system-config/systems/$(hostname)/nixos/configuration.nix";
    nixos-hardware-edit  = "vim ~/git/system-config/systems/$(hostname)/nixos/hardware-configuration.nix";
    nixos-update-packages = "nix flake update ~/git/system-config/systems/_shared/nixos";
  };
}
