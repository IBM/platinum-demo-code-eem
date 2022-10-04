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

Usage: setup-app.sh <namespace for deployment>"

Arguments:

namespace for deployment:      The namespace into which the app will be deployed.  It will be
                               created if necessary.

EOF
    exit 1
}

line_separator () {
  echo "####################### $1 #######################"
}

namespace=$1

if [ -z $namespace ]
then
    print_usage
fi

oc new-project $namespace 2> /dev/null
oc project $namespace

echo ""
line_separator "START - INSTALLING APP"
echo "Installing app into $namespace"

rest_service=`oc get service -n $namespace -l app.kubernetes.io/name=rest-producer,eventstreams.ibm.com/kind=EventStreams --no-headers=true | awk '/external/{print $1}'`
if [ -z $rest_service ]
then
    echo "Event Streams not found in namespace $namespace"
    exit 1
fi

export REST_ENDPOINT=$rest_service.$namespace.svc
echo Using $REST_ENDPOINT as the Event Streams REST endpoint

( echo "cat <<EOF" ; cat resources/AppConfigMapTemplate.yaml ; echo EOF ) | sh > resources/AppConfigMap.yaml

# Create configmap
oc apply -f resources/AppConfigMap.yaml

# Create flight board image
echo Creating flight board image
oc create is flightboard 2> /dev/null
oc apply -f resources/createFlightBoardImage.yaml
oc start-build build-flight-board-image

sleep 60s

oc adm policy add-scc-to-user -z default anyuid
oc apply -f resources/deployApp.yaml

# Wait for pods to be ready then run cronjob straight away to populate flights
oc wait --for=condition=Available=True deployment/flight-board --timeout=60s

appUrl=$(oc get routes flight-board -o jsonpath={..spec.host} -n $namespace |grep flight-board)
line_separator "SUCCESS - INSTALLING APP"

echo
echo
echo Please use the following URLs to access the app.  Please note the use of http and NOT https.
echo
echo FlightBoard: http://$appUrl/FlightBoard
echo FlightBoard Manager: http://$appUrl/FlightBoard/manage-flights.html

exit 0
