{ config, lib, pkgs, ... }:

let
  # The cage session runs swayidle next to moonlight so the machine suspends after a stretch
  # with no local input, for example once the stream drops and nobody is around. moonlight
  # inhibits idle while actively streaming and cage forwards that to the idle notifier, so this
  # only fires when the stream is idle. swayidle is killed when moonlight exits so cage loses
  # its last Wayland client and exits, returning to the greetd login prompt.
  session = pkgs.writeShellScript "thin-client-session" ''
    ${pkgs.swayidle}/bin/swayidle -w timeout 120 '${pkgs.systemd}/bin/systemctl suspend' &
    swayidle_pid=$!
    # PipeWire takes a moment to finish device enumeration after login. SDL3 crashes
    # (SIGSEGV in pthread_mutex_lock via SDL_AudioDeviceDisconnected_OnMainThread) if an
    # audio device disconnect event fires while Moonlight is initializing the EGL renderer.
    # Wait until PipeWire accepts connections before launching.
    until ${pkgs.pipewire}/bin/pw-cli info >/dev/null 2>&1; do
      sleep 0.2
    done
    ${pkgs.moonlight-qt}/bin/moonlight
    kill "$swayidle_pid"
  '';

  # Registers the cage+moonlight session alongside sway.desktop in the tuigreet session picker.
  moonlightSession = pkgs.writeTextDir "share/wayland-sessions/moonlight.desktop" ''
    [Desktop Entry]
    Name=Moonlight
    Comment=Stream gaming session
    Exec=${pkgs.cage}/bin/cage -d -s -- ${session}
    Type=Application
  '';
in
{
  imports = [
    ./base.nix
    ./sway.nix
  ];

  # Cage needs a render device, so pull in the graphics stack. Systems built on top of this
  # base can append hardware specific drivers via hardware.graphics.extraPackages.
  hardware.graphics.enable = true;

  # Audio for the moonlight session.
  services.pipewire = {
    enable = true;
    pulse.enable = true;
  };

  # Session picker: moonlight (cage) or sway desktop. Both .desktop files land in
  # /run/current-system/sw/share/wayland-sessions via environment.systemPackages.
  services.greetd.settings.default_session.command =
    "${pkgs.tuigreet}/bin/tuigreet --time --kb-power 4 --sessions /run/current-system/sw/share/wayland-sessions";

  # Cage relies on polkit to authorize VT switching.
  security.polkit.enable = true;

  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
  };

  # Authorize personal-server's key so it can SSH in.
  users.users.muser.openssh.authorizedKeys.keyFiles = [
    ../../personal-server/ssh/id_ed25519.pub
  ];

  # IdleAction covers the greetd prompt, which the session's swayidle does not, so a client
  # left sitting at the greeter still suspends.
  services.logind.settings.Login = {
    IdleAction = "suspend";
    IdleActionSec = "2min";
  };

  # Keep a bumped mouse or stray keypress from resuming the machine. Wake it with the power
  # button instead.
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="usb", ATTR{power/wakeup}="disabled"
  '';

  # Tear down the cage session as the machine sleeps so it wakes at the greetd login prompt
  # rather than resuming the old moonlight session. greetd returns to the greeter once the
  # session exits, and killing cage takes its moonlight child with it. The leading dash
  # ignores a nonzero exit when no session is running.
  systemd.services.reset-session-on-sleep = {
    before = [ "sleep.target" ];
    wantedBy = [ "sleep.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "-${pkgs.procps}/bin/pkill -KILL -f 'cage -d -s'";
    };
  };

  # Skip the seatd backend (no daemon) so libseat goes straight to logind without flashing errors on screen.
  environment.variables.LIBSEAT_BACKEND = "logind";

  environment.systemPackages = lib.mkAfter (with pkgs; [
    cage
    moonlight-qt
    moonlightSession
  ]);

  home-manager.sharedModules = [
    ../home/base.nix
    ../home/nixos.nix
    {
      home.stateVersion = "26.05";

      home.file = {
        ".config/sway/config".source = ../sway;
        ".config/waybar".source      = ../waybar;
        ".config/mako/config".source = ../mako.conf;
      };

      # foot uses TERM=foot; remote hosts rarely have its terminfo, so force a
      # universally supported value for SSH sessions.
      programs.ssh = {
        enable = true;
        enableDefaultConfig = false;
        settings."*".SetEnv = { TERM = "xterm-256color"; };
      };
    }
  ];
}
