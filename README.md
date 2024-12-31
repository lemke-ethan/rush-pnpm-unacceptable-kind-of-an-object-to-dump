# rush-pnpm-unacceptable-kind-of-an-object-to-dump

An example project to show an error when using rush v5.147.0 with pnpm v9.13.2.

## dev environment

1. `docker build --pull -t rush-pnpm-dev .`
2. `docker run --mount type=bind,src=/var/run/docker.sock,target=/var/run/docker.sock --name rush-pnpm-dev -h ts-docker -it rush-pnpm-dev`

## reproduction steps

1. clone repo into `/home/devuser/git`
1. `rush update`
1. change `rushVersion` in `rush.json` to `"5.147.0"`
1. add a dev dependency to `foo`
1. `rush update`

or

1. clone repo into a new directory
1. change `rushVersion` in `rush.json` to `"5.147.0"`
1. `rush update`
