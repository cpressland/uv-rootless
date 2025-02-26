FROM mcr.microsoft.com/azurelinux/base/core:3.0 AS build
COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv

ENV UV_LINK_MODE=copy \
    UV_COMPILE_BYTECODE=1 \
    UV_PYTHON=python3.13 \
    UV_PROJECT_ENVIRONMENT=/app

RUN mkdir -p /app && chown nonroot:nonroot /app
USER nonroot

COPY --chown=nonroot:nonroot pyproject.toml /_lock/
COPY --chown=nonroot:nonroot uv.lock /_lock/
RUN --mount=type=cache,target=/home/nonroot/.cache,uid=65532,gid=65532 \
    cd /_lock && \
    uv sync \
    --locked \
    --no-dev \
    --no-install-project

COPY --chown=nonroot:nonroot . /src
RUN --mount=type=cache,target=/home/nonroot/.cache,uid=65532,gid=65532 \
    uv pip install \
    --python=$UV_PROJECT_ENVIRONMENT \
    --no-deps \
    /src

FROM mcr.microsoft.com/azurelinux/base/core:3.0
USER nonroot
COPY --from=build /home/nonroot/.local/share/uv /home/nonroot/.local/share/uv
COPY --from=build /app /app
ENV PATH=/app/bin:$PATH
ENTRYPOINT [ "uv-rootless" ]
