{ config, lib, pkgs, ... }:

{
  age.secrets.zwave-keys = {
    file  = ../../secrets/zwave-keys.age;
    mode  = "0400";
    owner = "zwave-js";
  };

  services.zwave-js = {
    enable     = true;
    serialPort = "/dev/ttyZW0";
    secretsConfigFile = config.age.secrets.zwave-keys.path;
    # 3000 = AdGuard, 3001 = Invidious; HA must connect to ws://localhost:3002
    port = 3002;
  };

  systemd.services.zwave-js = {
    bindsTo = [ "dev-ttyZW0.device" ];
    after   = [ "dev-ttyZW0.device" ];
  };

  users.users.zwave-js = {
    isSystemUser = true;
    group        = "zwave-js";
    extraGroups  = [ "dialout" ];
  };
  users.groups.zwave-js = {};
}
