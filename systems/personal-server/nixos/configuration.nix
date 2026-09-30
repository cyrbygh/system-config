{ config, lib, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../_shared/nixos/base.nix
    ./networking.nix
    ./services/postgres.nix
    ./services/miniflux.nix
    ./services/vaultwarden.nix
    ./services/invidious.nix
    ./services/wireguard.nix
    ./services/traefik.nix
  ];

  networking.hostName = "personal-server";
  networking.hostId = "49377d88";

  # When transplanting to the i5-13400 machine, update this MAC to a8:a1:59:be:11:78
  systemd.network.links."10-tr0" = {
    matchConfig.MACAddress = "18:c0:4d:90:4f:70";
    linkConfig.Name = "tr0";
  };

  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
  };

  users.users.muser.openssh.authorizedKeys.keyFiles = [
    ../../server-desktop/ssh/id_ed25519.pub
  ];

  users.users.root.openssh.authorizedKeys.keyFiles = [
    ../../server-desktop/ssh/id_ed25519.pub
  ];


  system.stateVersion = "26.05";
}
