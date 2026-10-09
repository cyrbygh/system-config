{ config, lib, pkgs, ... }:

let
  version = "1.4.1";

  # Upstream's static (musl) release binary; no image or build needed.
  ironclaw = pkgs.stdenvNoCC.mkDerivation {
    pname = "ironclaw";
    inherit version;
    src = pkgs.fetchurl {
      url = "https://github.com/nearai/ironclaw/releases/download/ironclaw-v${version}/ironclaw-x86_64-unknown-linux-musl.tar.gz";
      sha256 = "c27454b886a7a8f075d3ffdb99bd6f4d7caf488e034a29fde0983e26e596ffdb";
    };
    installPhase = ''
      install -Dm755 ironclaw $out/bin/ironclaw
    '';
  };

  stateDir = "/var/lib/ironclaw";
  rebornHome = "${stateDir}/reborn";
  workspace = "${stateDir}/workspace";
  ollama = config.services.ollama;

  # The WebUI token doubles as the session-signing key (must be >= 32 bytes).
  ensureToken = pkgs.writeShellScript "ironclaw-ensure-webui-token" ''
    if [ ! -s ${rebornHome}/webui-token ]; then
      ${pkgs.coreutils}/bin/head -c 48 /dev/urandom | ${pkgs.coreutils}/bin/base64 -w0 > ${rebornHome}/webui-token
    fi
  '';
in
{
  users.users.ironclaw = {
    isSystemUser = true;
    group = "ironclaw";
    home = stateDir;
  };
  users.groups.ironclaw = { };

  # stateDir is its own dataset; its mountpoint is root-owned when created.
  systemd.tmpfiles.rules = [
    "d ${stateDir} 0700 ironclaw ironclaw -"
    "d ${rebornHome} 0700 ironclaw ironclaw -"
    "d ${workspace} 0700 ironclaw ironclaw -"
  ];

  # infra VLAN only.
  systemd.services.ironclaw = {
    description = "IronClaw agent";
    wantedBy = [ "multi-user.target" ];
    wants = [ "ollama.service" ];
    after = [ "ollama.service" ];

    environment = {
      HOME = stateDir;
      IRONCLAW_REBORN_HOME = rebornHome;
      IRONCLAW_REBORN_WORKSPACE_ROOT = workspace;
      LLM_BACKEND = "ollama";
      OLLAMA_BASE_URL = "http://${ollama.host}:${toString ollama.port}";
      OLLAMA_MODEL = "qwen3:14b";
      LLM_REQUEST_TIMEOUT_SECS = "600";
      SSL_CERT_FILE = "/etc/ssl/certs/ca-certificates.crt";
    };

    serviceConfig = {
      User = "ironclaw";
      Group = "ironclaw";
      ExecStartPre = ensureToken;
      ExecStart = "${ironclaw}/bin/ironclaw serve --host 10.215.20.1 --port 8091";
      WorkingDirectory = workspace;
      Restart = "on-failure";

      # Empty read-only root; only the store, certs, DNS config and its own state.
      TemporaryFileSystem = "/:ro";
      MountAPIVFS = true;
      BindReadOnlyPaths = [
        "/nix/store"
        "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt:/etc/ssl/certs/ca-certificates.crt"
        "-/etc/resolv.conf"
        "-/etc/hosts"
      ];
      BindPaths = [ stateDir ];

      CapabilityBoundingSet = "";
      NoNewPrivileges = true;
      PrivateTmp = true;
      PrivateDevices = true;
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectKernelLogs = true;
      ProtectControlGroups = true;
      ProtectClock = true;
      ProtectHostname = true;
      ProtectProc = "invisible";
      ProcSubset = "pid";
      RestrictNamespaces = true;
      RestrictRealtime = true;
      RestrictSUIDSGID = true;
      LockPersonality = true;
      # MemoryDenyWriteExecute left off: the WASM tool runtime JIT-compiles.
      RestrictAddressFamilies = [ "AF_INET" "AF_INET6" "AF_UNIX" ];
      SystemCallArchitectures = "native";
      SystemCallFilter = [ "@system-service" "~@privileged @resources" ];
      UMask = "0077";
    };
  };
}
