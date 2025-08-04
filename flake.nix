{
  description = "All Thing's Linux discord bot - awbot";

  inputs = {
    nixpkgs = {
      type = "github";
      owner = "NixOS";
      repo = "nixpkgs";
      ref = "nixos-unstable";
    };

    flake-parts = {
      type = "github";
      owner = "hercules-ci";
      repo = "flake-parts";
      ref = "main";
    };
  };

  outputs = inputs@{
    self,
    nixpkgs,
    flake-parts,
    ...
  }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "x86_64-darwin"
        "aarch64-linux"
        "aarch64-darwin"
      ];

      perSystem = { pkgs, self', ... }: {
        devShells = {
          default = self'.devShells.awbot;
          awbot = pkgs.callPackage ./shell.nix { inherit pkgs self; };
        };
      };
    };
}
