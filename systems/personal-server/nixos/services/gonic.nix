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

  # StateDirectory=gonic only creates /var/lib/gonic itself; the module's own
  # BindPaths for playlists-path/podcast-path need these to already exist, or
  # the service fails at mount-namespace setup before gonic ever runs.
  systemd.tmpfiles.rules = [
    "d /var/lib/gonic/playlists 0755 root root -"
    "d /var/lib/gonic/podcasts 0755 root root -"
  ];

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
