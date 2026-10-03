{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
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

  outputs = { self, nixpkgs, nixpkgs-unstable, agenix, home-manager }:
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
    # Pull home-assistant from unstable so the package version stays close to
    # HaOS releases and storage-format compatibility is maintained.
    unstableOverlay = final: prev:
      let
        unstable = import nixpkgs-unstable {
          system = prev.stdenv.hostPlatform.system;
          config.allowUnfree = true;
        };
      in {
        home-assistant  = unstable.home-assistant;
        zwave-js-server = unstable.zwave-js-server;
        invidious       = unstable.invidious;
        vaultwarden     = unstable.vaultwarden;
        claude-code     = unstable.claude-code;
      };
  in {
    nixosConfigurations = lib.genAttrs systemNames (name:
      nixpkgs.lib.nixosSystem {
        modules = [
          { nixpkgs.overlays = [ agenix.overlays.default unstableOverlay ]; }
          agenix.nixosModules.default
          home-manager.nixosModules.home-manager
          ../../${name}/nixos/configuration.nix
        ];
      }
    );
  };
}
