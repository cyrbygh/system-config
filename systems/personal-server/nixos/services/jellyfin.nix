{ config, lib, pkgs, ... }:

{
  services.jellyfin = {
    enable = true;

    # Intel iGPU (UHD 730). by-path, not renderD12x - minor numbers shift between
    # boots on this box with three GPUs.
    hardwareAcceleration = {
      enable = true;
      type = "vaapi";
      device = "/dev/dri/by-path/pci-0000:00:02.0-render";
    };

    # Without this the module won't overwrite an existing encoding.xml, so the
    # settings below would never apply. Dashboard transcoding edits get reset.
    forceEncodingConfig = true;

    # Codec support per vainfo on this iGPU; all of these default to false.
    transcoding = {
      enableHardwareEncoding = true;
      enableIntelLowPowerEncoding = true;
      hardwareDecodingCodecs = {
        h264 = true;
        hevc = true;
        hevc10bit = true;
        hevcRExt10bit = true;
        hevcRExt12bit = true;
        mpeg2 = true;
        vc1 = true;
        vp9 = true;
        av1 = true;
      };
      hardwareEncodingCodecs.hevc = true;
    };
  };

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
