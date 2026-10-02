{ config, lib, pkgs, ... }:

{
  virtualisation.oci-containers.containers.omada-controller = {
    image = "mbentley/omada-controller:5.13";
    environment = {
      TZ                = "America/Los_Angeles";
      MANAGE_HTTP_PORT  = "8088";
      MANAGE_HTTPS_PORT = "8043";
      PORTAL_HTTP_PORT  = "8088";
      PORTAL_HTTPS_PORT = "8843";
    };
    ports = [
      "127.0.0.1:8088:8088"   # HTTP management (Traefik backend)
      "127.0.0.1:8043:8043"   # HTTPS management (Traefik backend)
      "10.215.20.1:29810:29810/udp"  # AP discovery
      "10.215.20.1:29811:29811"      # AP management v1
      "10.215.20.1:29812:29812"      # AP adoption
      "10.215.20.1:29813:29813"      # AP upgrade
      "10.215.20.1:29814:29814"      # AP management v2
      "10.215.20.1:29815:29815"      # AP transfer v2
      "10.215.20.1:29816:29816"      # RTTY
      "10.215.20.1:27001:27001/udp"  # App discovery
    ];
    volumes = [
      "/var/lib/omada-controller/data:/opt/tplink/EAPController/data"
      "/var/lib/omada-controller/logs:/opt/tplink/EAPController/logs"
      "/var/lib/omada-controller/work:/opt/tplink/EAPController/work"
    ];
  };

  # Traefik proxies to the Omada HTTPS backend; Omada uses a self-signed cert
  # so we skip verification on the backend connection.
  services.traefik.dynamicConfigOptions.http = {
    routers.omada = {
      rule        = "Host(`omada.dillon.io`)";
      entryPoints = [ "websecure" ];
      service     = "omada";
      tls.certResolver = "letsencrypt";
    };
    services.omada.loadBalancer = {
      servers          = [{ url = "https://localhost:8043"; }];
      serversTransport = "omada-insecure";
    };
    serversTransports.omada-insecure.insecureSkipVerify = true;
  };
}
