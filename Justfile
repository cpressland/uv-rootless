build:
    docker build --pull -t uv_rootless .

run:
    docker run --rm -it uv_rootless

test:
    kind create cluster --name uv-rootless
    kubectl apply -k deploy
    kubectl config set-context --current --namespace uv-rootless
    sleep 5
    kubectl wait --for=condition=ready pod --all
    kubectl exec -it deploy/uv-rootless -- bash

exec:
    kubectl exec -it deploy/uv-rootless -- bash

clean:
    kind delete cluster --name uv-rootless
