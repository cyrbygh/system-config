{ modulesPath, lib, ... }:

{
  imports = [ (modulesPath + "/virtualisation/proxmox-lxc.nix") ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  proxmoxLXC = {
    # Required so NixOS configures itself for cap_sys_admin (sunshine input).
    # The Proxmox host side must also mark the container as privileged.
    privileged = true;
    manageHostName = true;
  };
}
