{ config, lib, pkgs, ... }:

let
  # Forcing eDP-1's connector status to "off" makes it look unplugged to fbcon and sway
  # alike; "detect" hands it back. Lid close is inhibited while docked on AC, and the power
  # key is inhibited while undocked.
  externalMonitorSwitch = pkgs.writeShellScript "external-monitor-switch" ''
    edp=$(echo /sys/class/drm/card*-eDP-1/status)
    dp=$(echo /sys/class/drm/card*-DP-1/status)

    docked=
    if [ "$(cat "$dp")" = connected ]; then
      docked=1
      [ "$(cat "$edp")" = disconnected ] || echo off > "$edp"
    elif [ "$(cat "$edp")" = disconnected ]; then
      echo detect > "$edp"
    fi

    if [ -n "$docked" ]; then
      ${pkgs.systemd}/bin/systemctl --no-block stop undocked-power-key-inhibit.service
    else
      ${pkgs.systemd}/bin/systemctl --no-block start undocked-power-key-inhibit.service
    fi

    on_ac=
    for p in /sys/class/power_supply/*; do
      [ "$(cat "$p/type")" != Battery ] && [ "$(cat "$p/online" 2>/dev/null)" = 1 ] && on_ac=1
    done

    if [ -n "$docked" ] && [ -n "$on_ac" ]; then
      ${pkgs.systemd}/bin/systemctl --no-block start docked-lid-inhibit.service
    else
      ${pkgs.systemd}/bin/systemctl --no-block stop docked-lid-inhibit.service
    fi
  '';
  restartSwitch = "${pkgs.systemd}/bin/systemctl --no-block restart external-monitor-switch.service";
in

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

  # External monitor on DP-1 replaces the internal panel.
  systemd.services.external-monitor-switch = {
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = externalMonitorSwitch;
    };
  };

  services.udev.extraRules = ''
    ACTION=="change", SUBSYSTEM=="drm", ENV{HOTPLUG}=="1", RUN+="${restartSwitch}"
    ACTION=="change", SUBSYSTEM=="power_supply", ATTR{type}!="Battery", RUN+="${restartSwitch}"
  '';

  systemd.services.docked-lid-inhibit.serviceConfig.ExecStart =
    "${pkgs.systemd}/bin/systemd-inhibit --what=handle-lid-switch --who=external-monitor-switch --why='Docked on AC' --mode=block ${pkgs.coreutils}/bin/sleep infinity";

  systemd.services.undocked-power-key-inhibit.serviceConfig.ExecStart =
    "${pkgs.systemd}/bin/systemd-inhibit --what=handle-power-key --who=external-monitor-switch --why='Undocked' --mode=block ${pkgs.coreutils}/bin/sleep infinity";

  # Suspend unless the inhibitors above are held. logind's docked lid default is ignore.
  services.logind.settings.Login = {
    HandleLidSwitchDocked = "suspend";
    HandlePowerKey = lib.mkForce "suspend";
  };

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
