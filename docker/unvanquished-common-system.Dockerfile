FROM debian:buster-slim

RUN mkdir /docker
COPY docker/common.sh /docker

COPY docker/fix-ownership /docker

ARG targets
RUN test -n "${targets}"

COPY docker/install-system-dependencies /docker
RUN /docker/install-system-dependencies

ARG reference
RUN test -n "${reference}"

COPY docker/clone-repositories /docker

COPY docker/build-external-dependencies /docker

COPY docker/build-targets /docker

COPY build-release /
