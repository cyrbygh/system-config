{ config, lib, pkgs, ... }:

{
  imports =
    [
      ./hardware-configuration.nix
      ../../_shared/configuration.nix
    ];

  networking.hostName = "office-desktop";

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

  services.greetd.settings.default_session.command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --cmd sway";

  # Necessary for remote input to work with sunshine.
  hardware.uinput.enable = true;

  users.users.muser = {
    extraGroups = lib.mkAfter [
      "cdrom"
      "dialout"
      "docker"
      "uinput"
    ];
  };

  environment.systemPackages = lib.mkAfter (with pkgs; [
    chromium
    firefox
    fuzzel
    gnome-themes-extra # Needed to persuade apps into dark mode.
    kitty
    libnotify
    mako
    pavucontrol
    sway
    vlc
    waybar
    xwayland-satellite
  ]);

  services.openssh.enable = true;
  services.avahi.enable = true;

  services.syncthing = {
    enable = true;
    group = "users";
    user = "muser";
    dataDir = "/sync/data";
    configDir = "/sync/config";
  };

  services.printing.enable = true;

  services.nfs.server = {
    enable = true;
    exports = ''
      /home/muser/usb-host-share usb-host.inf(rw,sync,no_subtree_check,fsid=0,no_root_squash)
    '';
  };

  systemd.services.nfs-server = {
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
  };

  virtualisation.docker.enable = true;
  virtualisation.docker.rootless = {
    enable = true;
    setSocketVariable = true;
  };

  # Do NOT change this value unless you have manually inspected all the changes it would make to your configuration,
  # and migrated your data accordingly.
  #
  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "24.05"; # Did you read the comment?
}

