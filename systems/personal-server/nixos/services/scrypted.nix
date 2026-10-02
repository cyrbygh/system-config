{ config, lib, pkgs, ... }:

{
  # host network is required for mDNS/Bonjour used by HomeKit.
  virtualisation.oci-containers.containers.scrypted = {
    image   = "ghcr.io/koush/scrypted";
    volumes = [ "/var/lib/scrypted:/server/volume" ];
    extraOptions = [ "--network=host" ];
  };

  services.traefik.dynamicConfigOptions.http = {
    routers.scrypted = {
      rule        = "Host(`scrypted.dillon.io`)";
      entryPoints = [ "websecure" ];
      service     = "scrypted";
      tls.certResolver = "letsencrypt";
    };
    services.scrypted.loadBalancer.servers = [{ url = "http://localhost:11080"; }];
  };

  systemd.tmpfiles.rules = [
    "d /var/lib/scrypted 0750 root root -"
  ];

  systemd.services.podman-scrypted = {
    serviceConfig = {
      Restart    = lib.mkForce "always";
      RestartSec = "10s";
    };
  };

  systemd.services.scrypted-update = {
    description = "Pull latest scrypted image and restart if changed";
    after    = [ "network-online.target" ];
    wants    = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "scrypted-update" ''
        old=$(${pkgs.podman}/bin/podman inspect --format '{{.Id}}' ghcr.io/koush/scrypted 2>/dev/null || true)
        ${pkgs.podman}/bin/podman pull ghcr.io/koush/scrypted
        new=$(${pkgs.podman}/bin/podman inspect --format '{{.Id}}' ghcr.io/koush/scrypted 2>/dev/null || true)
        if [ -n "$new" ] && [ "$old" != "$new" ]; then
          ${pkgs.systemd}/bin/systemctl restart podman-scrypted.service
        fi
      '';
    };
  };

  systemd.timers.scrypted-update = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
    };
  };
}
