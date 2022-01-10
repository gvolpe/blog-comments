# gvolpe's blog

## Principled Software Craftsmanship

A nix flake defines a shell providing the necessary tools to run the blog locally.

```console
$ nix flake show
git+file:///home/gvolpe/workspace/blog
└───devShell
    ├───aarch64-darwin: development environment 'blog-tools-shell'
    ├───aarch64-linux: development environment 'blog-tools-shell'
    ├───i686-linux: development environment 'blog-tools-shell'
    ├───x86_64-darwin: development environment 'blog-tools-shell'
    └───x86_64-linux: development environment 'blog-tools-shell'
```

### Run it locally

```console
$ nix develop
$ bundle exec jekyll serve
# ....................
 Auto-regeneration: enabled for '/home/gvolpe/workspace/blog'
Configuration file: /home/gvolpe/workspace/blog/_config.yml
    Server address: http://127.0.0.1:4000/blog/
  Server running... press ctrl-c to stop.
```

Made with [Zetsu](https://github.com/nandomoreirame/zetsu).
