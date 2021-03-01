## Building static Linux binaries with Docker

For the `rev` argument, you should use a tag or a commit hash, rather than a branch
name, in order to avoid false caching.

```
# Build
docker build -t unvrel . --build-arg=rev=3173f3307
# Get outputs
docker create --name tmp unvrel
docker cp tmp:/Unvanquished/build/release/linux-amd64.zip .
docker rm tmp
```

It is recommended to check the results with [validate-release](https://github.com/Unvanquished/validate-release), e.g. `../validate-release/validate-release linux-amd64.zip`.
