# Unvanquished release scripts

## Scripts

- `docker-build`: Create docker images with build dependencies, fetch sources and build them with `build-release` and `make-unizip` in Docker in a controlled environment.
- `build-release`: The the entry point to generate the binaries and
Breakpad symbol files for a given platform. This script can be used outside of Docker but it may be difficult to set up the required static libraries.
- `make-unizip`: Produces an universal zip reusing the files produced by `build-release`. This script can be used outside of Docker.

Various cross compilers are used on Debian to build every Linux and Windows targets. The macOS targets are built on [Darling](https://www.darlinghq.org/) on Ubuntu.


## Building in docker

For the `reference` argument, you should use a tag or a commit hash, rather than a branch name, in order to avoid false caching.

It is recommended to check the results with [validate-release](https://github.com/Unvanquished/validate-release), for example:

```sh
../validate-release/validate-release build/release/linux-amd64.zip`
```


### Cleaning files from previous builds

```sh
./docker-build --clean
```


### Build static amd64 Linux engine binaries

```sh
./docker-build --reference 85dee939 --targets linux-amd64
```


### Clean-up, rebuild system images, and build an unizip with everything supported

```sh
./docker-build --clean --reimage --reference 85dee939 --targets all --unizip
```

Output files will be found in `build/release`.


### Built-in help

```
usage: docker-build [-h] [--clean] [--prune] [--reimage] [--reference [REFERENCE]]
                    [--targets TARGETS [TARGETS ...]] [--unizip] [--chown] [--docker PATH]

docker-build builds Unvanquished engine, virtual machine and universal zip in Docker.

options:
  -h, --help            show this help message and exit
  --clean               Delete previous target and universal zip builds.
  --prune               Delete all docker images from previous target builds.
  --reimage             Rebuild the system docker images for the targets to build.
  --reference [REFERbINLENCE]
                        Git reference for targets to build.
  --targets TARGETS [TARGETS ...]
                        List of targets. Requires a reference. Available targets: all linux-amd64
                        linux-i686 linux-arm64 linux-armhf windows-amd64 windows-i686 macos-amd64
                        vm
  --unizip              Make an universal zip out of built targets.
  --chown               Change ownership of produced files, this option should never be needed as
                        other tasks are expected to do it.
  --docker PATH         Path to the docker binary. Default: docker.

```


## Building with the simple Dockerfile

For the `rev` argument, you should use a tag or a commit hash, rather than a branch name, in order to avoid false caching.


### Build static Linux binaries
```
# Build
docker build -t unvrel . --build-arg=rev=3173f3307 --build-arg=targets=linux-amd64
# Get outputs
docker create --name tmp unvrel
docker cp tmp:/Unvanquished/build/release/linux-amd64.zip .
docker rm tmp
```


### Build everything supported by the simple Dockerfile
```
# Build
docker build -t unvrel . --build-arg=rev=8bef4ceee
# Get outputs
docker create --name tmp unvrel
docker cp tmp:/Unvanquished/build/release/unvanquished_0.zip .
docker rm tmp
```
