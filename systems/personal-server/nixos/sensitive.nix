{ config, lib, pkgs, ... }:

{
  # Unlocks hdds/sensitive and starts all services that depend on it.
  # Run manually after boot: start-sensitive-services
  environment.systemPackages = [
    (pkgs.writeShellScriptBin "start-sensitive-services" ''
      set -e

      # hdds only holds noauto datasets, so NixOS imports it on demand, not at boot.
      ${pkgs.systemd}/bin/systemctl start zfs-import-hdds.service

      key_status=$(${pkgs.zfs}/bin/zfs get -H -o value keystatus hdds/sensitive 2>/dev/null || true)
      if [ "$key_status" != "available" ]; then
        echo "Loading encryption key for hdds/sensitive..."
        ${pkgs.zfs}/bin/zfs load-key hdds/sensitive
      fi

      echo "Mounting sensitive datasets (services will start automatically)..."
      ${pkgs.systemd}/bin/systemctl start \
        hdds-sensitive-media-music.mount \
        hdds-sensitive-media-movies.mount \
        hdds-sensitive-media-tv_shows.mount
      echo "Done."
    '')
  ];
}
