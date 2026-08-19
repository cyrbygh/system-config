{ config, lib, pkgs, ... }:

{
  imports = [ ./base.nix ];

  # BCM4360 needs the out-of-tree wl driver from broadcom_sta (unfree, insecure).
  nixpkgs.config.allowUnfreePredicate  = pkg: lib.getName pkg == "broadcom-sta";
  nixpkgs.config.allowInsecurePredicate = pkg: lib.getName pkg == "broadcom-sta";
  boot.kernelModules = [ "wl" "iTCO_wdt" "applesmc" "coretemp" "drivetemp" ];
  boot.extraModulePackages = [ config.boot.kernelPackages.broadcom_sta ];

  networking.useNetworkd = false;
  networking.networkmanager.enable = true;
  users.users.muser.extraGroups = [ "networkmanager" ];

  age.identityPaths = [ "/etc/age_key" ];
  age.secrets.wg0-conf = {
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

  # Clears AFTERG3_EN (bit 0) in the Intel PCH GEN_PMCON_3 register so the
  # machine boots when AC is restored after a power cut. The bit lives in the
  # RTC well (CMOS-battery-backed) so it survives power loss. macOS resets it
  # to 1 on graceful shutdown; NixOS does not, so in practice this is a no-op,
  # but kept as a safety net. Mask form (0:1) touches only bit 0.
  systemd.services.mac-power-on-after-loss = {
    description = "Clear AFTERG3_EN so Mac Mini boots after AC restore";
    wantedBy = [ "sysinit.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.pciutils}/bin/setpci -s 00:1f.0 0xa4.b=0:1";
    };
  };

  # Pings the WireGuard server once per minute. After 30 consecutive failures
  # (~30 min) the machine reboots — covers any combination of WiFi, driver,
  # or tunnel failure without trying to patch individual components.
  systemd.services.connectivity-watchdog = {
    description = "Reboot after 30 consecutive minutes without WireGuard connectivity";
    wantedBy = [ "multi-user.target" ];
    after = [ "wg-quick-wg0.service" ];
    script = ''
      failures=0
      while true; do
        sleep 60
        if ${pkgs.iputils}/bin/ping -c 1 -W 5 10.77.67.1 > /dev/null 2>&1; then
          if [ "$failures" -gt 0 ]; then
            echo "Connectivity restored after $failures consecutive failure(s)"
            failures=0
          fi
        else
          failures=$((failures + 1))
          echo "No connectivity to WireGuard server ($failures/30)"
          if [ "$failures" -ge 30 ]; then
            echo "30 consecutive failures — rebooting"
            systemctl reboot
          fi
        fi
      done
    '';
    serviceConfig = {
      Type = "simple";
      Restart = "on-failure";
      RestartSec = "10s";
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
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEUY3/jST6nv6qDAiHYKRQxG4jpnkNFMcC9L9IEq/v2w"
    ];
  };
  users.groups.backup = {};

  environment.systemPackages = with pkgs; [
    lm_sensors
    lzop
    mbuffer
  ];

  systemd.services.glances = {
    description = "Glances system monitor REST API";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.glances}/bin/glances -w";
      Restart = "on-failure";
      RestartSec = "5s";
    };
  };

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users.muser = import ../home/mac-mini-2014-backup.nix;
  };
}
