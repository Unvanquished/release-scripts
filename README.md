`build-release` is the entry point to generate the binaries and Breakpad symbol files for a given
platform. Currently the working configurations are Linux hosts for Linux, NaCl, or Windows
targets and binaries and MSYS2 for Windows targets. For Linux, it is difficult to set up the
required static libraries, so the Docker build is especially useful.

## Building in docker

For the `rev` argument, you should use a tag or a commit hash, rather than a branch
name, in order to avoid false caching.

It is recommended to check the results with [validate-release](https://github.com/Unvanquished/validate-release),
e.g. `../validate-release/validate-release linux-amd64.zip`.

### Build static Linux binaries
```
# Build
docker build -t unvrel . --build-arg=rev=3173f3307 --build-arg=targets=linux-amd64
# Get outputs
docker create --name tmp unvrel
docker cp tmp:/Unvanquished/build/release/linux-amd64.zip .
docker rm tmp
```

### Build everything supported in Docker
```
# Build
docker build -t unvrel . --build-arg=rev=8bef4ceee
# Get outputs
docker create --name tmp unvrel
docker cp tmp:/Unvanquished/build/release/unvanquished_0.zip .
docker rm tmp
```
