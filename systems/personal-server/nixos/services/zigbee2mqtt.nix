{ config, lib, pkgs, ... }:

{
  age.secrets.zigbee2mqtt-network-key = {
    file  = ../../secrets/zigbee2mqtt-network-key.age;
    mode  = "0400";
    owner = "zigbee2mqtt";
  };

  # zigbee2mqtt resolves `!secret <key>` values from secret.yaml in the data directory.
  systemd.tmpfiles.rules = [
    "L+ /var/lib/zigbee2mqtt/secret.yaml - - - - ${config.age.secrets.zigbee2mqtt-network-key.path}"
  ];

  services.zigbee2mqtt = {
    enable = true;
    settings = {
      homeassistant = {
        enabled      = true;
        status_topic = "homeassistant/status";
      };
      mqtt = {
        base_topic = "zigbee2mqtt";
        server     = "mqtt://localhost:1883";
      };
      serial = {
        port    = "/dev/ttyZB0";
        adapter = "zstack";
      };
      advanced = {
        channel     = 25;
        network_key = "!secret network_key";
        pan_id      = 36795;
        ext_pan_id  = [ 184 49 121 226 58 142 21 223 ];
      };
      devices = "devices.yaml";
    };
  };

  systemd.services.zigbee2mqtt = {
    bindsTo = [ "dev-ttyZB0.device" ];
    after   = [ "dev-ttyZB0.device" ];
  };

  users.users.zigbee2mqtt.extraGroups = [ "dialout" ];
}
