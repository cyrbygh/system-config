{ config, lib, pkgs, ... }:

{
  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_17;

    # Each service connects via unix socket as its own OS user.
    # peer auth ensures only that OS user can authenticate as that postgres user.
    authentication = lib.mkForce ''
      local all         postgres    peer
      local miniflux    miniflux    peer
      local vaultwarden vaultwarden peer
    '';

    ensureUsers = [
      { name = "miniflux";    ensureDBOwnership = true; }
      { name = "vaultwarden"; ensureDBOwnership = true; }
    ];

    ensureDatabases = [ "miniflux" "vaultwarden" ];
  };
}
