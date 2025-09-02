FROM debian:bullseye-slim

ARG build_linux=true

RUN mkdir /docker
COPY docker/common.sh /docker

COPY docker/fix-ownership /docker

COPY docker/install-system-dependencies /docker
RUN /docker/install-system-dependencies
