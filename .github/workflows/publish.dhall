let GithubActions =
      https://raw.githubusercontent.com/gvolpe/github-actions-dhall/steps/cachix/package.dhall sha256:61c95b4aebdeab1a8019a3e835aef7df9f5af983f926d7fe909d2f5e9a0e4aa3

let setup =
      [ GithubActions.steps.checkout
      , GithubActions.steps.cachix/install-nix
      , GithubActions.steps.cachix/cachix { cache-name = "gvolpe-blog" }
      ,   GithubActions.steps.run
            { run =
                "nix-shell --run \"bundle install && bundle exec rake site:generate\""
            }
        // { name = Some "Generating site 🚧" }
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
