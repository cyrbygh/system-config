{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

  outputs = { self, nixpkgs }:
  let
    lib = nixpkgs.lib;
    systemNames = lib.pipe (builtins.readDir ./systems) [
      (lib.filterAttrs (name: type:
        type == "directory"
        && !lib.hasPrefix "_" name
        && builtins.pathExists ./systems/${name}/nixos/configuration.nix
      ))
      builtins.attrNames
    ];
  in {
    nixosConfigurations = lib.genAttrs systemNames (name:
      nixpkgs.lib.nixosSystem {
        modules = [ ./systems/${name}/nixos/configuration.nix ];
      }
    );
  };
}
