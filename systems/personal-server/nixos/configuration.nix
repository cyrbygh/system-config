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
    ./services/scrypted.nix
    ./services/wireguard.nix
    ./services/traefik.nix
    ./services/mosquitto.nix
    ./services/zwave-js.nix
    ./services/zigbee2mqtt.nix
    ./services/gonic.nix
    ./services/jellyfin.nix
    ./services/home-assistant.nix
    ./services/nut.nix
    ./services/omada-controller.nix
    ./sensitive.nix
  ];

  networking.hostName = "personal-server";
  networking.hostId = "49377d88";

  systemd.network.links."10-tr0" = {
    matchConfig.MACAddress = "a8:a1:59:be:11:78";
    linkConfig.Name = "tr0";
  };

  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
  };

  age.secrets.ssh-key = {
    file = ../secrets/ssh-key.age;
    path = "/home/muser/.ssh/id_ed25519";
    owner = "muser";
    mode = "0600";
  };

  users.users.muser.openssh.authorizedKeys.keyFiles = [
    ../../thin-1/ssh/id_ed25519.pub
    ../../thin-2/ssh/id_ed25519.pub
  ];

  users.users.root.openssh.authorizedKeys.keyFiles = [
    ../../thin-2/ssh/id_ed25519.pub
  ];


  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users.muser = import ./home.nix;
  };

  nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (pkgs.lib.getName pkg) [
    "claude-code"
  ];

  environment.systemPackages = with pkgs; [
    claude-code
  ];

  system.stateVersion = "26.05";
}
