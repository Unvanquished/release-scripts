FROM unvanquished-darling-source

ARG targets
RUN test -n "${targets}"

COPY docker/build-external-dependencies /docker
RUN /docker/build-external-dependencies

COPY docker/build-targets /docker
COPY build-release /
