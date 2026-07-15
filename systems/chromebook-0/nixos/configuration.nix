{ config, lib, pkgs, ... }:

{
  imports =
    [
      ./hardware-configuration.nix
      ../../_shared/nixos/base.nix
      ../../_shared/nixos/thin_client.nix
      ../../_shared/nixos/wireguard.nix
    ];

  networking.hostName = "chromebook-0";

  # Placeholder slot, replace with this client's assigned address.
  wireguardClient.slot = 1;

  # iwd manages wifi. Networks are picked from a terminal by running iwctl.
  networking.wireless.iwd.enable = true;

  # networkd handles addressing on the wireless link once iwd associates.
  systemd.network.networks."40-wireless" = {
    matchConfig.Type = "wlan";
    networkConfig.DHCP = "yes";
  };

  # Intel iGPU (Celeron N4000). The media driver gives moonlight VAAPI accelerated decode, and
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

  system.stateVersion = "26.05";
}
