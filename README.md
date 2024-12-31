# rush-pnpm-unacceptable-kind-of-an-object-to-dump

An example project to show an error when using rush v5.147.0 with pnpm v9.13.2.

## dev environment

1. `docker build --pull --build-arg --target ts-dev -t ts-dev .`
1. `docker run -p 3002:3000 --mount type=bind,src=/var/run/docker.sock,target=/var/run/docker.sock --shm-size=2gb --detach-keys='ctrl-z,z' --name ts-dev -e DISPLAY=host.docker.internal:0 --security-opt seccomp=custom-seccomp.json -h ts-docker -it ts-dev`

## reproduction steps

1. clone repo into `/home/devuser/git`
1. `rush update`
1. change `rushVersion` in `rush.json` to `"5.147.0"`
1. `rush update`
