{ config, lib, pkgs, ... }:

{
  services.mosquitto = {
    enable = true;
    settings.per_listener_settings = true;
    listeners = [
      {
        # Local services (zigbee2mqtt, home-assistant) connect without credentials.
        address = "127.0.0.1";
        port    = 1883;
        settings.allow_anonymous = true;
      }
      {
        # IoT VLAN: password_file is in mosquitto passwd format (username:bcrypt_hash),
        # one line per device. Generate entries with: mosquitto_passwd -b <file> <user> <pass>
        address = (builtins.head config.networking.interfaces.iot.ipv4.addresses).address;
        port    = 1883;
        settings = {
          allow_anonymous = false;
          password_file   = ../../../mqtt-iot-passwords;
        };
      }
    ];
  };
}
