{ lib, pkgs, ... }:

let
  # programs.sway.enable wraps only the binary; the package's share/wayland-sessions/
  # directory is not carried over. Create the session file explicitly so tuigreet can
  # discover it alongside moonlight.desktop.
  swaySession = pkgs.writeTextDir "share/wayland-sessions/sway.desktop" ''
    [Desktop Entry]
    Name=Sway
    Comment=An i3-compatible Wayland compositor
    Exec=sway
    Type=Application
    DesktopNames=sway;wlroots
  '';
in
{
  programs.sway = {
    enable = true;
    wrapperFeatures.gtk = true;
  };

  # swaylock authenticates via PAM; without this it can never unlock.
  security.pam.services.swaylock = { };

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

  # Ensure share/wayland-sessions/ from all packages is linked into the system profile
  # so tuigreet can discover sessions at /run/current-system/sw/share/wayland-sessions/.
  environment.pathsToLink = [ "/share/wayland-sessions" ];

  environment.systemPackages = lib.mkAfter (with pkgs; [
    foot
    fuzzel
    gnome-themes-extra
    libnotify
    mako
    swayidle
    swaylock
    swaySession
    waybar
  ]);
}
