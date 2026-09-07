{ config, lib, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../_shared/nixos/chromebook-thin-client.nix
  ];

  networking.hostName = "thin-3";

  age.secrets.wg0-conf.file = ../secrets/wg0-conf.age;
  age.secrets.ssh-key.file = ../secrets/ssh-key.age;

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users.muser = import ./home.nix;
  };

  system.stateVersion = "26.05";
}
