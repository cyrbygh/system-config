{ config, lib, pkgs, ... }:

{
  age.secrets.traefik-acme-email = {
    file = ../../secrets/traefik-acme-email.age;
    mode = "0400";
    owner = "traefik";
  };

  services.traefik = {
    enable = true;

    staticConfigOptions = {
      entryPoints = {
        web = {
          address = ":80";
          http.redirections.entryPoint = { to = "websecure"; scheme = "https"; permanent = true; };
        };
        websecure.address = ":443";
      };
      certificatesResolvers.letsencrypt.acme = {
        # Email is set via TRAEFIK_CERTIFICATESRESOLVERS_LETSENCRYPT_ACME_EMAIL
        # in the agenix-managed EnvironmentFile — kept out of the public repo.
        storage = "/var/lib/traefik/acme.json";
        httpChallenge.entryPoint = "web";
      };
    };
  };

  systemd.services.traefik.serviceConfig.EnvironmentFile = config.age.secrets.traefik-acme-email.path;
}
