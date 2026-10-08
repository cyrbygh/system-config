{ config, lib, pkgs, ... }:

let
  ollama = config.services.ollama;
in
{
  # infra VLAN only; deliberately not behind Traefik.
  services.open-webui = {
    enable = true;
    host = "10.215.20.1";
    port = 8090;
    environment = {
      SCARF_NO_ANALYTICS = "True";
      DO_NOT_TRACK = "True";
      ANONYMIZED_TELEMETRY = "False";
      OLLAMA_BASE_URL = "http://${ollama.host}:${toString ollama.port}";
      WEBUI_URL = "http://10.215.20.1:8090";
    };
  };

  systemd.services.open-webui = {
    wants = [ "ollama.service" ];
    after = [ "ollama.service" ];
  };
}
