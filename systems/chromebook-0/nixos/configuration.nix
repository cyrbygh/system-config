{ config, lib, pkgs, ... }:

{
  imports =
    [
      ./hardware-configuration.nix
      ../../_shared/nixos/base.nix
      ../../_shared/nixos/thin_client.nix
    ];

  networking.hostName = "chromebook-0";

  # Remap the top row keys to F1-F10. Scancodes sourced from function_row_physmap.
  # The Search key already sends KEY_LEFTMETA so no remapping is needed for it.
  services.udev.extraHwdb = ''
    evdev:atkbd:dmi:bvn*:bvr*:bd*:svnGoogle:pnBobba:pvr*:rvn*:rn*:rvr*:
     KEYBOARD_KEY_ea=f1
     KEYBOARD_KEY_e9=f2
     KEYBOARD_KEY_e7=f3
     KEYBOARD_KEY_91=f4
     KEYBOARD_KEY_92=f5
     KEYBOARD_KEY_94=f6
     KEYBOARD_KEY_95=f7
     KEYBOARD_KEY_a0=f8
     KEYBOARD_KEY_ae=f9
     KEYBOARD_KEY_b0=f10
  '';

  # NetworkManager instead of networkd for nmtui and other wifi utilities.
  networking.useNetworkd = false;
  networking.networkmanager.enable = true;

  networking.wg-quick.interfaces.wg0.configFile = "/home/muser/.system-config/systems/current/wg0.conf.decrypted";
  users.users.muser.extraGroups = [ "networkmanager" ];

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

  # Suspend on lid close on battery and AC alike, so closing the lid resets to the greetd
  # prompt like the power button does. Both already default to suspend; set explicitly for
  # intent.
  services.logind.settings.Login = {
    HandleLidSwitch = "suspend";
    HandleLidSwitchExternalPower = "suspend";
  };

  system.stateVersion = "26.05";
}
