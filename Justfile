build:
    docker build --pull -t uv_rootless .

run:
    docker run --rm -it uv_rootless
