FROM unvanquished-linux-source

ARG targets
RUN test -n "${targets}"

COPY docker/build-external-dependencies /docker
RUN /docker/build-external-dependencies
