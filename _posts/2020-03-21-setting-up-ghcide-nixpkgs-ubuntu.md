---
layout: post
title:  "Setting up Ghcide in Ubuntu with Nixpkgs"
date:   2020-03-21 19:28:00
categories: haskell nix ide
comments: true
---

If you use [Ubuntu](https://ubuntu.com/) or any other Linux distribution (AKA *distro*) together with [Nixpkgs](https://nixos.org/nixpkgs/), you might have noticed things don't play so well together. Nixpkgs has been mainly designed to work seamlessly in [Nix OS](https://nixos.org/nixos/); other distros are second class citizens.

Quoting the [Ghcide](https://github.com/digital-asset/ghcide) repository, it is defined as:

> A library for building Haskell IDE tooling

It is not defined as an IDE, because it only has a subset of the features [HIE (Haskell IDE Engine)](https://github.com/haskell/haskell-ide-engine) has. However, the good news is that the HIE and Ghcide teams are joining forces to create [One Haskell IDE to rule them all](https://neilmitchell.blogspot.com/2020/01/one-haskell-ide-to-rule-them-all.html)!

For what it's worth, I've been using HIE for a while together with my favorite text editor, [NeoVim](https://neovim.io/). It's got a lot of cool features but it's been quite buggy, in my experience.

Ghcide only offers a few features that work flawlessly, and my experience has been great so far. Though, setting it up to work properly in NeoVim on Ubuntu when all your software has been installed using Nixpkgs hasn't been easy at all.

<iframe width="680" height="350" src="https://www.youtube.com/embed/6bP_cpJkzdg" frameborder="0" allow="accelerometer; autoplay; encrypted-media; gyroscope; picture-in-picture" allowfullscreen></iframe>

This is the reason why I am writing this blog post. Aim at those who use Nixpkgs like me, in a different distro other than NixOS.

## Installing Ghcide

If you go to the main Ghcide repository, you'll find instructions on how to install it. For those using Nix, it is officially recommended using [Ghcide-Nix](https://github.com/hercules-ci/ghcide-nix).

If everything went well, you will find its binary in your Nix profile.

{% highlight haskell %}
λ ~ which ghcide
/home/gvolpe/.nix-profile/bin/ghcide
{% endhighlight %}

To verify Ghcide works, go to any Haskell project or standalone files, and run `ghcide`.

{% highlight haskell %}
λ ~ ghcide
ghcide version: 0.1.0 (GHC: 8.6.5) (PATH: /nix/store/02wcifqr53wjs1m5vn670b1avfy071az-ghcide-0.1.0-exe-ghcide/bin/ghcide)
Ghcide setup tester in /workspace/oss/types-matter.
Report bugs at https://github.com/digital-asset/ghcide/issues

Step 1/6: Finding files to test in /workspace/oss/types-matter
Found 6 files

Step 2/6: Looking for hie.yaml files that control setup
Found 1 cradle

Step 3/6, Cradle 1/1: Loading /workspace/oss/types-matter/hie.yaml

Step 4/6, Cradle 1/1: Loading GHC Session
> Warning: The package list for 'hackage.haskell.org' is 15 days old.
> Run 'cabal update' to get the latest list of available packages.
> Resolving dependencies...
> Build profile: -w ghc-8.6.5 -O1
> In order, the following will be built (use -v for more details):
>  - types-matter-0.1.0.0 (lib) (configuration changed)
> Configuring library for types-matter-0.1.0.0..
> Preprocessing library for types-matter-0.1.0.0..
ghcide: <command line>: cannot satisfy -package-id refined-0.4.4-ea7ce6a6d7ef3587351a3b3bdc4140a3a7bcd0f526627e28a7d5d456e39e9aa9:
    refined-0.4.4-ea7ce6a6d7ef3587351a3b3bdc4140a3a7bcd0f526627e28a7d5d456e39e9aa9 is unusable due to missing dependencies:
      QuickCheck-2.13.2-8aa3fcd8ac86c93ae5db4035083dd975e5b8f88ea826f8604a5748a04c7798bd aeson-1.4.6.0-3a4c86def05154b3acabc0a30d0acd96d235de9d3fd7ba28330e785107e8f5da exceptions-0.10.4-2e686fdff7a6bdbd62e24641169087c094e991de8ab3f6381a859306fd258e32 mtl-2.2.2 prettyprinter-1.3.0-08f8b1f2cf2a49ae7d9056e4ed9fbb3f75b812f789dbb30ab5e82b53b6cc42c8 transformers-0.5.6.2
    (use -v for more information)
{% endhighlight %}

Yes, you may get a similar output. So let's make it clear.

> All software installed by Nix works better within a Nix Shell.

You hear me. If you want this to work, make sure to you have a Nix Shell set up for your project and even run your text editor within a Nix Shell. *This is the only sane way*.

### Configuring Nix Shell

Nix shell is amazing! It creates an environment where all the necessary software is installed. Once you're done, you leave the shell and come back to your regular terminal. This way we avoid polluting our global environment, i.e. installing unnecessary global software such as Ruby, Node.js, etc.

Now, there are many ways to properly set up a Nix Shell for a Haskell project. I personally like to use [Cabal2Nix](https://github.com/NixOS/cabal2nix) to Nixify my [Cabal](https://github.com/haskell/cabal) projects. It basically creates a derivation with all the Haskell packages we need. Here's an example:

{% highlight nix %}
{ mkDerivation, aeson, async, base, bytestring, co-log-core
, containers, dhall, exceptions, hedis, postgresql-simple
, raw-strings-qq, refined, servant, servant-server, stdenv
, template-haskell, text, uuid, wai, wai-cors, warp, wreq
}:
mkDerivation {
  pname = "shopping-cart";
  version = "0.1.0.0";
  src = ./.;
  isLibrary = true;
  isExecutable = true;
  libraryHaskellDepends = [
    aeson async base bytestring co-log-core containers dhall exceptions
    hedis postgresql-simple raw-strings-qq refined servant
    servant-server template-haskell text uuid wai wai-cors warp wreq
  ];
  executableHaskellDepends = [ base ];
  description = "The Shopping Cart developed in PFP Scala for Haskell";
  license = stdenv.lib.licenses.asl20;
}
{% endhighlight %}

This derivation belongs in the `shopping-cart.nix` file, and it was created from a `shopping-cart.cabal` file as follows:

{% highlight haskell %}
cabal2nix . > shopping-cart.nix
{% endhighlight %}

In my current set up, I have three other Nix files that are needed in order to properly run this project within a Nix Shell: `default.nix`, `release.nix`, and `shell.nix`.

This is the content of `default.nix`, which indicates what GHC version we need:

{% highlight nix %}
{ nixpkgs ? import <nixpkgs> {}, compiler ? "ghc865" }:
nixpkgs.pkgs.haskell.packages.${compiler}.callPackage ./shopping-cart.nix { }
{% endhighlight %}

Next is the content of `release.nix`, which only refers to `default.nix`:

{% highlight nix %}
let
  pkgs = import <nixpkgs> { };
in
  pkgs.haskellPackages.callPackage ./default.nix { }
{% endhighlight %}

Finally, the most important one, `shell.nix`:

{% highlight nix %}
{ nixpkgs ? import <nixpkgs> {} }:
let
  inherit (nixpkgs) pkgs;
  inherit (pkgs) haskellPackages;

  project = import ./release.nix;
in
pkgs.stdenv.mkDerivation {
  name = "shell";
  buildInputs = project.env.nativeBuildInputs ++ [
    haskellPackages.cabal-install
    haskellPackages.hlint
  ];
  shellHook = ''
    export NIX_GHC="$(which ghc)"
    export NIX_GHCPKG="$(which ghc-pkg)"
    export NIX_GHC_DOCDIR="$NIX_GHC/../../share/doc/ghc/html"
    export NIX_GHC_LIBDIR="$(ghc --print-libdir)"
  '';
}
{% endhighlight %}

The important part here is our `shellHook`, which exports a few environment variables needed to get GHC properly detected by Nixpkgs within a Nix Shell.

Furthermore, these Nix files could probably be simplified into two files or maybe a single one but, to be honest, I haven't bothered in trying to do so. Nix is amazing when it works but, when it doesn't, it's a huge pain to find out what's going on.

You can find all these Nix files in this [Github repository](https://github.com/gvolpe/shopping-cart-haskell).

## Troubleshooting

There could be a lot of different things going wrong. We have seen a first common error above, but there could be a few others. Find below a summary of common issues.

### Error #1

The following error is one of the most common ones:

{% highlight haskell %}
cannot satisfy -package-id ghc-8.6.5
{% endhighlight %}

I have reported [this issue](https://github.com/digital-asset/ghcide/issues/439). This seems to happen because the GHC version detected by Ghcide is not the same it is expected by the Cabal project. Fortunately, this is fixed by the export of the environment variables defined in our `shellHook`.

Notice that the error message might show a different package, such as `aeson`, not only `ghc`. The fix seems to be the same, though.

### Error #2

You may get a lot of the following errors as well:

{% highlight haskell %}
Step 6/6: Type checking the files
File:     /workspace/oss/shopping-cart-haskell/app/Main.hs
Hidden:   no
Range:    5:17-5:28
Source:   not found
Severity: DsError
Message:
  Could not find module ‘Http.Server’
  It is not a module in the current program, or in any known package.
{% endhighlight %}

This is normally fixed by creating a specific `hie.yaml` file, indicating [hie-bios](https://github.com/mpickering/hie-bios) how to read our project. Here's the one defined in the Shopping Cart project:

{% highlight yaml %}
cradle: {cabal: {component: "lib:shopping-cart"}}
{% endhighlight %}

You will still get the same error with your `Setup.hs` file, defined by Cabal:

{% highlight haskell %}
Message:
  Could not load module ‘Distribution.Simple’
  It is a member of the hidden package ‘Cabal-2.4.0.1’.
  Perhaps you need to add ‘Cabal’ to the build-depends in your .cabal file.
Files that failed:
 * /workspace/oss/shopping-cart-haskell/Setup.hs
{% endhighlight %}

However, it doesn't matter. Ghcide will still work in our project; this is not an issue.

### Error #3

The following error is somewhat a nasty one:

{% highlight haskell %}
Error ghcide: <command line>: can't load .so/.DLL
{% endhighlight %}

If you stumble upon this one, make sure to update to the latest version. I had this error, which is reported [here](https://github.com/digital-asset/ghcide/issues/404), and got it fixed after updating Ghcide.

## Bonus Track

As I have got used to having a linter and a formatter integrated in NeoVim when using HIE, I kind of miss these features, which are probably going to land in the future Haskell IDE as plugins.

So I came up with a few (temporary) commands to get [HLint](https://github.com/ndmitchell/hlint) and [Brittany](https://github.com/lspitzner/brittany/) integrated in NeoVim.

{% highlight vim %}
nnoremap <leader>af :r !brittany --write-mode=inplace %:p<CR>
nnoremap <leader>al :AsyncRun hlint %:p<CR>
{% endhighlight %}

The first one runs `brittany` on the current file in the buffer and applies its output *inplace*. The latter runs `hlint`
for the current file in the buffer and it displays its result in a quickfix window. It uses the [asyncrun.vim](https://github.com/skywind3000/asyncrun.vim) plugin.

If you are interested in my full configuration, you can find it [here](https://github.com/gvolpe/nix-config).

The future of IDEs in Haskell is only getting brighter :)

Gabriel.
