{ pkgs, ... }:

{
  # The Intel 7265 (iwlwifi) sometimes comes back from S3 fully re-associated -- auth,
  # 4-way handshake and DHCP all succeed within a few seconds -- but with its TX/RX
  # queues wedged, so no traffic actually flows. Restarting NetworkManager alone does not
  # clear this; only reloading the driver does. Probe the gateway first so the reload only
  # happens on the wakes that actually need it, leaving the common case untouched.
  powerManagement.resumeCommands = ''
    dev=$(${pkgs.networkmanager}/bin/nmcli -t -f DEVICE,TYPE device | ${pkgs.gawk}/bin/awk -F: '$2 == "wifi" { print $1; exit }')
    [ -z "$dev" ] && exit 0

    connected=""
    for _ in $(seq 1 15); do
      case "$(${pkgs.networkmanager}/bin/nmcli -t -f GENERAL.STATE device show "$dev" | cut -d: -f2)" in
        100*) connected=1; break ;;
      esac
      sleep 1
    done

    if [ -n "$connected" ]; then
      gw=$(${pkgs.iproute2}/bin/ip route show default dev "$dev" | ${pkgs.gawk}/bin/awk '{ print $3; exit }')
      if [ -n "$gw" ] && ${pkgs.iputils}/bin/ping -c2 -W2 "$gw" >/dev/null 2>&1; then
        exit 0
      fi
    fi

    ${pkgs.systemd}/bin/systemctl stop NetworkManager
    ${pkgs.iproute2}/bin/ip link set "$dev" down 2>/dev/null || true
    ${pkgs.kmod}/bin/modprobe -r iwlmvm || true
    ${pkgs.kmod}/bin/modprobe -r iwlwifi || true
    ${pkgs.kmod}/bin/modprobe iwlwifi || true
    ${pkgs.systemd}/bin/systemctl start NetworkManager
  '';
}
