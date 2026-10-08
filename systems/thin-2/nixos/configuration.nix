{ config, lib, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../_shared/nixos/chromebook-thin-client.nix
    ../../_shared/nixos/iwlwifi-resume-fix.nix
  ];

  networking.hostName = "thin-2";

  # Remap the top row keys to F1-F10. Scancodes sourced from function_row_physmap.
  # The Search key already sends KEY_LEFTMETA so no remapping is needed for it.
  services.udev.extraHwdb = ''
    evdev:atkbd:dmi:bvn*:bvr*:bd*:svnGoogle:pnFleex:pvr*:rvn*:rn*:rvr*:
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

  nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
    "claude-code"
  ];

  environment.systemPackages = [ pkgs.claude-code ];

  age.secrets.wg0-conf.file = ../secrets/wg0-conf.age;
  age.secrets.ssh-key.file = ../secrets/ssh-key.age;

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users.muser.home.file = {
      ".ssh/id_ed25519.pub".source = ../ssh/id_ed25519.pub;
      ".config/foot/foot.ini".source = ../foot.ini;
    };
  };

  system.stateVersion = "26.05";
}
