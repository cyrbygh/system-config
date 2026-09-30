{ config, lib, pkgs, ... }:

{
  services.mosquitto = {
    enable = true;
    listeners = [
      {
        # Local services (zigbee2mqtt, home-assistant) connect without credentials.
        address          = "127.0.0.1";
        port             = 1883;
        omitPasswordAuth = true;
        settings.allow_anonymous = true;
      }
      {
        # IoT VLAN: anonymous for now; add vacuum user with hashedPasswordFile once
        # a new password is generated (mqtt-iot-passwords, one bcrypt hash per line).
        address          = (builtins.head config.networking.interfaces.iot.ipv4.addresses).address;
        port             = 1883;
        omitPasswordAuth = true;
        settings.allow_anonymous = true;
      }
    ];
  };
}
