{ config, lib, pkgs, ... }:

{
  services.jellyfin.enable = true;

  systemd.services.jellyfin = {
    wantedBy = lib.mkForce [
      "hdds-sensitive-media-movies.mount"
      "hdds-sensitive-media-tv_shows.mount"
    ];
    requires = [
      "hdds-sensitive-media-movies.mount"
      "hdds-sensitive-media-tv_shows.mount"
    ];
    after = [
      "hdds-sensitive-media-movies.mount"
      "hdds-sensitive-media-tv_shows.mount"
    ];
  };

  services.traefik.dynamicConfigOptions.http = {
    routers.jellyfin = {
      rule        = "Host(`media.dillon.io`)";
      entryPoints = [ "websecure" ];
      service     = "jellyfin";
      tls.certResolver = "letsencrypt";
    };
    services.jellyfin.loadBalancer.servers = [{ url = "http://localhost:8096"; }];
  };
}
