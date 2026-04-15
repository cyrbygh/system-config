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

  time.timeZone = "America/Los_Angeles";

  i18n.defaultLocale = "en_US.UTF-8";

  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = lib.mkDefault "${pkgs.tuigreet}/bin/tuigreet --time";
        user = lib.mkDefault "greeter";
      };
    };
  };

  users.users.muser = {
    isNormalUser = true;
    extraGroups = [ "wheel" ]; # Enable ‘sudo’ for the user.
    shell = pkgs.zsh;
    home = "/home/muser";
    uid = 1000;
  };

  environment.systemPackages = with pkgs; [
    age
    git
    htop
    tree
    unzip
    usbutils
    vim
    wget
    xz
  ];

  programs.zsh.enable = true;
}
