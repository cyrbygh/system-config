{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
      inputs.darwin.follows = "";
    };
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, agenix, home-manager }:
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
        modules = [
          agenix.nixosModules.default
          home-manager.nixosModules.home-manager
          ../../${name}/nixos/configuration.nix
        ];
      }
    );
  };
}
