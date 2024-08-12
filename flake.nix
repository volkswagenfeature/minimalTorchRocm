# file: flake.nix
{
  description = "A minimal example for trying to get pytorch with ROCM working";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  inputs.poetry2nix.url = "github:nix-community/poetry2nix";

  #inputs.nixified-ai.url = "github:nixified-ai/flake";

  outputs = { self, nixpkgs, poetry2nix }:
    let
      addNativeBuildInputs = prev: drvName: inputs: {
        "${drvName}" = prev.${drvName}.overridePythonAttrs (old: {
          nativeBuildInputs = (old.nativeBuildInputs or []) ++ inputs;
        });
      };

      system = "x86_64-linux";
      #pkgs = nixpkgs.legacyPackages.${system};
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
        #overlays = [];
      };

      inherit (poetry2nix.lib.mkPoetry2Nix { inherit pkgs; }) mkPoetryApplication mkPoetryEnv overrides;

      myPythonEnv = mkPoetryEnv {
        projectDir = ./.;
        overrides = overrides.withDefaults (final: prev: { 
          dummy-test = prev.dummy-test.overridePythonAttrs (old: {
            nativeBuildInputs = ( old.nativeBuildInputs or [] ) ++ [
              final.setuptools
            ];
          });
        });

      };

      update-poetry-lock =
        pkgs.writeShellApplication
        {
          name = "update-poetry-lock";
          runtimeInputs = [pkgs.poetry];
          text = ''
            shopt -s globstar
            shopt -s nullglob

            lockfiles=(**/poetry.lock)
            pyprojects=(**/pyproject.toml)

            if [[ ''${lockfiles[*]} ]]; then
              for lock in $lockfiles; do
                (
                  echo Updating "$lock"
                  cd "$(dirname "$lock")"
                  poetry update
                )
              done
            elif [[ ''${pyprojects[*]} ]]; then
              echo "No lockfiles found, but pyproject.tomls found so creating them"
              for lf in $pyprojects; do
                (
                  echo "Creating $(dirname "$lf")/poetry.lock"
                  cd "$(dirname "$lf")"
                  poetry update
                )
              done
            else
              print "Nothing to do."
            fi
          '';
        };
    in
      {
        packages.${system}={  
          default = myPythonEnv;
        };
        apps.${system} = {
          update-lock = {
            type = "app";
            program = "${update-poetry-lock}/bin/update-poetry-lock";
          };
        };
      };
}
