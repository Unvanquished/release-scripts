FROM debian:buster-slim

# Toolchain dependencies for Unvanquished, Daemon, external_deps, or build-release
ENV TOOLCHAIN_DEPS=' \
    autoconf \
    cmake \
    curl \
    g++ \
    g++-mingw-w64-i686 \
    g++-mingw-w64-x86-64 \
    git \
    libtool \
    make \
    p7zip-full \
    python2 \
    python3-jinja2 \
    python3-yaml \
    rsync \
'

# Libraries statically linked into the Linux binaries of Daemon
ENV DAEMON_LINUX_STATIC_DEPS=' \
    libfreetype6-dev \
    libgmp-dev \
    libjpeg-dev \
    libogg-dev \
    libopus-dev \
    libopusfile-dev \
    libpng-dev \
    libvorbis-dev \
    libwebp-dev \
    nettle-dev \
    zlib1g-dev \
'

# These are needed for building Daemon or its dependencies but not statically linked into the binary.
# The display-related ones are relevant for SDL configuration and are taken from
# https://wiki.libsdl.org/FAQLinux#How_do_I_get_all_the_dependencies_for_building_SDL_on_Ubuntu.3F
# The audio ones are relevant for OpenAL configuration.
ENV DAEMON_LINUX_AV_DEPS=' \
    libasound2-dev \
    libaudio-dev \
    libgl1-mesa-dev \
    libjack-jackd2-dev \
    libpulse-dev \
    libx11-dev \
    libxcursor-dev \
    libxext-dev \
    libxi-dev \
    libxinerama-dev \
    libxrandr-dev \
    libxss-dev \
    libxxf86vm-dev \
'

RUN apt-get update && apt-get install -y $TOOLCHAIN_DEPS $DAEMON_LINUX_STATIC_DEPS $DAEMON_LINUX_AV_DEPS

RUN update-alternatives --set i686-w64-mingw32-gcc /usr/bin/i686-w64-mingw32-gcc-posix && \
    update-alternatives --set i686-w64-mingw32-g++ /usr/bin/i686-w64-mingw32-g++-posix && \
    update-alternatives --set x86_64-w64-mingw32-gcc /usr/bin/x86_64-w64-mingw32-gcc-posix && \
    update-alternatives --set x86_64-w64-mingw32-g++ /usr/bin/x86_64-w64-mingw32-g++-posix

ARG rev
RUN test -n "$rev"
WORKDIR /Unvanquished
# Assume the desired revision of Unvanquished is near the tip of some branch (last 20 commits)
RUN git clone --depth 20 --no-single-branch https://github.com/Unvanquished/Unvanquished . && \
    git checkout "$rev" && \
    git submodule update --init --depth 1 --recursive

WORKDIR /Unvanquished/daemon/external_deps
# Build some static libraries in the cases where the package manager didn't provide a satisfactory one.
# openal, glew, ncurses: a static library is not provided
# geoip: there is a static library but it seems broken - "archive has no index"
# sdl2: the static library is configured to have non-optional dependencies on some dynamic libs
# curl: static libraries are configured with unneeded protocols that have extra dynamic dependencies
RUN ./build.sh linux64 geoip curl sdl2 glew openal ncurses naclsdk naclports
RUN ./build.sh linux64 install

COPY build-release /
WORKDIR /Unvanquished
ARG targets='linux-amd64 windows-i686 windows-amd64 vm'
RUN /build-release -j`nproc` ${targets}

COPY build-release make-unizip unizip-readme.txt /
RUN /make-unizip /Unvanquished/build/release
