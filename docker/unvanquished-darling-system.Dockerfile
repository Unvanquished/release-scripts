FROM ubuntu:focal

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

COPY docker/build-targets /docker

COPY docker/install-darling-dependencies /docker
COPY docker/install-brew-and-packages /docker

COPY build-release /
