#!/usr/bin/env bash

set -xe

if [ "down" == "$1" ] || ["destroy" == "$1"]; then
  k3d cluster delete test
  exit 0
fi

k3d cluster create test -p "443:443@loadbalancer" --k3s-arg="--disable=traefik@server:0"

# https://knative.dev/docs/install/yaml-install/serving/install-serving-with-yaml/#install-the-knative-serving-component
kubectl apply -f https://github.com/knative/serving/releases/download/knative-v1.14.1/serving-crds.yaml
kubectl apply -f https://github.com/knative/serving/releases/download/knative-v1.14.1/serving-core.yaml

kubectl apply -k kourier

kubectl patch configmap/config-network \
  --namespace knative-serving \
  --type merge \
  --patch '{"data":{"ingress-class":"kourier.ingress.networking.knative.dev"}}'


kubectl patch configmap/config-domain \
  --namespace knative-serving \
  --type merge \
  --patch '{"data":{"localhost.pomerium.io":""}}'

kubectl patch --namespace knative-serving configmap/config-features \
 --type merge \
 --patch '{"data":{"kubernetes.podspec-persistent-volume-claim": "enabled", "kubernetes.podspec-persistent-volume-write": "enabled"}}'

kubectl apply -k pomerium

kubectl create secret tls pomerium-wildcard-tls \
  --namespace=pomerium \
  --cert=./certs/_wildcard.localhost.pomerium.io.crt \
  --key=./certs/_wildcard.localhost.pomerium.io.key

kubectl create secret generic idp -n pomerium \
    --from-literal=client_id=mynewclient \
    --from-literal=client_secret='N3CVVi6h5mZ2BiEg14wR2zTCHpFzMUur'

kubectl apply -f pomerium.yaml

kubectl apply -f httpbin.yaml

kn service create whoami --image traefik/whoami --port 80
kn service create code-server --image codercom/code-server:latest --port 8080 --arg --auth=none --arg --disable-telemetry --arg --trusted-origins --arg '*'
kn service create code-server --image codercom/code-server:latest --port 8080 --arg --auth=none --arg --disable-telemetry
kn service delete code-server
