{ config, lib, pkgs, ... }:

{
  imports =
    [
      ./hardware-configuration.nix
      ../../_shared/configuration.nix
    ];

  networking.hostName = "thin-client";

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [
      intel-media-driver
    ];
  };

  services.greetd.settings.default_session = {
    command = "${pkgs.tuigreet}/bin/tuigreet --time --cmd 'cage -d -s -- moonlight'";
    user = "muser";
  };

  environment.systemPackages = lib.mkAfter (with pkgs; [
    cage
    libva
    libva-utils
    moonlight-qt
  ]);

  environment.sessionVariables = {
    LIBVA_DRIVER_NAME = "iHD";
  };

  security.polkit.enable = true;

  services.openssh.enable = true;
  services.printing.enable = true;

  services.pipewire = {
    enable = true;
    pulse.enable = true;
  };

  # This option defines the first version of NixOS you have installed on this particular machine,
  # and is used to maintain compatibility with application data (e.g. databases) created on older NixOS versions.
  #
  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "25.11"; # Did you read the comment?
}

