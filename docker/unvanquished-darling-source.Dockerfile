FROM unvanquished-darling-darling

ARG reference

ARG engine_reference

COPY docker/clone-repositories /docker
RUN /docker/clone-repositories
