{ config, lib, pkgs, modulesPath, ... }:

let
  loadZfsKey = pkgs.writeShellScript "load-zfs-key" ''
    mkdir -p /run/keydev
    mount -t vfat /dev/disk/by-label/boot /run/keydev
    zfs load-key -L file:///run/keydev/zfs-key ssds
    umount /run/keydev
  '';
in
{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  boot.initrd.availableKernelModules = [ "xhci_pci" "nvme" "usbhid" "usb_storage" "sd_mod" ];
  boot.initrd.kernelModules = [ "ahci" "vfat" "nls_cp437" "nls_iso8859_1" ];
  boot.kernelModules = [ "kvm-amd" ];
  boot.extraModulePackages = [];


  boot.supportedFilesystems = [ "zfs" ];
  boot.zfs.requestEncryptionCredentials = false;

  # Mount the key disk in the initrd, load the ZFS encryption key,
  # then unmount before the pool datasets are mounted.
  boot.initrd.systemd.storePaths = [ loadZfsKey ];
  boot.initrd.systemd.services.load-zfs-key = {
    description = "Load ZFS encryption key from boot partition";
    wantedBy = [ "sysroot.mount" ];
    before = [ "sysroot.mount" ];
    after = [ "dev-disk-by\\x2dlabel-boot.device" "zfs-import.target" ];
    requires = [ "dev-disk-by\\x2dlabel-boot.device" "zfs-import.target" ];
    unitConfig.DefaultDependencies = false;
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = loadZfsKey;
    };
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-label/boot";
    fsType = "vfat";
    options = [ "fmask=0022" "dmask=0022" ];
  };

  fileSystems."/" = {
    device = "ssds/root";
    fsType = "zfs";
  };

  fileSystems."/nix" = {
    device = "ssds/nix";
    fsType = "zfs";
  };

  fileSystems."/var" = {
    device = "ssds/var";
    fsType = "zfs";
  };

  swapDevices = [];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
