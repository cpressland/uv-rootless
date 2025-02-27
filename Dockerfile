FROM mcr.microsoft.com/azurelinux/base/core:3.0 AS build
COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv

ENV UV_LINK_MODE=copy \
    UV_COMPILE_BYTECODE=1 \
    UV_PYTHON=python3.13 \
    UV_PROJECT_ENVIRONMENT=/app \
    UV_PYTHON_INSTALL_DIR=/usr/share/uv/python

COPY pyproject.toml /_lock/
COPY uv.lock /_lock/
RUN --mount=type=cache,target=/root/.cache \
    cd /_lock && \
    uv sync \
    --locked \
    --no-dev \
    --no-install-project

COPY . /src
RUN --mount=type=cache,target=/root/.cache \
    uv pip install \
    --python=$UV_PROJECT_ENVIRONMENT \
    --no-deps \
    /src

FROM mcr.microsoft.com/azurelinux/base/core:3.0
USER nonroot
COPY --from=build /usr/share/uv /usr/share/uv
COPY --from=build --chown=nonroot:nonroot /app /app
ENV PATH=/app/bin:$PATH
ENTRYPOINT [ "uv-rootless" ]
