let GithubActions =
      https://raw.githubusercontent.com/gvolpe/github-actions-dhall/steps/cachix/package.dhall sha256:e87cb4b185337214f6b62425fbcf4056a4a3cd364a8d5c422e9db792ef9379d0

let setup =
      [ GithubActions.steps.checkout
      , GithubActions.steps.cachix/install-nix
      , GithubActions.steps.cachix/cachix { cache-name = "gvolpe-blog" }
      , GithubActions.steps.runAs
          { name = "Generating site 🚧"
          , run =
              "nix-shell --run \"bundle install && bundle exec rake site:generate\""
          }
      , GithubActions.steps.JamesIves/ghpages-deploy
          { branch = "gh-pages", folder = "_site" }
      ]

let publishJob =
      GithubActions.Job::{
      , runs-on = GithubActions.types.RunsOn.`ubuntu-18.04`
      , steps = setup
      }

in  GithubActions.Workflow::{
    , name = "Blog"
    , on = GithubActions.On::{
      , push = Some GithubActions.Push::{
        , branches = Some [ "master" ]
        , paths = Some [ "_posts/**", "images/**" ]
        }
      }
    , jobs = toMap { publish = publishJob }
    }
