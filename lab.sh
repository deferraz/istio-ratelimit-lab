#!/bin/bash
usage()
{
    echo "Usage: ./lab.sh -c -d"
    exit 2
}

create_lab()
{
    echo "Installing Test Cluster..."
    kind create cluster --config ./kind.yaml --name istio-testing
    echo "Installing Istio..."
    helm repo add istio https://istio-release.storage.googleapis.com/charts
    helm install istio-base istio/base --set 'global.istioNamespace=istio-system' --version=1.12.5 --kube-context=kind-istio-testing -n istio-system --create-namespace
    helm install istiod istio/istiod --set 'global.istioNamespace=istio-system' --set 'meshConfig.accessLogFile=/dev/stdout' --set 'meshConfig.accessLogEncoding=TEXT' --version=1.12.5 --kube-context=kind-istio-testing -n istio-system --create-namespace --wait
    helm install istio-ingressgateway istio/gateway --set service.type=NodePort --set 'service.ports[0].name=status-port' --set 'service.ports[0].port=15021' --set 'service.ports[0].targetPort=15021' --set 'service.ports[0].nodePort=30002' --set 'service.ports[1].name=http2' --set 'service.ports[1].port=80' --set 'service.ports[1].targetPort=8080' --set 'service.ports[1].nodePort=30000' --set 'service.ports[2].name=https' --set 'service.ports[2].port=443' --set 'service.ports[2].targetPort=8443' --set 'service.ports[2].nodePort=30001' --kube-context kind-istio-testing -n istio-system --create-namespace
    echo "Installing Istio-Ratelimit-Operator..."
    helm repo add istio-ratelimit-operator https://zufardhiyaulhaq.com/istio-ratelimit-operator/charts/releases/
    helm install ratelimit-operator istio-ratelimit-operator/istio-ratelimit-operator --values ./ratelimitoperator-values.yaml --kube-context kind-istio-testing -n ratelimit-operator --create-namespace
    echo "Installing Redis..."
    kubectl apply --context=kind-istio-testing -f ./redis.yaml
    echo "Applying RatelimitService/GlobalRateLimitConfig/GlobalRateLimit manifests..."
    kubectl apply --context=kind-istio-testing -f ./ratelimitservice.yaml
    kubectl apply --context=kind-istio-testing -f ./globalratelimitconfig.yaml
    kubectl apply --context=kind-istio-testing -f ./globalratelimit.yaml
    echo "Deploying httpbin application..."
    kubectl apply -f <(istioctl kube-inject -f ./httpbin.yaml) --context=kind-istio-testing -n default
}

destroy_lab()
{
    kind delete cluster --name=istio-testing
}

while getopts 'cd' options
do
    case "${options}" in
        c) create_lab ;;
        d) destroy_lab ;;
        \?) usage ;;
    esac
done
exit 0