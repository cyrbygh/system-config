{ config, lib, pkgs, ... }:

{
  # A system importing this module only needs to set its slot. Everything else, including the
  # fixed 10.77.67.0/24 subnet, the endpoint host, and the private key, is handled here or read
  # from predictable paths populated at install time.
  options.wireguardClient.slot = lib.mkOption {
    type = lib.types.ints.between 1 254;
    example = 100;
    description = "This client's last address octet on the 10.77.67.0/24 WireGuard subnet.";
  };

  config.networking.wireguard.interfaces.wg0 = {
    ips = [ "10.77.67.${toString config.wireguardClient.slot}/32" ];

    privateKeyFile = "/home/muser/.system-config/systems/current/wg/private_key.decrypted";

    peers = [
      {
        publicKey = "NFg8Pkes/lBBoUkM5qUXHW1bCcZl87XUrxCDlExVQE8=";

        allowedIPs = [
          "10.215.10.0/24"
          "10.215.20.0/24"
          "10.215.30.0/24"
          "10.215.40.0/24"
          "10.215.50.0/24"
        ];

        endpoint = lib.fileContents ../../current/wg/host.decrypted;

        # Keep the tunnel alive through NAT so the always on connection survives idle periods.
        persistentKeepalive = 25;
      }
    ];
  };
}
