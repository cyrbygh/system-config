{ config, lib, pkgs, ... }:

let
  # alsa-lib's UCM2 conf.d lookup matches files by CardLongName, so it looks for
  # "AVS I2S MAX98927.conf" in conf.d/avs_max98927/. The profiles in alsa-ucm-conf are
  # named "HP-Soraka-1.0.conf" which is never found. The upstream HiFi profile also
  # specifies PCM device 1, but this board's AVS driver only exposes device 0.
  # Build a merged UCM2 tree with correctly-named aliases and a patched HiFi file,
  # then point PipeWire at it via ALSA_CONFIG_UCM2.
  sorakaAliases = pkgs.runCommand "soraka-ucm-aliases" { } ''
    mkdir -p "$out/conf.d/avs_max98927"
    cp ${pkgs.alsa-lib}/share/alsa/ucm2/conf.d/avs_max98927/HP-Soraka-1.0.conf \
       "$out/conf.d/avs_max98927/AVS I2S MAX98927.conf"
    mkdir -p "$out/conf.d/avs_rt5663"
    cp ${pkgs.alsa-lib}/share/alsa/ucm2/conf.d/avs_rt5663/HP-Soraka-1.0.conf \
       "$out/conf.d/avs_rt5663/AVS I2S ALC5663.conf"
    mkdir -p "$out/conf.d/avs_dmic"
    cp ${pkgs.alsa-lib}/share/alsa/ucm2/conf.d/avs_dmic/HP-Soraka-1.0.conf \
       "$out/conf.d/avs_dmic/AVS DMIC.conf"
    mkdir -p "$out/Intel/avs/avs_max98927"
    sed 's/PlaybackPCM "hw:''${CardId},1"/PlaybackPCM "hw:''${CardId},0"/' \
      ${pkgs.alsa-lib}/share/alsa/ucm2/Intel/avs/avs_max98927/HP-Soraka-1.0-HiFi.conf \
      > "$out/Intel/avs/avs_max98927/HP-Soraka-1.0-HiFi.conf"
  '';
  ucm2 = pkgs.symlinkJoin {
    name = "alsa-ucm2-soraka";
    paths = [ sorakaAliases "${pkgs.alsa-lib}/share/alsa/ucm2" ];
  };
in

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

  systemd.user.services.pipewire.environment.ALSA_CONFIG_UCM2 = "${ucm2}";
  systemd.user.services.wireplumber.environment.ALSA_CONFIG_UCM2 = "${ucm2}";

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
