{ config, lib, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../_shared/nixos/chromebook-thin-client.nix
  ];

  networking.hostName = "thin-3";

  # The HP Chromebook X2's Hammer keyboard touchpad reports INPUT_PROP_DIRECT alongside
  # INPUT_PROP_POINTER, causing libinput to classify it as a touchscreen. Match the touchpad
  # interface specifically via its ABS capabilities (distinct from the keyboard interface)
  # and override the udev classification so libinput generates pointer events instead.
  services.udev.extraRules = ''
    SUBSYSTEM=="input", ATTRS{name}=="Google Inc. Hammer", ATTRS{capabilities/abs}=="673800001000003", ENV{ID_INPUT_TOUCHPAD}="1", ENV{ID_INPUT_TOUCHSCREEN}=""
  '';

  # Set pressure range and Chromebook model flag so libinput registers light touches.
  # AttrPressureRange matches the threshold used on other Hammer-based Chromebooks.
  environment.etc."libinput/local-overrides.quirks".text = ''
    [HP Chromebook X2 Hammer Touchpad]
    MatchUdevType=touchpad
    MatchName=Google Inc. Hammer
    MatchBus=usb
    MatchVendor=0x18D1
    MatchProduct=0x502B
    MatchDMIModalias=dmi:*svnGoogle:*pnSoraka*
    ModelChromebook=1
    AttrPressureRange=20:10
  '';

  age.secrets.wg0-conf.file = ../secrets/wg0-conf.age;
  age.secrets.ssh-key.file = ../secrets/ssh-key.age;

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users.muser = import ./home.nix;
  };

  system.stateVersion = "26.05";
}
