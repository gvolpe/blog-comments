let
  pkgs = import (fetchTarball "https://github.com/NixOS/nixpkgs-channels/archive/1fe82110feb.tar.gz") {};
  stdenv = pkgs.stdenv;

  ruby = pkgs.ruby_2_7;
  rubygems = (pkgs.rubygems.override { ruby = ruby; });

in stdenv.mkDerivation rec {
  name = "blog";
  buildInputs = [
    ruby
  ];

  shellHook = ''
    mkdir -p .nix-gems
    export GEM_HOME=$PWD/.nix-gems
    export GEM_PATH=$GEM_HOME
    export PATH=$GEM_HOME/bin:$PATH
    bundle install
  '';

}
