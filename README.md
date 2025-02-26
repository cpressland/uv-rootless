# UV Rootless

Quick PoC for work for mitigating the issues described in https://github.com/astral-sh/uv/issues/7758

## Requirements
* Use of Azure Linux
* Run as a nonroot user, thankfully Azure Linux has one built in

## Usage
To test this project, simply execute `just test` and a `kind` cluster will be spawned, this app will be installed, and you should land in a nonroot shell inside the resulting pod. You can confirm Python works as expected by either simply calling `python`, or the hello world app this ships with `uv-rootless`.

Cleanup can be executed via `uv cleanup`

## Solution

```Dockerfile
FROM mcr.microsoft.com/azurelinux/base/core:3.0 AS build
COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv

ENV UV_LINK_MODE=copy \
    UV_COMPILE_BYTECODE=1 \
    UV_PYTHON=python3.13 \
    UV_PROJECT_ENVIRONMENT=/app

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
COPY --from=build /root/.local/share/uv /root/.local/share/uv
COPY --from=build /app /app
ENV PATH=/app/bin:$PATH
ENTRYPOINT [ "uv-rootless" ]
```

The above works well if the intent is to run the resulting application as root, however, the `/root` directory has permissions of `drwxr-x---` (750), and as `uv` installs `python-build-standalone` into `/root/.local/share/uv` this is inaccessible to the symlink setup in the `/app/bin` directory (`python -> /root/.local/share/uv/python/cpython-3.13.2-linux-x86_64-gnu/bin/python3.13`).

As I'm not aware of a mechanism to override this to install somewhere else, such as `/usr/local/bin`, I've made the following modifications:

```Dockerfile
FROM mcr.microsoft.com/azurelinux/base/core:3.0 AS build
COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv

ENV UV_LINK_MODE=copy \
    UV_COMPILE_BYTECODE=1 \
    UV_PYTHON=python3.13 \
    UV_PROJECT_ENVIRONMENT=/app

# Create the /app directory upfront and chown it to be owned by nonroot.
RUN mkdir -p /app && chown nonroot:nonroot /app
# Move the build context over to the nonroot user.
USER nonroot

# Add pyproject.toml and uv.lock to /_lock/ as a single operation for efficiency
COPY pyproject.toml uv.lock /_lock/
# Include the `uid` and `gid` options for the cache mount, 65532 == nonroot.
RUN --mount=type=cache,target=/home/nonroot/.cache,uid=65532,gid=65532 \
    cd /_lock && \
    uv sync \
    --locked \
    --no-dev \
    --no-install-project

# Chown files in /src to be owned by nonroot, else the build fails as an egg is created here.
COPY --chown=nonroot:nonroot . /src
# As above, cache but with the correct user.
RUN --mount=type=cache,target=/home/nonroot/.cache,uid=65532,gid=65532 \
    uv pip install \
    --python=$UV_PROJECT_ENVIRONMENT \
    --no-deps \
    /src

FROM mcr.microsoft.com/azurelinux/base/core:3.0
# Set the user to run as for all future commands.
USER nonroot
#  Update the path to pull files from, /home/nonroot instead of /root
COPY --from=build /home/nonroot/.local/share/uv /home/nonroot/.local/share/uv
COPY --from=build /app /app
ENV PATH=/app/bin:$PATH
ENTRYPOINT [ "uv-rootless" ]
```
