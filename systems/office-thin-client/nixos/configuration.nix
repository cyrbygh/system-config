{ config, lib, pkgs, ... }:

{
  imports =
    [
      ./hardware-configuration.nix
      ../../_shared/nixos/base.nix
      ../../_shared/nixos/thin_client.nix
    ];

  networking.hostName = "office-thin-client";

  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
  };

  # Authorize server-desktop's key so it can SSH in.
  users.users.muser.openssh.authorizedKeys.keyFiles = [
    ../../server-desktop/ssh/id_ed25519.pub
  ];

  # Intel iGPU. The media driver gives moonlight VAAPI accelerated decode, and iHD is the
  # driver name libva looks up at runtime.
  hardware.graphics.extraPackages = with pkgs; [
    intel-media-driver
  ];

  environment.sessionVariables = {
    LIBVA_DRIVER_NAME = "iHD";
  };

  system.stateVersion = "26.05";
}
