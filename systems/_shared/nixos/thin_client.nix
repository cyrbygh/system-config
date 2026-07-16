{ config, lib, pkgs, ... }:

let
  # The cage session runs swayidle next to moonlight so the machine suspends after a stretch
  # with no local input, for example once the stream drops and nobody is around. moonlight
  # inhibits idle while actively streaming and cage forwards that to the idle notifier, so this
  # only fires when the stream is idle. exec hands the foreground to moonlight so cage exits
  # with it.
  session = pkgs.writeShellScript "thin-client-session" ''
    ${pkgs.swayidle}/bin/swayidle -w timeout 120 '${pkgs.systemd}/bin/systemctl suspend' &
    exec ${pkgs.moonlight-qt}/bin/moonlight
  '';
in
{
  # Cage needs a render device, so pull in the graphics stack. Systems built on top of this
  # base can append hardware specific drivers via hardware.graphics.extraPackages.
  hardware.graphics.enable = true;

  # Audio for the moonlight session.
  services.pipewire = {
    enable = true;
    pulse.enable = true;
  };

  # Keep the tuigreet login prompt, but drop the user straight into the cage session once they
  # authenticate. Cage's -d drops client side decorations and -s allows VT switching.
  services.greetd.settings.default_session.command =
    "${pkgs.tuigreet}/bin/tuigreet --time --cmd '${pkgs.cage}/bin/cage -d -s -- ${session}'";

  # Cage relies on polkit to authorize VT switching.
  security.polkit.enable = true;

  # Suspend on a short power button press rather than powering off. Since moonlight grabs the
  # keyboard, the power button is the only practical local sleep and wake control. IdleAction
  # covers the greetd prompt, which the session's swayidle does not, so a client left sitting
  # at the greeter still suspends.
  services.logind.settings.Login = {
    HandlePowerKey = "suspend";
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
      ExecStart = "-${pkgs.procps}/bin/pkill -x cage";
    };
  };

  environment.systemPackages = lib.mkAfter (with pkgs; [
    cage
    moonlight-qt
  ]);
}
