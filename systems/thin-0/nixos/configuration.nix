{ config, lib, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../_shared/nixos/thin_client.nix
  ];

  networking.hostName = "thin-0";

  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
  };

  # Authorize server-desktop's key so it can SSH in.
  users.users.muser.openssh.authorizedKeys.keyFiles = [
    ../../server-desktop/ssh/id_ed25519.pub
  ];

  age.identityPaths = [ "/etc/age_key" ];
  age.secrets.ssh-key = {
    file = ../secrets/ssh-key.age;
    path = "/home/muser/.ssh/id_ed25519";
    owner = "muser";
    mode = "0600";
  };

  # Suspend on a short power button press. Since moonlight grabs the keyboard, the power button
  # is the only practical local sleep and wake control.
  services.logind.settings.Login.HandlePowerKey = "suspend";

  # Intel iGPU. The media driver gives moonlight VAAPI accelerated decode, and iHD is the
  # driver name libva looks up at runtime.
  hardware.graphics.extraPackages = with pkgs; [
    intel-media-driver
  ];

  environment.sessionVariables = {
    LIBVA_DRIVER_NAME = "iHD";
  };

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users.muser = import ./home.nix;
  };

  system.stateVersion = "26.05";
}
