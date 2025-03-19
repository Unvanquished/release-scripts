FROM unvanquished-common-system

ARG targets
RUN test -n "${targets}"

ARG reference

ARG engine_reference

RUN /docker/clone-repositories

RUN /docker/build-external-dependencies
