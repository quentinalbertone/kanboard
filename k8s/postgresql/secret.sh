#!/bin/bash -e

function generate_unique {
    cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w $1 | head -n 1 #$1 length password
}

function postgresql_secret { # namespace
    cat <<EOF | tee  >(kubeseal --format yaml -n $1 > "postgresql_secret.yaml")
apiVersion: v1
kind: Secret
metadata:
  name: postgresql
type: Opaque
data:
  host: $(echo -n "postgres-svc" | base64)
  database: $(echo -n "kanboard" | base64)
  username: $(echo -n "kanboard" | base64)
  password: $(echo -n $(generate_unique 20) | base64)
EOF
}

[ $# != 1 ] && echo "Need namespace" && exit 1
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.12.1/controller.yaml 1>/dev/null
echo "Install sealed secret can take 10 sec"
kubectl wait --for=condition=available deployment/sealed-secrets-controller -n kube-system --timeout 1m

kustomize edit set namespace $1
postgresql_secret $1
kustomize build . | kubectl apply -f -
