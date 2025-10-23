FROM docker.io/debian:trixie-slim

ARG build_vm=true

RUN mkdir /docker
COPY docker/common.sh /docker

COPY docker/fix-ownership /docker

COPY docker/install-system-dependencies /docker
RUN /docker/install-system-dependencies
