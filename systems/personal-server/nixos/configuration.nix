{ config, lib, pkgs, ... }:

let
  # Background color swaylock shows while locked.
  lockColor = "34495e";

  # Resolved by PCI vendor ID, not a hardcoded renderD path - this box has multiple
  # GPUs and render-node enumeration order isn't guaranteed across reboots.
  findAmdRenderNode = pkgs.writeShellScript "find-amd-render-node" ''
    for node in /dev/dri/renderD*; do
      name=$(basename "$node")
      if [ "$(cat "/sys/class/drm/$name/device/vendor" 2>/dev/null)" = "0x1002" ]; then
        echo "$node"
        exit 0
      fi
    done
    exit 1
  '';

  # The infra VLAN is a static-IP interface excluded from network-online.target
  # (networking.nix only waits on wan), so nothing otherwise stops sunshine from
  # starting before its bind address exists, which fails as a one-shot bind()
  # with no retry.
  waitForBindAddress = pkgs.writeShellScript "wait-for-sunshine-bind-address" ''
    until ${pkgs.iproute2}/bin/ip -4 addr show | grep -q "inet ${config.services.sunshine.settings.bind_address}/"; do
      sleep 0.2
    done
  '';

  # Resize the headless output to the connecting Moonlight client, matching refresh
  # rate when sunshine provides one. Scale 2 at 1440p or higher, otherwise 1.
  resizeToClient = pkgs.writeShellScript "sunshine-resize-to-client" ''
    if [ -n "$SUNSHINE_CLIENT_FPS" ]; then fps="@''${SUNSHINE_CLIENT_FPS}Hz"; fi
    if [ "$SUNSHINE_CLIENT_HEIGHT" -ge 1440 ]; then scale=2; else scale=1; fi
    ${pkgs.sway}/bin/swaymsg output HEADLESS-1 resolution "$SUNSHINE_CLIENT_WIDTH"x"$SUNSHINE_CLIENT_HEIGHT''${fps}" scale "$scale"
  '';

  # Lock the session on disconnect unless it is already locked. Moonlight pairing is the
  # only other gate, so this leaves a password prompt behind for the next client.
  lockSession = pkgs.writeShellScript "sunshine-lock" ''
    ${pkgs.procps}/bin/pgrep -x swaylock > /dev/null || ${pkgs.swaylock}/bin/swaylock -f -c ${lockColor}
  '';

  # swayidle locks after a short idle and blanks the headless output after a longer one.
  swayidleCmd = pkgs.writeShellScript "swayidle-session" ''
    exec ${pkgs.swayidle}/bin/swayidle \
      timeout 60 '${pkgs.swaylock}/bin/swaylock -f -c ${lockColor}' \
      timeout 120 '${pkgs.sway}/bin/swaymsg "output * dpms off"' \
      resume '${pkgs.sway}/bin/swaymsg "output * dpms on"'
  '';

  # greetd (tty1/PiKVM console) gets stopped for the duration of a stream, since
  # sunshine's uinput input reaches the active VT regardless of seat boundaries.
  # Needs sudo (see security.sudo.extraRules below): greetd.service is a system
  # unit, sunshine.service is a user unit running as plain muser.
  startConsoleLogin = pkgs.writeShellScript "sunshine-start-console-login" ''
    ${pkgs.sudo}/bin/sudo ${pkgs.systemd}/bin/systemctl start greetd.service
  '';
  stopConsoleLogin = pkgs.writeShellScript "sunshine-stop-console-login" ''
    ${pkgs.sudo}/bin/sudo ${pkgs.systemd}/bin/systemctl stop greetd.service
  '';

  # Wiring shared by every service that belongs to the sway graphical session.
  # systemd.user.services installs a system-wide template available to *any*
  # user's systemd --user manager, not just muser's - ConditionUser prevents it
  # from also spinning up under root/greeter if they ever have a lingering user
  # session reach default.target/graphical-session.target.
  mkSessionService = description: execStart: {
    inherit description;
    partOf = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    wantedBy = [ "graphical-session.target" ];
    unitConfig.ConditionUser = "muser";
    serviceConfig = {
      ExecStart = execStart;
      Restart = "on-failure";
    };
  };
in
{
  imports = [
    ./hardware-configuration.nix
    ../../_shared/nixos/base.nix
    ./networking.nix
    ./services/postgres.nix
    ./services/miniflux.nix
    ./services/vaultwarden.nix
    ./services/invidious.nix
    ./services/scrypted.nix
    ./services/wireguard.nix
    ./services/traefik.nix
    ./services/mosquitto.nix
    ./services/zwave-js.nix
    ./services/zigbee2mqtt.nix
    ./services/gonic.nix
    ./services/jellyfin.nix
    ./services/home-assistant.nix
    ./services/nut.nix
    ./services/omada-controller.nix
    ./sensitive.nix
  ];

  networking.hostName = "personal-server";
  networking.hostId = "49377d88";

  systemd.network.links."10-tr0" = {
    matchConfig.MACAddress = "a8:a1:59:be:11:78";
    linkConfig.Name = "tr0";
  };

  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
  };

  age.secrets.ssh-key = {
    file = ../secrets/ssh-key.age;
    path = "/home/muser/.ssh/id_ed25519";
    owner = "muser";
    mode = "0600";
  };

  users.users.muser.openssh.authorizedKeys.keyFiles = [
    ../../thin-1/ssh/id_ed25519.pub
    ../../thin-2/ssh/id_ed25519.pub
  ];

  users.users.root.openssh.authorizedKeys.keyFiles = [
    ../../thin-2/ssh/id_ed25519.pub
  ];

  # ── Headless sway + Sunshine (Moonlight game streaming) ───────────────────

  hardware.graphics.enable = true;

  # amdgpu is in-kernel but loads its microcode from linux-firmware at probe time.
  hardware.enableRedistributableFirmware = true;

  services.pipewire = {
    enable = true;
    pulse.enable = true;
  };

  services.flatpak.enable = true;

  system.activationScripts.addFlathub = {
    text = ''
      ${pkgs.flatpak}/bin/flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo || true
    '';
  };

  xdg.portal = {
    config.common.default = "*";
    enable = true;
    extraPortals = [
      pkgs.xdg-desktop-portal-wlr
      pkgs.xdg-desktop-portal-gtk
    ];
  };

  fonts.packages = with pkgs; [
    font-awesome
    noto-fonts
    noto-fonts-color-emoji
  ];

  environment.variables = {
    GTK_THEME = "Adwaita-dark";
  };

  # Linger starts muser's systemd instance at boot, which creates XDG_RUNTIME_DIR
  # and runs user services without requiring an interactive login.
  users.users.muser.linger = true;

  systemd.user.services.sway = {
    wantedBy = [ "default.target" ];
    unitConfig.ConditionUser = "muser";
    serviceConfig = {
      # amdgpu can finish probing after this user service would otherwise start. Without
      # the render node, sway silently falls back to the pixman software renderer, which
      # only exports SHM and breaks sunshine's dmabuf capture. Wait for the node first.
      ExecStartPre = "${pkgs.coreutils}/bin/timeout 30 ${pkgs.bash}/bin/sh -c 'until ${findAmdRenderNode} >/dev/null 2>&1; do sleep 0.2; done'";
      ExecStart = "${config.programs.sway.package}/bin/sway";
      Restart = "on-failure";
    };
  };

  # sway is the only compositor on this machine, so graphical-session.target's
  # RefuseManualStart restriction serves no purpose here. Override it so sway's
  # config can start the target directly. bindsTo sway.service so the whole
  # session tears down when sway stops or restarts.
  systemd.user.targets.graphical-session = {
    overrideStrategy = "asDropin";
    unitConfig.RefuseManualStart = false;
    bindsTo = [ "sway.service" ];
    after = [ "sway.service" ];
  };

  # Session helpers. Each waits for graphical-session.target, so WAYLAND_DISPLAY and
  # SWAYSOCK have already been imported, and stops with it.
  systemd.user.services.swayidle = mkSessionService "Idle locking and output blanking" "${swayidleCmd}";
  systemd.user.services.mako = mkSessionService "Notification daemon" "${pkgs.mako}/bin/mako";
  systemd.user.services.waybar = mkSessionService "Status bar" "${pkgs.waybar}/bin/waybar";

  # swaylock authenticates via PAM; without this service definition it can never unlock.
  security.pam.services.swaylock = { };

  programs.sway = {
    enable = true;
    wrapperFeatures.gtk = true;
    extraSessionCommands = ''
      export WLR_BACKENDS=headless,libinput
      export WLR_RENDER_DRM_DEVICE="$(${findAmdRenderNode})"
      export LIBSEAT_BACKEND=noop
      export WLR_LIBINPUT_NO_DEVICES=1
      export PATH=/run/current-system/sw/bin:/run/wrappers/bin:$PATH
    '';
  };

  services.sunshine = {
    enable = true;
    # infra VLAN only - already fully trusted by the firewall, no nftables change needed.
    settings.bind_address = "10.215.20.1";
    # Runs on every stream start/stop: resize the output, then stop/start the console login.
    settings.global_prep_cmd = builtins.toJSON [
      {
        do = "${resizeToClient}";
        undo = "${lockSession}";
      }
      {
        do = "${stopConsoleLogin}";
        undo = "${startConsoleLogin}";
      }
    ];
  };

  # Crash-safety backstop: restarts greetd if sunshine dies mid-stream before undo runs.
  # ConditionUser guards against this template also starting under root/greeter's own
  # lingering user sessions (see mkSessionService above for why).
  systemd.user.services.sunshine = {
    unitConfig.ConditionUser = "muser";
    serviceConfig = {
      ExecStartPre = "${pkgs.coreutils}/bin/timeout 30 ${waitForBindAddress}";
      ExecStopPost = "${startConsoleLogin}";
    };
  };

  security.sudo.extraRules = [
    {
      users = [ "muser" ];
      commands = [
        { command = "${pkgs.systemd}/bin/systemctl start greetd.service"; options = [ "NOPASSWD" ]; }
        { command = "${pkgs.systemd}/bin/systemctl stop greetd.service"; options = [ "NOPASSWD" ]; }
      ];
    }
  ];

  users.users.muser = {
    extraGroups = lib.mkAfter [
      "input"  # Needed for libinput to open /dev/input/* devices.
      "render"
      "uinput" # Needed for sunshine remote input.
      "video"
    ];
  };

  nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
    "claude-code"
  ];

  environment.systemPackages = lib.mkAfter (with pkgs; [
    claude-code
    fuzzel
    gnome-themes-extra
    kitty
    libnotify
    mako
    pavucontrol
    ungoogled-chromium
    vlc
    waybar
    xwayland-satellite
  ]);

  services.avahi.enable = true;

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users.muser = {
      home.stateVersion = "26.05";

      imports = [
        ../../_shared/home/base.nix
        ../../_shared/home/nixos.nix
      ];

      home.file = {
        ".ssh/id_ed25519.pub".source      = ../ssh/id_ed25519.pub;
        ".config/sway/config".source      = ../sway;
        ".config/waybar".source           = ../../_shared/waybar;
        ".config/kitty/kitty.conf".source = ../../_shared/kitty.conf;
        ".config/mako/config".source      = ../../_shared/mako.conf;
      };

      programs.zsh = {
        shellAliases = {
          icat = "kitty +kitten icat --align left";
          vcat = "mpv --vo=kitty";
        };
        initContent = ''
          export XDG_DATA_DIRS="$XDG_DATA_DIRS:/var/lib/flatpak/exports/share/applications/"
        '';
      };
    };
  };

  system.stateVersion = "26.05";
}
