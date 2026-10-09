{ config, lib, pkgs, ... }:

{
  # infra VLAN only. No auth on the API.
  services.ollama = {
    enable = true;
    package = pkgs.ollama-cuda;
    host = "10.215.20.1";
    user = "ollama";
    # 16K context for IronClaw's ~11K-token prompt; flash attention + q8 KV cache
    # keep that and qwen3:14b within the 3060's 12 GB.
    environmentVariables = {
      OLLAMA_CONTEXT_LENGTH = "16384";
      OLLAMA_FLASH_ATTENTION = "1";
      OLLAMA_KV_CACHE_TYPE = "q8_0";
    };
  };

  systemd.services.ollama = {
    wants = [ "systemd-networkd-wait-online@infra.service" ];
    after = [ "systemd-networkd-wait-online@infra.service" ];
    # Static user so state lives at /var/lib/ollama (its own dataset) rather than
    # /var/lib/private, which DynamicUser would try to move a mountpoint into.
    serviceConfig.DynamicUser = lib.mkForce false;
  };

  # The models dataset's mountpoint is root-owned when created.
  systemd.tmpfiles.rules = [
    "d ${config.services.ollama.models} 0700 ollama ollama -"
  ];
}
