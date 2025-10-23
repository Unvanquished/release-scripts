FROM docker.io/debian:trixie-slim

RUN mkdir /docker
COPY docker/common.sh /docker

COPY docker/fix-ownership /docker

RUN apt-get update

RUN apt-get install --yes p7zip-full

COPY docker/build-unizip /docker

COPY make-unizip unizip-readme.txt /
