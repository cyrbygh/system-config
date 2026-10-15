{ config, lib, pkgs, ... }:

{
  age.secrets.traefik-acme-email = {
    file = ../../secrets/traefik-acme-email.age;
    mode = "0400";
    owner = "traefik";
  };

  # DOMAIN (router rules) and INVIDIOUS_INSTANCE (miniflux).
  age.secrets.domain-env.file = ../../secrets/domain-env.age;

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

  # Router rules read DOMAIN via Traefik's templating: {{ env `DOMAIN` }}.
  systemd.services.traefik.serviceConfig.EnvironmentFile = [
    config.age.secrets.traefik-acme-email.path
    config.age.secrets.domain-env.path
  ];
}
