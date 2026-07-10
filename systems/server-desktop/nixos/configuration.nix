{ config, lib, pkgs, ... }:

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

  programs.sway = {
    enable = true;
    wrapperFeatures.gtk = true;
    extraSessionCommands = ''
      export WLR_BACKENDS=headless
      export WLR_RENDERER=pixman
      export PATH=/run/current-system/sw/bin:/run/wrappers/bin:$PATH
    '';
  };

  services.sunshine.enable = true;

  # Necessary for remote input to work with sunshine.
  # Proxmox host must pass through /dev/uinput to the container.
  hardware.uinput.enable = true;

  users.users.muser = {
    extraGroups = lib.mkAfter [
      "cdrom"
      "dialout"
      "docker"
      "uinput"
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
