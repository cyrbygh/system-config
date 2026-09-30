{ config, lib, pkgs, ... }:

let
  # First two octets of all internal subnets.
  # Change to "10.215" when transplanting to the production machine.
  prefix = "192.215";

  # Physical NIC connecting to the VLAN trunk.
  nic = "tr0";

  mkSubnet = vlanId: map (h: h // { ip = "${prefix}.${toString vlanId}.${toString h.n}"; });

  main = mkSubnet 10 [
    { name = "inktank-printer";    n = 3;  mac = "e0:bb:9e:21:4b:cd"; }
    { name = "apple-tv";           n = 4;  mac = "c0:95:6d:55:5d:85"; }
    { name = "scrypted";           n = 20; mac = "bc:24:11:e1:bd:02"; }
  ];

  infra = mkSubnet 20 [
    { name = "wifi-0";             n = 6;  mac = "40:ed:00:da:aa:52"; }
    { name = "wifi-1";             n = 7;  mac = "a8:6e:84:b1:5f:90"; }
    { name = "wifi-2";             n = 8;  mac = "a8:6e:84:b1:62:28"; }
    { name = "wifi-3";             n = 9;  mac = "b0:95:75:6d:f1:82"; }
    { name = "hass";               n = 10; mac = "bc:24:11:45:34:f1"; }
    { name = "voip-base";          n = 12; mac = "ec:74:d7:6b:19:d3"; }
    { name = "kvm";                n = 13; mac = "dc:a6:32:6a:56:ef"; }
  ];

  iot = mkSubnet 40 [
    { name = "weight-scale";       n = 5;  mac = "0c:7e:24:4e:c9:63"; }
    { name = "ir-blaster";         n = 6;  mac = "e8:16:56:06:eb:32"; }
    { name = "garage-door";        n = 7;  mac = "c4:d8:d5:0a:fc:c2"; }
    { name = "vacuum";             n = 8;  mac = "24:18:c6:14:06:27"; }
    { name = "esphome";            n = 9;  mac = "bc:24:11:00:4b:cf"; }
    { name = "cam-1";              n = 10; mac = "80:7c:62:da:3f:3b"; }
    { name = "cam-2";              n = 11; mac = "9c:8e:cd:2b:ed:99"; }
    { name = "cam-3";              n = 12; mac = "3c:52:a1:e5:be:fa"; }
    { name = "cam-4";              n = 13; mac = "3c:52:a1:e5:be:69"; }
    { name = "fridge";             n = 14; mac = "e0:85:4d:86:b4:ec"; }
  ];

  mgmt = mkSubnet 50 [
    { name = "thin-0";             n = 2;  mac = "f0:d4:e2:f9:17:66"; }
    { name = "server-desktop";     n = 3;  mac = "bc:24:11:c6:33:dd"; }
  ];

  # Single source of truth for internal VLANs. Drives interface config,
  # Kea DHCP, dnsmasq, and AdGuard.
  internalVlans = [
    { name = "main";  id = 10; domain = "lan";  pool = true;  hosts = main; }
    { name = "infra"; id = 20; domain = "inf";  pool = true;  hosts = infra; }
    { name = "iot";   id = 40; domain = "iot";  pool = true;  hosts = iot; }
    { name = "mgmt";  id = 50; domain = "mgmt"; pool = false; hosts = mgmt; }
  ];

  localHostsFile =
    lib.concatMapStrings (v:
      lib.concatMapStrings (h: "${h.ip} ${h.name} ${h.name}.${v.domain}\n") v.hosts
    ) internalVlans
    + "${prefix}.10.1 router router.lan\n";

in {

  # ── Network online target ──────────────────────────────────────────────────
  # Only wait for the WAN interface; internal VLAN interfaces are static and
  # don't gate whether the machine is "online".
  systemd.network.wait-online.extraArgs = [ "--interface=wan" ];

  # ── IP forwarding ──────────────────────────────────────────────────────────
  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
    "net.ipv4.conf.all.forwarding" = 1;
  };

  # ── VLANs ──────────────────────────────────────────────────────────────────
  networking.useDHCP = false;
  networking.vlans =
    { wan = { id = 5; interface = nic; }; } //
    lib.listToAttrs (map (v: lib.nameValuePair v.name { id = v.id; interface = nic; }) internalVlans);

  networking.interfaces =
    { ${nic}.useDHCP = false; wan.useDHCP = true; } //
    lib.listToAttrs (map (v: lib.nameValuePair v.name {
      ipv4.addresses = [{ address = "${prefix}.${toString v.id}.1"; prefixLength = 24; }];
    }) internalVlans);

  # ── Firewall (nftables) ────────────────────────────────────────────────────
  #
  # Interfaces:
  #   wan   VLAN 5  — upstream internet
  #   main  VLAN 10 — main LAN
  #   infra VLAN 20 — infrastructure
  #   iot   VLAN 40 — IoT devices
  #   mgmt  VLAN 50 — management hosts
  #
  # Per-service rules (specific host IPs, port forwards) will be added
  # incrementally as services come online.
  #
  networking.nftables = {
    enable = true;
    ruleset = ''
      table inet filter {
        chain input {
          type filter hook input priority filter; policy drop;

          iifname lo                        accept
          ct state { established, related } accept
          ct state invalid                  drop

          # Trusted interfaces: full access to router services
          iifname { infra, mgmt, wg0 }      accept

          # main and IoT: DNS and DHCP only
          iifname { main, iot } tcp dport 53               accept
          iifname { main, iot } udp dport { 53, 67 }       accept
          iifname { main, iot } reject with icmpx admin-prohibited

          # WAN: DHCP response + ICMP + SSH (from masqueraded router IP)
          iifname wan udp dport 68                         accept
          iifname wan udp dport 443                        accept  # WireGuard
          iifname wan icmp type echo-request               accept
          iifname wan ip saddr 10.215.50.0/24 accept                    # Mgmt network access during test period.
          iifname wan ip saddr 10.215.30.3   tcp dport { 8000, 8080, 3001, 8282 } accept  # Traefik.
          iifname wan reject with icmpx admin-prohibited
        }

        chain forward {
          type filter hook forward priority filter; policy drop;

          ct state { established, related } accept
          ct state invalid                  drop

          # Management: full routing access
          iifname mgmt                      accept

          # Internet access per VLAN (IoT is isolated by default)
          iifname main    oifname wan       accept
          iifname infra   oifname wan       accept
          iifname podman0 oifname wan       accept

          # Infra can reach IoT
          iifname infra oifname iot         accept

          # VPN clients can reach internal networks; backup systems (10.77.68.0/24) are isolated.
          iifname wg0 ip saddr 10.77.67.0/24 accept

          # NTP outbound from any VLAN
          oifname wan udp dport 123         accept
        }

        chain output {
          type filter hook output priority filter; policy accept;
        }
      }

      table ip nat {
        chain prerouting {
          type nat hook prerouting priority dstnat; policy accept;
        }

        chain postrouting {
          type nat hook postrouting priority srcnat; policy accept;
          oifname wan masquerade
        }
      }
    '';
  };

  # ── DHCP (Kea) ─────────────────────────────────────────────────────────────
  services.kea.dhcp4 = {
    enable = true;
    settings = {
      interfaces-config.interfaces = map (v: v.name) internalVlans;
      lease-database = {
        type = "memfile";
        persist = true;
        name = "/var/lib/kea/dhcp4.leases";
      };
      valid-lifetime = 43200;
      subnet4 = let
        mkReservation = h: { hw-address = h.mac; ip-address = h.ip; hostname = h.name; };
        mkDhcpOptions = gw: domain: [
          { name = "routers";             data = gw; }
          { name = "domain-name-servers"; data = gw; }
          { name = "domain-name";         data = domain; }
        ];
      in map (v: {
        id     = v.id;
        subnet = "${prefix}.${toString v.id}.0/24";
        pools  = lib.optional v.pool { pool = "${prefix}.${toString v.id}.100 - ${prefix}.${toString v.id}.249"; };
        option-data  = mkDhcpOptions "${prefix}.${toString v.id}.1" v.domain;
        reservations = map mkReservation v.hosts;
      }) internalVlans;
    };
  };

  # AdGuard handles all DNS; disable the stub resolver.
  # Point the host's resolv.conf at AdGuard so aardvark-dns (Podman) can forward external queries.
  networking.nameservers = [ "127.0.0.1" ];
  services.resolved.enable = false;

  # ── DNS: local resolver (dnsmasq) ─────────────────────────────────────────
  # Serves local hostnames from a generated hosts file on a loopback port.
  # AdGuard routes zone-suffix queries here so local lookups appear as
  # "forwarded" in stats rather than "blocked".
  environment.etc."dnsmasq-local-hosts".text = localHostsFile;

  services.dnsmasq = {
    enable = true;
    resolveLocalQueries = false;
    settings = {
      listen-address = "127.0.0.1";
      port = 5335;
      no-resolv = true;
      no-hosts = true;
      addn-hosts = "/etc/dnsmasq-local-hosts";
      local = map (v: "/${v.domain}/") internalVlans;
    };
  };

  # ── DNS: AdGuard Home ──────────────────────────────────────────────────────
  services.adguardhome = {
    enable = true;
    mutableSettings = false;
    settings = {
      http.address = "127.0.0.1:3000";
      dns = {
        bind_hosts = [ "0.0.0.0" ];
        port = 53;
        upstream_dns =
          map (v: "[/${v.domain}/]127.0.0.1:5335") internalVlans
          ++ [ "https://dns.cloudflare.com/dns-query" "https://dns.google/dns-query" ];
        bootstrap_dns = [ "1.1.1.1" "8.8.8.8" ];
      };
    };
  };
}
