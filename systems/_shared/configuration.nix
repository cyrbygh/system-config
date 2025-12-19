{ config, lib, pkgs, ... }:

{
  boot = {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
  };

  networking = {
    useNetworkd = true;
    firewall.enable = false;
  };

  systemd.network.wait-online.enable = true;

  fonts.packages = with pkgs; [
    font-awesome
    noto-fonts
    noto-fonts-emoji
  ];

  time.timeZone = "America/Los_Angeles";

  i18n.defaultLocale = "en_US.UTF-8";

  services = {
    pipewire = {
      enable = true;
      pulse.enable = true;
    };
    greetd = {
      enable = true;
      settings = {
        default_session = {
          command = lib.mkDefault "${pkgs.greetd.tuigreet}/bin/tuigreet --time --cmd sway";
          user = lib.mkDefault "greeter";
        };
      };
    };
    flatpak = {
      enable = true;
    };
  };

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

  users.users.muser = {
    isNormalUser = true;
    extraGroups = [ "wheel" ]; # Enable ‘sudo’ for the user.
    shell = pkgs.zsh;
    home = "/home/muser";
    uid = 1000;
  };

  environment.variables = {
    GTK_THEME = "Awaita-dark";
  };
  environment.systemPackages = with pkgs; [
    fuzzel
    git
    gnome-themes-extra # Needed to persuade apps into dark mode.
    htop
    libnotify
    firefox
    mako
    pavucontrol
    tree
    unzip
    usbutils
    vim
    waybar
    wget
    xz
  ];

  programs = {
    sway = {
      enable = true;
      wrapperFeatures.gtk = true;
    };
    zsh.enable = true;
  };
}
