{ config, lib, pkgs, ... }:

{
  services.home-assistant = {
    enable = true;
    # configuration.yaml and all other config is copied from HaOS and managed
    # by HA itself — no `config` attr here so nix doesn't touch it.
    extraComponents = [
      "broadlink"
      "esphome"
      "homekit"
      "mqtt"
      "zwave_js"
    ];
  };

  services.traefik.dynamicConfigOptions.http = {
    routers.hass = {
      rule        = "Host(`hass.dillon.io`)";
      entryPoints = [ "websecure" ];
      service     = "hass";
      tls.certResolver = "letsencrypt";
    };
    services.hass.loadBalancer.servers = [{ url = "http://localhost:8123"; }];
  };
}
