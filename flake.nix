# file: flake.nix
{
  description = "A minimal example for trying to get pytorch with ROCM working";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  inputs.poetry2nix.url = "github:nix-community/poetry2nix";

  #inputs.nixified-ai.url = "github:nixified-ai/flake";

  outputs = { self, nixpkgs, poetry2nix }:
    let
      system = "x86_64-linux";
      #pkgs = nixpkgs.legacyPackages.${system};
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
        overlays = [];
      };
      inherit (poetry2nix.lib.mkPoetry2Nix { inherit pkgs; }) mkPoetryApplication mkPoetryEnv overrides;

      myPythonApp = mkPoetryApplication { 
        projectDir = ./.; 
        overrides = overrides.withDefaults ( ( import ./overrides.nix ) nixpkgs );
        buildInputs = [pkgs.nodejs pkgs.python311Packages.torch];
      };

      myPythonEnv = mkPoetryEnv {
        projectDir = ./.;
        overrides = overrides.withDefaults ( ( import ./overrides.nix ) nixpkgs );


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
            if [[ $lockfiles ]]; then
              for lock in **/poetry.lock; do
                (
                  echo Updating "$lock"
                  cd "$(dirname "$lock")"
                  poetry update
                )
              done
            else
              echo "No Lockfiles."
            fi
          '';
        };
    in
    {
      packages.${system}={  
        default = myPythonApp;
        enviroment = myPythonEnv;

      };
      apps.${system} = {
        default = {  
          type = "app";
          # replace <script> with the name in the [tool.poetry.scripts] section of your pyproject.toml
          program = "${myPythonEnv}/bin/jupyter-lab";
        };
        update-lock = {
          type = "app";
          program = "${update-poetry-lock}/bin/update-poetry-lock";
        };
        jupytext = {
          type = "app";
          program = "${myPythonEnv}/bin/jupytext";
        };
      };
    };
}
