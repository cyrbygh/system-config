{ config, lib, pkgs, ... }:

{
  # Intel iGPU is otherwise idle (sway/sunshine use the AMD 6700XT) - used here for
  # both ffmpeg decode (VAAPI) and detection (OpenVINO targeting the same GPU device).
  hardware.graphics.extraPackages = with pkgs; [ intel-media-driver ];

  # FRIGATE_RTSP_PASSWORD below, read by systemd (as root) before it drops
  # privileges to the frigate user - shared password across all four cameras.
  # Usernames aren't secret, so they're hardcoded per-camera instead.
  age.secrets.frigate-rtsp-credentials = {
    file = ../../secrets/frigate-rtsp-credentials.age;
    owner = "root";
    mode = "0400";
  };

  systemd.services.frigate.serviceConfig.EnvironmentFile =
    config.age.secrets.frigate-rtsp-credentials.path;

  services.frigate = {
    enable = true;
    hostname = "frigate.infra";
    # The model/labelmap paths only exist on the live host (see comment below),
    # not in the build sandbox, so the build-time config check can't open them.
    checkConfig = false;
    vaapiDriver = "iHD";

    settings = {
      mqtt = {
        enabled = true;
        host = "127.0.0.1";
        port = 1883;
      };

      detectors.ov = {
        type = "openvino";
        device = "GPU";
      };

      # Not bundled by the nixpkgs package. Expected to already exist at
      # /var/lib/frigate/model/{ssdlite_mobilenet_v2.xml,.bin,coco_91cl_bkgr.txt} -
      # that's part of the backed-up state for this host, not managed here. If it
      # ever needs re-extracting from scratch: those exact three files came from
      # the official ghcr.io/blakeblackshear/frigate:0.17.2 image (manifest
      # sha256:06e48c72f5af2887eafff09a4c53e8df9238827ae9e8df811cbdeaab1c7a4330),
      # at /openvino-model/ in that image.
      model = {
        width = 300;
        height = 300;
        input_tensor = "nhwc";
        input_pixel_format = "bgr";
        path = "/var/lib/frigate/model/ssdlite_mobilenet_v2.xml";
        labelmap_path = "/var/lib/frigate/model/coco_91cl_bkgr.txt";
      };

      ffmpeg.hwaccel_args = "preset-vaapi";

      record = {
        enabled = true;
        retain.days = 7;
      };

      cameras = {
        cam-1 = {
          # Hikvision. Detect runs against the substream (channel 102) - the main
          # stream's 2560x1440 intermittently crashed VAAPI hwdownload ("Failed to
          # sync surface"), and detection doesn't need full resolution anyway.
          ffmpeg.inputs = [
            {
              path = "rtsp://admin:{FRIGATE_RTSP_PASSWORD}@10.215.40.10:554/Streaming/Channels/102";
              roles = [ "detect" ];
            }
            {
              path = "rtsp://admin:{FRIGATE_RTSP_PASSWORD}@10.215.40.10:554/Streaming/Channels/101";
              roles = [ "record" ];
            }
          ];
        };
        cam-2 = {
          # Amcrest (Dahua-licensed firmware, hence the Dahua-style path). Detect
          # runs against the substream (subtype=1) - same reasoning as cam-1.
          ffmpeg.inputs = [
            {
              path = "rtsp://admin:{FRIGATE_RTSP_PASSWORD}@10.215.40.11:554/cam/realmonitor?channel=1&subtype=1";
              roles = [ "detect" ];
            }
            {
              path = "rtsp://admin:{FRIGATE_RTSP_PASSWORD}@10.215.40.11:554/cam/realmonitor?channel=1&subtype=0";
              roles = [ "record" ];
            }
          ];
        };
        cam-3 = {
          # TP-Link Tapo - Camera Account username is "cadmin" here, not "admin"
          # like cam-1/cam-2; password is shared. Detect runs against stream2 (sub).
          ffmpeg.inputs = [
            {
              path = "rtsp://cadmin:{FRIGATE_RTSP_PASSWORD}@10.215.40.12:554/stream2";
              roles = [ "detect" ];
            }
            {
              path = "rtsp://cadmin:{FRIGATE_RTSP_PASSWORD}@10.215.40.12:554/stream1";
              roles = [ "record" ];
            }
          ];
        };
        cam-4 = {
          # TP-Link Tapo - same username/password split and sub/main split as cam-3.
          ffmpeg.inputs = [
            {
              path = "rtsp://cadmin:{FRIGATE_RTSP_PASSWORD}@10.215.40.13:554/stream2";
              roles = [ "detect" ];
            }
            {
              path = "rtsp://cadmin:{FRIGATE_RTSP_PASSWORD}@10.215.40.13:554/stream1";
              roles = [ "record" ];
            }
          ];
        };
      };
    };
  };

  # The module's nginx vhost is the only supported way to reach frigate's otherwise
  # 127.0.0.1-only backend. Pin it to the infra VLAN specifically (already fully
  # trusted by the firewall) and off port 80, since Traefik already wildcard-binds
  # that port for the public-facing services.
  services.nginx.virtualHosts."frigate.infra".listen = lib.mkForce [
    { addr = "10.215.20.1"; port = 8971; }
  ];
}
