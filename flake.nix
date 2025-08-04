{
  description = "Prisma on NixOS dev shell";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
      in {
        devShells.default = pkgs.mkShell {
          buildInputs = [
            pkgs.nodejs_20
            pkgs.prisma
            pkgs.openssl
            pkgs.python312
            pkgs.python312Packages.pip
            pkgs.python312Packages.virtualenv
          ];

          # Help Prisma engines find OpenSSL at runtime
          LD_LIBRARY_PATH = "${pkgs.openssl.out}/lib";
          # Some setups also benefit from:
          # PKG_CONFIG_PATH = "${pkgs.openssl.dev}/lib/pkgconfig";
        };
      });
}
