#!/bin/bash
# © Copyright IBM Corporation 2022
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

print_usage () {

cat << EOF

Usage: setup-client-app.sh <namespace for deployment> <kafka client id> <gateway username> <gateway password> <flight number>"

Arguments:

namespace for deployment:      The namespace into which the app will be deployed.  It will be
                               created if necessary.

EOF
    exit 1
}

line_separator () {
  echo "####################### $1 #######################"
}

namespace=${1:-"cp4i"}
export GATEWAY_ENDPOINT=$(oc get eventgatewaycluster ademo-egw -o jsonpath='{..endpoints[?(@.name == "eventGateway")].uri}')
export KAFKA_CLIENT_ID=$2
export GATEWAY_USERNAME=$3
export GATEWAY_PASSWORD=$4
export FLIGHT_NUMBER=$5
export NAMESPACE=$namespace


echo "Using $namespace $GATEWAY_ENDPOINT $KAFKA_CLIENT_ID $GATEWAY_USERNAME $GATEWAY_PASSWORD $FLIGHT_NUMBER"

if [[ -z $namespace || -z $GATEWAY_ENDPOINT || -z $KAFKA_CLIENT_ID || -z $GATEWAY_USERNAME || -z $GATEWAY_PASSWORD || -z $FLIGHT_NUMBER ]]
then
    print_usage
fi

oc new-project $namespace 2> /dev/null
oc project $namespace

echo ""
line_separator "START - INSTALLING CLIENT APP"
echo "Installing app into $namespace"

# Create flight board image
echo Creating flight board image
oc create is flightclientapp 2> /dev/null
oc apply -f resources/createFlightClientAppImage.yaml
oc start-build build-flight-client-app-image

sleep 60



( echo "cat <<EOF" ; cat resources/deployClientAppTemplate.yaml ; echo EOF ) | sh > resources/deployClientApp.yaml

# Create configmap
oc apply -f resources/deployClientApp.yaml

oc wait --for=condition=Available=True deployment/flight-client-app --timeout=60s

line_separator "SUCCESS - INSTALLING APP"

echo ""
line_separator "CONNECTING TO CONTAINER"
oc logs -f deployment.apps/flight-client-app

exit 0
