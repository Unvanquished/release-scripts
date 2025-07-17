FROM debian:bullseye-slim

RUN mkdir /docker
COPY docker/common.sh /docker

COPY docker/fix-ownership /docker
