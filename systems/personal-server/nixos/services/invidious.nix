{ config, lib, pkgs, ... }:

{
  services.invidious = {
    enable = true;
    port   = 3001;
    settings = {
      check_tables = true;
      invidious_companion = [{
        private_url = "http://localhost:8282/companion";
        public_url  = "https://invidious.dillon.io/companion";
      }];
      invidious_companion_key = "3805800f15dd4724";
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
      environment.SERVER_SECRET_KEY = "3805800f15dd4724";
      volumes = [ "/var/lib/invidious-companion:/var/tmp/youtubei.js:rw" ];
      extraOptions = [
        "--cap-drop=ALL"
        "--read-only"
        "--security-opt=no-new-privileges:true"
      ];
    };
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
      DynamicUser    = lib.mkForce false;
      User           = lib.mkForce "invidious";
      Group          = lib.mkForce "invidious";
      StateDirectory = lib.mkForce "invidious";
    };
  };

  systemd.services.invidious-companion-update = {
    description = "Pull latest invidious-companion image and restart if changed";
    after    = [ "network-online.target" ];
    wants    = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "invidious-companion-update" ''
        old=$(${pkgs.podman}/bin/podman inspect --format '{{.Id}}' quay.io/invidious/invidious-companion:latest 2>/dev/null || true)
        ${pkgs.podman}/bin/podman pull quay.io/invidious/invidious-companion:latest
        new=$(${pkgs.podman}/bin/podman inspect --format '{{.Id}}' quay.io/invidious/invidious-companion:latest 2>/dev/null || true)
        if [ -n "$new" ] && [ "$old" != "$new" ]; then
          ${pkgs.systemd}/bin/systemctl restart podman-invidious-companion.service
        fi
      '';
    };
  };

  systemd.timers.invidious-companion-update = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
    };
  };
}
