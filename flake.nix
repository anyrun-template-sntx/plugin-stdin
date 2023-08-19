{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    crane = {
      url = "github:ipetkov/crane";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    flake-utils.url = "github:numtide/flake-utils";

    advisory-db = {
      url = "github:rustsec/advisory-db";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, crane, flake-utils, advisory-db, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
        };

        inherit (pkgs) lib;

        craneLib = crane.lib.${system};
        src = craneLib.cleanCargoSource (craneLib.path ./.);

        commonArgs = {
          inherit src;
          buildInputs = with pkgs; [
            pkg-config
          ] ++ lib.optionals pkgs.stdenv.isDarwin [ ];
        };

        cargoArtifacts = craneLib.buildDepsOnly commonArgs;

        anyrun-stdin = craneLib.buildPackage (commonArgs // {
          inherit cargoArtifacts;
        });
      in
      {
        checks = {
          inherit anyrun-stdin;

          anyrun-stdin-clippy = craneLib.cargoClippy (commonArgs // {
            inherit cargoArtifacts;
            cargoClippyExtraArgs = "--all-targets -- --deny warnings";
          });

          anyrun-stdin-doc = craneLib.cargoDoc (commonArgs // {
            inherit cargoArtifacts;
          });

          anyrun-stdin-fmt = craneLib.cargoFmt {
            inherit src;
          };

          anyrun-stdin-audit = craneLib.cargoAudit {
            inherit src advisory-db;
          };
        };

        packages.default = anyrun-stdin;

        devShells.default = pkgs.mkShell {
          inputsFrom = builtins.attrValues self.checks.${system};

          nativeBuildInputs = with pkgs; [
            alejandra # nix formatter
            rustfmt # rust formatter
            statix # lints and suggestions
            deadnix # clean up unused nix code
            rustc # rust compiler
            gcc # GNU Compiler Collection
            cargo # rust package manager
            clippy # opinionated rust formatter

            rust-analyzer # rust analyzer
            lldb # software debugger
          ];
        };
      });
}
