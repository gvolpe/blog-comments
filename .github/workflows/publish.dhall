let GithubActions =
      https://raw.githubusercontent.com/gvolpe/github-actions-dhall/steps/cachix/package.dhall sha256:4cd8f64770d8b015c2fd52bae5ddfb5b393eb7e0936f7f8e18f311c591b888a5

let DeployAction =
      GithubActions.Step::{
      , id = None Text
      , name = Some "Deploy 🚀"
      , uses = Some "JamesIves/github-pages-deploy-action@3.5.3"
      , run = None Text
      , with = Some
          ( toMap
              { ACCESS_TOKEN = "\${{ secrets.ACCESS_TOKEN }}"
              , BRANCH = "gh-pages"
              , FOLDER = "_site"
              }
          )
      }

let setup =
      [ GithubActions.steps.checkout
      , GithubActions.steps.cachix/install-nix
      , GithubActions.steps.cachix/cachix { cache-name = "gvolpe-blog" }
      , GithubActions.steps.run
          { run =
              "nix-shell --run \"bundle install && bundle exec rake site:generate\""
          }
      , DeployAction
      ]

in  GithubActions.Workflow::{
    , name = "Blog"
    , on = GithubActions.On::{
      , push = Some GithubActions.Push::{
        , branches = Some [ "master" ]
        , paths = Some [ "_posts/**" ]
        }
      }
    , jobs = toMap
        { publish = GithubActions.Job::{
          , name = "publish"
          , needs = None (List Text)
          , runs-on = GithubActions.types.RunsOn.`ubuntu-18.04`
          , steps = setup
          }
        }
    }
