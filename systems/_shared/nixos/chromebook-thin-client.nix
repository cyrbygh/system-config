{ config, lib, pkgs, ... }:

{
  imports = [ ./thin_client.nix ];

  networking.useNetworkd = false;
  networking.networkmanager.enable = true;
  users.users.muser.extraGroups = [ "networkmanager" ];

  age.identityPaths = [ "/etc/age_key" ];
  age.secrets.wg0-conf.mode = "0400";
  age.secrets.ssh-key = {
    path = "/home/muser/.ssh/id_ed25519";
    owner = "muser";
    mode = "0600";
  };

  networking.wg-quick.interfaces.wg0.configFile = config.age.secrets.wg0-conf.path;

  systemd.services.wg-quick-wg0 = {
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Restart = "on-failure";
      RestartSec = "5s";
    };
  };

  # Intel iGPU. The media driver gives moonlight VAAPI accelerated decode, and
  # iHD is the driver name libva looks up at runtime.
  hardware.graphics.extraPackages = with pkgs; [
    intel-media-driver
  ];

  environment.sessionVariables = {
    LIBVA_DRIVER_NAME = "iHD";
  };

  environment.systemPackages = with pkgs; [
    # acpi prints battery percentage and time remaining from a VT (acpi -b).
    acpi

    ungoogled-chromium

    # portal opens ungoogled-chromium in its own cage session to sign in to captive wifi
    # portals, then returns to the VT on exit. neverssl.com forces the portal redirect.
    (writeShellScriptBin "portal" ''
      exec ${cage}/bin/cage -s -- ${ungoogled-chromium}/bin/chromium --ozone-platform=wayland --new-window http://neverssl.com
    '')
  ];

  # Suspend on lid close on battery and AC alike, so closing the lid resets to the greetd
  # prompt like the power button does. Both already default to suspend; set explicitly for
  # intent.
  services.logind.settings.Login = {
    HandleLidSwitch = "suspend";
    HandleLidSwitchExternalPower = "suspend";
  };
}
