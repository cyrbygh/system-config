{ config, lib, pkgs, ... }:

let
  # Main streams, pulled once by go2rtc and restreamed locally to Frigate's record
  # role and live view. go2rtc expands ${VAR} from its environment (Frigate uses
  # {VAR} instead, see the detect inputs below).
  mainStreams = {
    cam-1 = "rtsp://admin:\${FRIGATE_RTSP_PASSWORD}@10.215.40.10:554/Streaming/Channels/101"; # Hikvision
    cam-2 = "rtsp://admin:\${FRIGATE_RTSP_PASSWORD}@10.215.40.11:554/cam/realmonitor?channel=1&subtype=0"; # Amcrest
    cam-3 = "rtsp://cadmin:\${FRIGATE_RTSP_PASSWORD}@10.215.40.12:554/stream1"; # Tapo
    cam-4 = "rtsp://cadmin:\${FRIGATE_RTSP_PASSWORD}@10.215.40.13:554/stream1"; # Tapo
  };

  restream = name: "rtsp://127.0.0.1:8554/${name}";

  recordInput = name: {
    path = restream name;
    input_args = "preset-rtsp-restream";
    roles = [ "record" ];
  };
in
{
  # FRIGATE_RTSP_PASSWORD, read by systemd (as root) before it drops privileges -
  # shared password across all four cameras. Usernames aren't secret, so they're
  # hardcoded per-camera instead.
  age.secrets.frigate-rtsp-credentials = {
    file = ../../secrets/frigate-rtsp-credentials.age;
    owner = "root";
    mode = "0400";
  };

  systemd.services.frigate.serviceConfig.EnvironmentFile =
    config.age.secrets.frigate-rtsp-credentials.path;

  systemd.services.go2rtc.serviceConfig.EnvironmentFile =
    config.age.secrets.frigate-rtsp-credentials.path;

  systemd.services.frigate.wants = [ "go2rtc.service" ];

  # The module defaults all three listeners to every interface. API and RTSP are
  # only used by nginx and Frigate locally; WebRTC is off, so live view uses MSE
  # over the existing nginx vhost and nothing new is exposed.
  services.go2rtc = {
    enable = true;
    settings = {
      api.listen = "127.0.0.1:1984";
      rtsp.listen = "127.0.0.1:8554";
      webrtc.listen = "";
      streams = mainStreams;
    };
  };

  # Frigate only unlinks its /dev/shm frame buffers on a clean exit, and reattaches
  # to an existing buffer without checking its size. Leftovers from a killed run
  # sized for an old detect resolution make every frame read fail. (Docker gets a
  # fresh /dev/shm per container, so upstream never hits this.)
  systemd.services.frigate.serviceConfig.ExecStartPre = lib.mkBefore [
    "${pkgs.findutils}/bin/find /dev/shm -maxdepth 1 -user frigate -delete"
  ];

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

      # No GPU index needed: Frigate picks among render nodes that pass vainfo, and
      # with LIBVA_DRIVER_NAME=iHD (vaapiDriver above) only the Intel node does.
      ffmpeg.hwaccel_args = "preset-vaapi";

      record = {
        enabled = true;
        retain.days = 7;
      };

      # Frigate only checks these names exist (each camera's live view defaults to
      # the go2rtc stream of the same name); the real sources live in go2rtc above.
      go2rtc.streams = lib.mapAttrs (name: _: restream name) mainStreams;

      # Detect pulls each camera's substream directly - detection doesn't need full
      # resolution, and it keeps decode load on the iGPU low.
      cameras = {
        cam-1.ffmpeg.inputs = [
          {
            path = "rtsp://admin:{FRIGATE_RTSP_PASSWORD}@10.215.40.10:554/Streaming/Channels/102";
            roles = [ "detect" ];
          }
          (recordInput "cam-1")
        ];
        cam-2.ffmpeg.inputs = [
          {
            path = "rtsp://admin:{FRIGATE_RTSP_PASSWORD}@10.215.40.11:554/cam/realmonitor?channel=1&subtype=1";
            roles = [ "detect" ];
          }
          (recordInput "cam-2")
        ];
        cam-3.ffmpeg.inputs = [
          {
            path = "rtsp://cadmin:{FRIGATE_RTSP_PASSWORD}@10.215.40.12:554/stream2";
            roles = [ "detect" ];
          }
          (recordInput "cam-3")
        ];
        cam-4.ffmpeg.inputs = [
          {
            path = "rtsp://cadmin:{FRIGATE_RTSP_PASSWORD}@10.215.40.13:554/stream2";
            roles = [ "detect" ];
          }
          (recordInput "cam-4")
        ];
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
