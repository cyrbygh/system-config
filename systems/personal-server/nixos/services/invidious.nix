{ config, lib, pkgs, ... }:

{
  # Shared by Invidious and the companion: SERVER_SECRET_KEY, plus Invidious's
  # INVIDIOUS_INVIDIOUS_COMPANION{,_KEY} setting overrides.
  age.secrets.invidious-env.file = ../../secrets/invidious-env.age;

  services.invidious = {
    enable = true;
    port   = 3001;
    settings = {
      check_tables = true;
    };
    # null host = connect via unix socket; peer auth, no password needed.
    database.createLocally = false;
    database.host = null;
  };

  # Companion is Deno-based with no nixpkgs package; run it via Podman.
  virtualisation.oci-containers = {
    backend = "podman";
    containers.invidious-companion = {
      image   = "quay.io/invidious/invidious-companion:latest";
      ports   = [ "127.0.0.1:8282:8282" ];
      environmentFiles = [ config.age.secrets.invidious-env.path ];
      volumes = [ "/var/lib/invidious-companion:/var/tmp/youtubei.js:rw" ];
      extraOptions = [
        "--cap-drop=ALL"
        "--read-only"
        "--security-opt=no-new-privileges:true"
      ];
    };
  };

  services.traefik.dynamicConfigOptions.http = {
    routers.invidious = {
      rule        = "Host(`invidious.{{ env `DOMAIN` }}`)";
      entryPoints = [ "websecure" ];
      service     = "invidious";
      tls.certResolver = "letsencrypt";
    };
    services.invidious.loadBalancer.servers = [{ url = "http://localhost:3001"; }];
  };

  # DynamicUser=true (the module default) tries to bind-mount a private state
  # dir on top of /var/lib/invidious, which conflicts with the ZFS mountpoint.
  # Use an explicit user instead.
  users.users.invidious = { isSystemUser = true; group = "invidious"; };
  users.groups.invidious = {};

  systemd.services.invidious = {
    after    = [ "postgresql.service" "var-lib-invidious.mount" ];
    requires = [ "postgresql.service" "var-lib-invidious.mount" ];
    serviceConfig = {
      EnvironmentFile = config.age.secrets.invidious-env.path;
      DynamicUser    = lib.mkForce false;
      User           = lib.mkForce "invidious";
      Group          = lib.mkForce "invidious";
      StateDirectory = lib.mkForce "invidious";
    };
  };

  # UID/GID 10001 = appuser inside the invidious-companion image.
  systemd.tmpfiles.rules = [
    "d /var/lib/invidious-companion 0700 10001 10001 -"
  ];

  systemd.services.podman-invidious-companion = {
    serviceConfig = {
      Restart    = lib.mkForce "always";
      RestartSec = "10s";
    };
  };

  # Daily restart clears companion stalls; picks up a new image if one was pulled.
  systemd.services.invidious-companion-update = {
    description = "Pull latest invidious-companion image and restart it";
    after    = [ "network-online.target" ];
    wants    = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "invidious-companion-update" ''
        ${pkgs.podman}/bin/podman pull quay.io/invidious/invidious-companion:latest
        pulled=$?
        ${pkgs.systemd}/bin/systemctl restart podman-invidious-companion.service
        exit $pulled
      '';
    };
  };

  systemd.timers.invidious-companion-update = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "04:00";
      Persistent = true;
    };
  };
}
