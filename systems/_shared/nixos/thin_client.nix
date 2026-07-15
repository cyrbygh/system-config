{ config, lib, pkgs, ... }:

{
  # Cage needs a render device, so pull in the graphics stack. Systems built on top of this
  # base can append hardware specific drivers via hardware.graphics.extraPackages.
  hardware.graphics.enable = true;

  # Audio for the moonlight session.
  services.pipewire = {
    enable = true;
    pulse.enable = true;
  };

  # Keep the tuigreet login prompt, but drop the user straight into a cage session running
  # moonlight once they authenticate. Cage's -d drops client side decorations and -s allows
  # VT switching.
  services.greetd.settings.default_session.command =
    "${pkgs.tuigreet}/bin/tuigreet --time --cmd '${pkgs.cage}/bin/cage -d -s -- ${pkgs.moonlight-qt}/bin/moonlight'";

  # Cage relies on polkit to authorize VT switching.
  security.polkit.enable = true;

  environment.systemPackages = lib.mkAfter (with pkgs; [
    cage
    moonlight-qt
  ]);
}
