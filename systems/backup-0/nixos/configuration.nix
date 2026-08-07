{ config, lib, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../_shared/nixos/mac-mini-2014-backup.nix
  ];

  networking.hostName = "backup-0";
  age.secrets.wg0-conf.file = ../secrets/wg0-conf.age;
  system.stateVersion = "26.05";
}
