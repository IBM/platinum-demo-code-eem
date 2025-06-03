#!/bin/sh
timestamp=$(date +%Y-%m-%d_%H:%M:%S)
echo "$timestamp Starting script"
echo "Installing cert manager operator"
oc apply -f resources/cert-manager-operatorgroup.yaml
oc apply -f resources/cert-manager-subscription.yaml
echo "Getting operator version..."
SUB_NAME=''
while [ -z "$SUB_NAME" ]; do
    sleep 3
    SUB_NAME=$(oc get deployment cert-manager-operator-controller-manager -n cert-manager-operator --ignore-not-found -o jsonpath='{.metadata.labels.olm\.owner}')
done
echo "Operator: " $SUB_NAME
echo "Waiting for cert manager operator to be ready..."
while ! oc wait --for=jsonpath='{.status.phase}'=Succeeded \
    csv/$SUB_NAME -n cert-manager-operator 2>/dev/null; do sleep 20; done
echo "Cert manager operator is ready"
echo "Done!"
timestamp=$(date +%Y-%m-%d_%H:%M:%S)
echo "$timestamp Script completed"
