{ config, lib, pkgs, ... }:

{
  imports =
    [
      ./hardware-configuration.nix
      ../../_shared/configuration.nix
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

  # Auto-login directly to sway. greetd handles PAM session setup
  # (XDG_RUNTIME_DIR, systemd user manager, loginctl session).
  services.greetd.settings.default_session = {
    command = "${config.programs.sway.package}/bin/sway";
    user = "muser";
  };

  programs.sway = {
    enable = true;
    wrapperFeatures.gtk = true;
    extraSessionCommands = ''
      export WLR_BACKENDS=headless
      export WLR_RENDERER=pixman
    '';
  };

  # Sunshine game streaming.
  # Proxmox host must also mark the container as privileged for cap_sys_admin.
  services.sunshine = {
    enable = true;
    capSysAdmin = true;
  };

  # Necessary for remote input to work with sunshine.
  # Proxmox host must pass through /dev/uinput and have uinput module loaded.
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
