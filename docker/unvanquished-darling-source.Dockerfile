FROM unvanquished-darling-darling

ARG reference
RUN test -n "${reference}"

RUN /docker/clone-repositories
