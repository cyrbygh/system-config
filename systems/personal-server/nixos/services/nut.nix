{ config, lib, pkgs, ... }:

{
  age.secrets.nut-monitor-password = {
    file = ../../secrets/nut-monitor-password.age;
    owner = "root";
    mode = "0400";
  };

  power.ups = {
    enable = true;
    mode = "netserver";

    ups.server-ups = {
      driver = "usbhid-ups";
      port = "auto";
      description = "CyberPower OR500LCDRM1Ua";
    };

    users.monitor = {
      passwordFile = config.age.secrets.nut-monitor-password.path;
      actions = [ "get" ];
      instcmds = [ "none" ];
    };

    upsd.listen = [
      { address = "127.0.0.1"; port = 3493; }
    ];

    upsmon = {
      enable = true;
      monitor.server-ups = {
        system = "server-ups@localhost";
        powerValue = 1;
        user = "monitor";
        passwordFile = config.age.secrets.nut-monitor-password.path;
        type = "primary";
      };
    };
  };
}
