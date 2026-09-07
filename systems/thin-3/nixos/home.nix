{ ... }:

{
  imports = [ ../../_shared/home/chromebook-thin-client.nix ];
  home.file.".ssh/id_ed25519.pub".source = ../ssh/id_ed25519.pub;
}
