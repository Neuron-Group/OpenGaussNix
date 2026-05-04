{
  description = "Nix flake for Open Gauss";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    let
      overlay = final: prev: {
        opengauss = final.callPackage ./nix/package.nix { };
      };
    in
    flake-utils.lib.eachDefaultSystem
      (system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ overlay ];
          };
          opengaussWithClaude = pkgs.callPackage ./nix/package.nix {
            withClaudeCode = true;
          };
        in
        {
          packages.default = pkgs.opengauss;
          packages.opengauss = pkgs.opengauss;
          packages.opengauss-with-claude = opengaussWithClaude;

          apps.default = {
            type = "app";
            program = "${pkgs.opengauss}/bin/gauss";
          };
          apps.gauss = self.apps.${system}.default;

          checks.default = pkgs.opengauss;

          devShells.default = pkgs.mkShell {
            packages = [
              pkgs.opengauss
              pkgs.python312
              pkgs.uv
              pkgs.ripgrep
              pkgs.lean4
            ];
          };

          devShells.withClaude = pkgs.mkShell {
            packages = [
              opengaussWithClaude
              pkgs.python312
              pkgs.uv
              pkgs.ripgrep
              pkgs.claude-code
              pkgs.lean4
            ];
          };

          formatter = pkgs.nixpkgs-fmt;
        })
    // {
      overlays.default = overlay;
      homeManagerModules.default = import ./nix/home-manager.nix;
      homeManagerModules.opengauss = self.homeManagerModules.default;
    };
}
