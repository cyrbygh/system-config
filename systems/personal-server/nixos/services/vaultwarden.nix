{ config, lib, pkgs, ... }:

{
  services.vaultwarden = {
    enable = true;
    dbBackend = "postgresql";
    config = {
      ROCKET_ADDRESS  = "0.0.0.0";
      ROCKET_PORT     = 8000;
      SIGNUPS_ALLOWED = false;
      DATABASE_URL    = "postgresql:///vaultwarden?host=/run/postgresql";
    };
  };

  # Vaultwarden doesn't auto-detect postgres ordering; declare it explicitly.
  systemd.services.vaultwarden = {
    after    = [ "postgresql.service" ];
    requires = [ "postgresql.service" ];
  };
}
