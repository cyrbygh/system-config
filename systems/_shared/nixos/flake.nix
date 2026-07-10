{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

  outputs = { self, nixpkgs }:
  let
    lib = nixpkgs.lib;
    systemNames = lib.pipe (builtins.readDir ../.. ) [
      (lib.filterAttrs (name: type:
        type == "directory"
        && !lib.hasPrefix "_" name
        && builtins.pathExists ../../${name}/nixos/configuration.nix
      ))
      builtins.attrNames
    ];
  in {
    nixosConfigurations = lib.genAttrs systemNames (name:
      nixpkgs.lib.nixosSystem {
        modules = [ ../../${name}/nixos/configuration.nix ];
      }
    );
  };
}
