{ config, lib, pkgs, ... }:

{
  age.secrets.wg0-private-key = {
    file = ../../secrets/wg0-private-key.age;
    mode = "0400";
  };

  networking.wg-quick.interfaces.wg0 = {
    address     = [ "10.77.67.1/24" ];
    listenPort  = 443;
    privateKeyFile = config.age.secrets.wg0-private-key.path;
    peers = [
      { # phone
        publicKey  = "o2RWzcibrQwq7EfTsC9MqxApK3nQ3jJqe135Qa5PkUM=";
        allowedIPs = [ "10.77.67.100/32" ];
      }
      { # thin-1
        publicKey  = "aDAro79fATh9IJzVEfNEWxpAXX1jYNqVTCQHPj8m0TI=";
        allowedIPs = [ "10.77.67.101/32" ];
      }
      { # thin-2
        publicKey  = "z0tD0OtNJrAxglzaoXFykJec+0I/EOy1TP3pvH4zUmQ=";
        allowedIPs = [ "10.77.67.102/32" ];
      }
      { # thin-3
        publicKey  = "T9d8KLDYvlZjK9/W+PJ7AngdS8JpzABm0p9eud96ARI=";
        allowedIPs = [ "10.77.67.103/32" ];
      }
      { # backup-0
        publicKey  = "A1owSm2YExzG37FSDOCM/6Cby5BpP3W3qvoDdVxr1GU=";
        allowedIPs = [ "10.77.68.2/32" ];
      }
      { # backup-1
        publicKey  = "cw5uTzJIFtrAXvUUduJ0Iqe5GGEnhE6l3rruRbvzJTo=";
        allowedIPs = [ "10.77.68.3/32" ];
      }
      { # don-server
        publicKey  = "AeB+VYk21ooEzIRxtGG/30Az0pU07Ttuo4rkHkQCmBU=";
        allowedIPs = [ "10.77.68.4/32" ];
      }
    ];
  };

  systemd.services.wg-quick-wg0 = {
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
  };
}
