{ config, lib, pkgs, ... }:

{
  services.miniflux = {
    enable = true;
    config = {
      LISTEN_ADDR        = "0.0.0.0:8080";
      INVIDIOUS_INSTANCE = "invidious.dillon.io";
      CREATE_ADMIN       = false;
      DATABASE_URL       = "user=miniflux host=/run/postgresql dbname=miniflux";
    };
  };

  services.traefik.dynamicConfigOptions.http = {
    routers.miniflux = {
      rule        = "Host(`rss.dillon.io`)";
      entryPoints = [ "websecure" ];
      service     = "miniflux";
      tls.certResolver = "letsencrypt";
    };
    services.miniflux.loadBalancer.servers = [{ url = "http://localhost:8080"; }];
  };
}
