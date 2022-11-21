FROM unvanquished-common-system

ARG targets
RUN test -n "${targets}"

ARG reference
RUN test -n "${reference}"

RUN /docker/clone-repositories

RUN /docker/build-external-dependencies
