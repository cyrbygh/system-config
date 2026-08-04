{ config, lib, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../_shared/nixos/base.nix
  ];

  networking.hostName = "backup-1";

  # BCM4360 needs the out-of-tree wl driver from broadcom_sta (unfree, insecure).
  nixpkgs.config.allowUnfreePredicate  = pkg: lib.getName pkg == "broadcom-sta";
  nixpkgs.config.allowInsecurePredicate = pkg: lib.getName pkg == "broadcom-sta";
  boot.kernelModules = [ "wl" ];
  boot.extraModulePackages = [ config.boot.kernelPackages.broadcom_sta ];

  networking.useNetworkd = false;
  networking.networkmanager.enable = true;
  users.users.muser.extraGroups = [ "networkmanager" ];

  age.identityPaths = [ "/etc/age_key" ];
  age.secrets.wg0-conf = {
    file = ../secrets/wg0-conf.age;
    owner = "root";
    mode = "0400";
  };

  networking.wg-quick.interfaces.wg0.configFile = config.age.secrets.wg0-conf.path;

  systemd.services.wg-quick-wg0 = {
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Restart = "on-failure";
      RestartSec = "5s";
    };
  };

  services.greetd.enable = lib.mkForce false;
  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
    extraConfig = ''
      Match User backup
        PermitTTY no
        AllowTcpForwarding no
        AllowAgentForwarding no
        PermitTunnel no
        X11Forwarding no
    '';
  };

  # Allow the backup user to receive ZFS snapshots without root.
  # create/mount are needed for new datasets; rollback for -F receives.
  systemd.services.zfs-backup-permissions = {
    description = "Grant ZFS delegation to backup user";
    wantedBy = [ "multi-user.target" ];
    after = [ "zfs.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.zfs}/bin/zfs allow backup create,receive,mount,rollback,destroy backup";
    };
  };

  users.users.muser.openssh.authorizedKeys.keyFiles = [
    ../../server-desktop/ssh/id_ed25519.pub
  ];

  # Dedicated user for syncoid ZFS receive. Non-interactive SSH only (PermitTTY no);
  # ZFS delegation above grants the necessary zfs permissions without root.
  users.users.backup = {
    isSystemUser = true;
    group = "backup";
    home = "/backup";
    createHome = false;
    shell = pkgs.bash;
    openssh.authorizedKeys.keys = [
      # TODO: home-server syncoid key
    ];
  };
  users.groups.backup = {};

  # Watchdog that restarts wg-quick-wg0 if the WireGuard tunnel has had no
  # handshake in the last 5 minutes. Catches cases where routing is restored
  # after disruption but wg-quick (a oneshot service) doesn't re-run.
  systemd.services.wg-watchdog = {
    script = ''
      now=$(date +%s)
      handshake=$(${pkgs.wireguard-tools}/bin/wg show wg0 latest-handshakes 2>/dev/null | awk '{print $2}')
      if [ -z "$handshake" ] || [ "$handshake" -eq 0 ] || [ "$((now - handshake))" -gt 300 ]; then
        echo "wg0 handshake stale or missing (last: ''${handshake:-none}), restarting wg-quick-wg0"
        systemctl restart wg-quick-wg0
      else
        echo "wg0 handshake OK ($((now - handshake))s ago)"
      fi
    '';
    serviceConfig = {
      Type = "oneshot";
      User = "root";
    };
  };

  systemd.timers.wg-watchdog = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "5m";
      OnUnitActiveSec = "2m";
    };
  };

  environment.systemPackages = [ pkgs.mbuffer ];

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users.muser = import ./home.nix;
  };

  system.stateVersion = "26.05";
}
