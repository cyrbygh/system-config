{ config, lib, pkgs, ... }:

{
  services.miniflux = {
    enable = true;
    config = {
      LISTEN_ADDR        = "0.0.0.0:8080";
      CREATE_ADMIN       = false;
      DATABASE_URL       = "user=miniflux host=/run/postgresql dbname=miniflux";
    };
  };

  # INVIDIOUS_INSTANCE
  systemd.services.miniflux.serviceConfig.EnvironmentFile = config.age.secrets.domain-env.path;

  services.traefik.dynamicConfigOptions.http = {
    routers.miniflux = {
      rule        = "Host(`rss.{{ env `DOMAIN` }}`)";
      entryPoints = [ "websecure" ];
      service     = "miniflux";
      tls.certResolver = "letsencrypt";
    };
    services.miniflux.loadBalancer.servers = [{ url = "http://localhost:8080"; }];
  };
}
