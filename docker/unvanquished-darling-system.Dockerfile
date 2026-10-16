FROM docker.io/ubuntu:noble

ARG build_macos=true

RUN mkdir /docker
COPY docker/common.sh /docker

COPY docker/fix-ownership /docker

COPY docker/install-system-dependencies /docker
RUN /docker/install-system-dependencies

COPY docker/install-darling-dependencies /docker
COPY docker/install-xcode-and-packages /docker

RUN mkdir /tools
COPY tools/macos-extract-clt-dmg.pl /tools
COPY tools/macos-extract-pbzx.pl /tools
COPY tools/macos-replace-clt.sh /tools
COPY tools/macos-set-clt-env.sh /tools
