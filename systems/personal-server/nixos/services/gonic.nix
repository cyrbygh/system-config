{ config, lib, pkgs, ... }:

{
  # Never auto-started: hdds/sensitive requires manual key loading before the
  # music path is available. Use start-sensitive-services after unlocking the pool.
  services.gonic = {
    enable = true;
    settings = {
      music-path            = [ "/hdds/sensitive/media/music" ];
      podcast-path          = "/var/lib/gonic/podcasts";
      playlists-path        = "/var/lib/gonic/playlists";
      scan-at-start-enabled = true;
    };
  };

  systemd.services.gonic = {
    wantedBy  = lib.mkForce [ "hdds-sensitive-media-music.mount" ];
    bindsTo   = [ "hdds-sensitive-media-music.mount" ];
    after     = [ "hdds-sensitive-media-music.mount" ];
  };

  services.traefik.dynamicConfigOptions.http = {
    routers.gonic = {
      rule        = "Host(`music.dillon.io`)";
      entryPoints = [ "websecure" ];
      service     = "gonic";
      tls.certResolver = "letsencrypt";
    };
    services.gonic.loadBalancer.servers = [{ url = "http://localhost:4747"; }];
  };
}
