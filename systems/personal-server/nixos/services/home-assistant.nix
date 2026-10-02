{ config, lib, pkgs, ... }:

{
  services.home-assistant = {
    enable = true;
    # configuration.yaml and all other config is copied from HaOS and managed
    # by HA itself — no `config` attr here so nix doesn't touch it.
    extraComponents = [
      "apple_tv"
      "broadlink"
      "dhcp"
      "esphome"
      "glances"
      "go2rtc"
      "homekit"
      "homekit_controller"
      "lg_thinq"
      "met"
      "mqtt"
      "nut"
      "rest"
      "ssdp"
      "stream"
      "thread"
      "zha"
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
