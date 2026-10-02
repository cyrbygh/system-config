{ config, lib, pkgs, ... }:

{
  # host networking: container shares host network namespace so Omada sees
  # real interface IPs and APs can connect without DNAT/forwarding issues.
  # Access via https://10.215.20.1:8043/ from infra VLAN or WireGuard.
  virtualisation.oci-containers.containers.omada-controller = {
    image = "mbentley/omada-controller:5.13";
    environment = {
      TZ                = "America/Los_Angeles";
      MANAGE_HTTP_PORT  = "8088";
      MANAGE_HTTPS_PORT = "8043";
      PORTAL_HTTP_PORT  = "8088";
      PORTAL_HTTPS_PORT = "8843";
    };
    extraOptions = [ "--network=host" ];
    volumes = [
      "/var/lib/omada-controller/data:/opt/tplink/EAPController/data"
      "/var/lib/omada-controller/logs:/opt/tplink/EAPController/logs"
      "/var/lib/omada-controller/work:/opt/tplink/EAPController/work"
    ];
  };
}
