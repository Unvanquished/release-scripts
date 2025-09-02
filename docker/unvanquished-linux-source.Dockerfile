FROM unvanquished-linux-system

ARG reference

ARG engine_reference

COPY docker/clone-repositories /docker
RUN /docker/clone-repositories

COPY docker/build-targets /docker
COPY build-release /
