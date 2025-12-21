{ config, lib, pkgs, ... }:

{
  imports =
    [
      ./hardware-configuration.nix
      ../../_shared/configuration.nix
    ];

  networking.hostName = "desktop-vm";

  boot.kernelParams = [
    "video=DP-1:e"
    "drm.edid_firmware=DP-1:edid/fake-edid.bin"
  ];
  hardware.firmware = [
    (
      pkgs.runCommand "edid.bin" { } ''
        mkdir -p $out/lib/firmware/edid
        cp ${/edid/fake-edid.bin} $out/lib/firmware/edid/fake-edid.bin
      ''
    )];

  services.greetd.settings.default_session = {
    command = "sway";
    user = "user";
  };

  services.flatpak.enable = true;
  xdg = {
    portal = {
      config.common.default = "*";
      enable = true;
      extraPortals = [
        pkgs.xdg-desktop-portal-wlr
        pkgs.xdg-desktop-portal-gtk
      ];
    };
  };

  services.sunshine = {
    enable = true;
    capSysAdmin = true; # Needed for Wayland input support.
  };

  users.users.muser = {
    extraGroups = lib.mkAfter [
      "cdrom"
      "docker"
    ];
  };

  environment.systemPackages = lib.mkAfter (with pkgs; [
    age
    ethtool
    ffmpeg
    xwayland-satellite
  ]);

  services.openssh.enable = true;
  services.avahi.enable = true;

  services.syncthing = {
    enable = true;
    group = "users";
    user = "muser";
    dataDir = "/sync/data";
    configDir = "/sync/config";
  };

  services.printing.enable = true;

  services.nfs.server = {
    enable = true;
    exports = ''
      /home/user/usb-host-share usb-host.inf(rw,sync,no_subtree_check,fsid=0,no_root_squash)
    '';
  };

  systemd.services.nfs-server = {
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
  };

  virtualisation.docker.enable = true;
  virtualisation.docker.rootless = {
    enable = true;
    setSocketVariable = true;
  };

  # Do NOT change this value unless you have manually inspected all the changes it would make to your configuration,
  # and migrated your data accordingly.
  #
  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "24.05"; # Did you read the comment?
}

