{ config, lib, pkgs, ... }:

let
  peers = [
    { name = "phone";      ip = "10.77.67.100"; publicKey = "o2RWzcibrQwq7EfTsC9MqxApK3nQ3jJqe135Qa5PkUM="; }
    { name = "thin-1";     ip = "10.77.67.101"; publicKey = "aDAro79fATh9IJzVEfNEWxpAXX1jYNqVTCQHPj8m0TI="; }
    { name = "thin-2";     ip = "10.77.67.102"; publicKey = "z0tD0OtNJrAxglzaoXFykJec+0I/EOy1TP3pvH4zUmQ="; }
    { name = "thin-3";     ip = "10.77.67.103"; publicKey = "T9d8KLDYvlZjK9/W+PJ7AngdS8JpzABm0p9eud96ARI="; }
    { name = "backup-0";   ip = "10.77.68.2";   publicKey = "A1owSm2YExzG37FSDOCM/6Cby5BpP3W3qvoDdVxr1GU="; }
    { name = "backup-1";   ip = "10.77.68.3";   publicKey = "cw5uTzJIFtrAXvUUduJ0Iqe5GGEnhE6l3rruRbvzJTo="; }
    { name = "don-server"; ip = "10.77.68.4";   publicKey = "AeB+VYk21ooEzIRxtGG/30Az0pU07Ttuo4rkHkQCmBU="; }
  ];
in
{
  age.secrets.wg0-private-key = {
    file = ../../secrets/wg0-private-key.age;
    mode = "0400";
  };

  networking.wg-quick.interfaces.wg0 = {
    address     = [ "10.77.67.1/24" ];
    listenPort  = 443;
    privateKeyFile = config.age.secrets.wg0-private-key.path;
    peers = map (p: {
      inherit (p) publicKey;
      allowedIPs = [ "${p.ip}/32" ];
    }) peers;
  };

  systemd.services.wg-quick-wg0 = {
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
  };

  # <name>.wg records, served alongside the VLAN domains in networking.nix.
  environment.etc."dnsmasq-wg-hosts".text =
    lib.concatMapStrings (p: "${p.ip} ${p.name}.wg\n") peers;

  services.dnsmasq.settings = {
    addn-hosts = [ "/etc/dnsmasq-wg-hosts" ];
    local = [ "/wg/" ];
  };

  # dnsmasq only reads addn-hosts at startup.
  systemd.services.dnsmasq.restartTriggers = [
    config.environment.etc."dnsmasq-wg-hosts".text
  ];

  services.adguardhome.settings.dns.upstream_dns = [ "[/wg/]127.0.0.1:5335" ];
}
