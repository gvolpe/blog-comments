{
  description = "Blog tools flake";

  inputs = {
    nixpkgs.url = github:nixos/nixpkgs/nixpkgs-unstable;
    flake-utils.url = github:numtide/flake-utils;
  };

  outputs = { self, nixpkgs, flake-utils }:
    let
      forSystem = system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          ruby = pkgs.ruby_2_7;
          bundle = "${ruby}/bin/bundle";
        in
        {
          devShell = pkgs.mkShell {
            name = "blog-tools-shell";
            buildInputs = [
              ruby # 2.7.5p203
              pkgs.python2 # 2.7.18
            ];
            shellHook = ''
              mkdir -p .nix-gems
              export GEM_HOME=$PWD/.nix-gems
              export GEM_PATH=$GEM_HOME
              export PATH=$GEM_HOME/bin:$PATH
              ${bundle} install
            '';
          };
        };
    in
    flake-utils.lib.eachDefaultSystem forSystem;
}
