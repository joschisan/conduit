{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    devenv.url  = "github:cachix/devenv";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, devenv, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = import nixpkgs { inherit system; };
    in {
      devShells.default =
        devenv.lib.mkShell {
          inherit pkgs;
          modules = [
            {
              packages = with pkgs; [ cargo rustc bitcoind postgresql ];

              # Tiny service layer
              services.postgres.enable = true;   # port 5432
              services.bitcoind = {
                enable  = true;
                network = "regtest";
                extraArgs = "-txindex=1 -fallbackfee=0.0002";
                rpcPort = 18443;
                rpcUser = "alice";
                rpcPassword = "insecurepw";
              };
            }
          ];
        };
    });
} 