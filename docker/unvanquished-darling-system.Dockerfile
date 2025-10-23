FROM docker.io/ubuntu:focal

ARG build_macos=true

RUN mkdir /docker
COPY docker/common.sh /docker

COPY docker/fix-ownership /docker

COPY docker/install-system-dependencies /docker
RUN /docker/install-system-dependencies

COPY docker/install-darling-dependencies /docker
COPY docker/install-xcode-and-packages /docker
