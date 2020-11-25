let
  nixpkgs = fetchTarball {
    name   = "NixOS-unstable-13-05-2020";
    url    = "https://github.com/NixOS/nixpkgs-channels/archive/6bcb1dec8ea.tar.gz";
    sha256 = "04x750byjr397d3mfwkl09b2cz7z71fcykhvn8ypxrck8w7kdi1h";
  };
  pkgs = import nixpkgs {};

  ruby = pkgs.ruby_2_7;
  rubygems = (pkgs.rubygems.override { ruby = ruby; });

in pkgs.mkShell {
  buildInputs = [
    ruby # v2.7.1p83
    pkgs.python2
  ];

  shellHook = ''
    mkdir -p .nix-gems
    export GEM_HOME=$PWD/.nix-gems
    export GEM_PATH=$GEM_HOME
    export PATH=$GEM_HOME/bin:$PATH
  '';
}
