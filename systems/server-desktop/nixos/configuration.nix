{ config, lib, pkgs, ... }:

let
  # Background color swaylock shows while locked.
  lockColor = "34495e";

  # Resize the headless output to the connecting Moonlight client, matching refresh
  # rate when sunshine provides one.
  resizeToClient = pkgs.writeShellScript "sunshine-resize-to-client" ''
    if [ -n "$SUNSHINE_CLIENT_FPS" ]; then
      ${pkgs.sway}/bin/swaymsg output HEADLESS-1 mode "$SUNSHINE_CLIENT_WIDTH"x"$SUNSHINE_CLIENT_HEIGHT"@"$SUNSHINE_CLIENT_FPS"Hz
    else
      ${pkgs.sway}/bin/swaymsg output HEADLESS-1 resolution "$SUNSHINE_CLIENT_WIDTH"x"$SUNSHINE_CLIENT_HEIGHT"
    fi
    sleep 0.5
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

  # Wiring shared by every service that belongs to the sway graphical session.
  mkSessionService = description: execStart: {
    inherit description;
    partOf = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    wantedBy = [ "graphical-session.target" ];
    serviceConfig = {
      ExecStart = execStart;
      Restart = "on-failure";
    };
  };
in
{
  imports =
    [
      ./hardware-configuration.nix
      ../../_shared/nixos/configuration.nix
    ];

  networking.hostName = "server-desktop";

  # proxmox-lxc.nix sets boot.isContainer = true but the shared config enables
  # systemd-boot, which conflicts.
  boot.loader.systemd-boot.enable = lib.mkForce false;
  boot.loader.efi.canTouchEfiVariables = lib.mkForce false;

  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [ intel-media-driver ];
  };

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

  xdg = {
    portal = {
      config.common.default = "*";
      enable = true;
      extraPortals = [
        pkgs.xdg-desktop-portal-wlr
        pkgs.xdg-desktop-portal-gtk
      ];
    };
  };

  fonts.packages = with pkgs; [
    font-awesome
    noto-fonts
    noto-fonts-color-emoji
  ];

  environment.variables = {
    GTK_THEME = "Adwaita-dark";
  };

  # greetd requires VT/KMS ioctls which LXC containers don't support.
  services.greetd.enable = lib.mkForce false;

  # Linger starts muser's systemd instance at boot, which creates
  # XDG_RUNTIME_DIR and runs user services (pam_systemd fails in this container).
  users.users.muser.linger = true;

  systemd.user.services.sway = {
    wantedBy = [ "default.target" ];
    serviceConfig = {
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

  # seatd gives the libinput backend a way to open /dev/input/* without logind,
  # which doesn't work in an LXC container.
  services.seatd.enable = true;

  programs.sway = {
    enable = true;
    wrapperFeatures.gtk = true;
    extraSessionCommands = ''
      export WLR_BACKENDS=headless,libinput
      export WLR_RENDER_DRM_DEVICE=/dev/dri/renderD128
      export PATH=/run/current-system/sw/bin:/run/wrappers/bin:$PATH
    '';
  };

  services.sunshine = {
    enable = true;
    # Runs for every stream, including the built-in Desktop. do resizes the output to the
    # client; undo locks the session on disconnect so the next client hits a password prompt.
    settings.global_prep_cmd = builtins.toJSON [
      {
        do = "${resizeToClient}";
        undo = "${lockSession}";
      }
    ];
  };

  users.users.muser = {
    extraGroups = lib.mkAfter [
      "cdrom"
      "dialout"
      "docker"
      "input"  # Needed for libinput to open /dev/input/* devices.
      "render"
      "seat"   # Needed for seatd access.
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

  services.openssh.enable = true;
  services.avahi.enable = true;

  services.printing.enable = true;

  virtualisation.docker.enable = true;
  virtualisation.docker.rootless = {
    enable = true;
    setSocketVariable = true;
  };

  system.stateVersion = "26.05";
}
