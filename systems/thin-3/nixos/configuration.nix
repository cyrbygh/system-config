{ config, lib, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../_shared/nixos/chromebook-thin-client.nix
  ];

  networking.hostName = "thin-3";

  # The HP Chromebook X2's Hammer keyboard touchpad advertises INPUT_PROP_DIRECT alongside
  # INPUT_PROP_POINTER, causing libinput to classify it as a touchscreen rather than a
  # touchpad. Unset DIRECT so libinput treats it as a pointer device and generates cursor
  # motion instead of touch events.
  environment.etc."libinput/local-overrides.quirks".text = ''
    [HP Chromebook X2 Hammer Touchpad]
    MatchName=Google Inc. Hammer
    MatchBus=usb
    MatchVendor=0x18D1
    MatchProduct=0x502B
    MatchDMIModalias=dmi:*svnGoogle:*pnSoraka*
    AttrInputPropUnset=INPUT_PROP_DIRECT
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
