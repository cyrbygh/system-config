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
  boot.kernelModules = [ "wl" "iTCO_wdt" ];
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

  # Hardware watchdog via Intel TCO. systemd feeds it every 15s; if systemd
  # hangs the machine resets after 30s. Also provides the cold-reset that
  # broadcom_sta needs when a warm reboot leaves the WiFi hardware in a bad state.
  systemd.settings.Manager = {
    RuntimeWatchdogSec = "30";
    ShutdownWatchdogSec = "10min";
  };

  # Reload the wl driver if WiFi hasn't connected 2 minutes after boot —
  # broadcom_sta sometimes fails to initialise on a warm reboot and needs
  # the module cycled to recover.
  systemd.services.wifi-driver-recovery = {
    script = ''
      if ${pkgs.networkmanager}/bin/nmcli -t -f TYPE,STATE device | grep -q "wifi:connected"; then
        echo "WiFi connected, no recovery needed"
      else
        echo "WiFi not connected after boot, reloading wl module"
        ${pkgs.kmod}/bin/rmmod wl || true
        ${pkgs.kmod}/bin/modprobe wl
        systemctl restart NetworkManager
      fi
    '';
    serviceConfig = {
      Type = "oneshot";
      User = "root";
    };
  };

  systemd.timers.wifi-driver-recovery = {
    wantedBy = [ "timers.target" ];
    timerConfig.OnBootSec = "2m";
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

  # Clears AFTERG3_EN (bit 0) in the Intel PCH GEN_PMCON_3 register so the
  # machine boots when AC is restored after a power cut. The bit lives in the
  # RTC well (CMOS-battery-backed) so it survives power loss, but Apple's EFI
  # resets it to 1 on every graceful shutdown — hence this must run each boot.
  # Mask form (0:1) touches only bit 0 and leaves the rest of the byte intact.
  systemd.services.mac-power-on-after-loss = {
    description = "Clear AFTERG3_EN so Mac Mini boots after AC restore";
    wantedBy = [ "sysinit.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.pciutils}/bin/setpci -s 00:1f.0 0xa4.b=0:1";
    };
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
