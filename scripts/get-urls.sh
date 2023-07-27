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

line_separator () {
  echo "####################### $1 #######################"
}

print_usage () {

cat << EOF

Usage: get-urls.sh <namespace for deployment>"

Arguments:

namespace for deployment:      The namespace into which the resources are deployed.

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


line_separator "Cloud Pak for Integration User Interfaces"
PLATFORM_NAVIGATOR_URL=$(oc get route $namespace-navigator-pn -o jsonpath={.spec.host})
echo "Platform Navigator URL: https://$PLATFORM_NAVIGATOR_URL"
IBM_EVENT_STREAM_UI=$(oc get EventStreams ademo-es -o jsonpath={'.status.routes.ui'})
echo "Event Streams UI: https://$IBM_EVENT_STREAM_UI"
IBM_PORTAL_UI=$(oc get route ademo-ptl-portal-web -o jsonpath={.spec.host})
echo "Developer Portal UI: https://$IBM_PORTAL_UI/ibm-demo/sandbox"
echo ""
echo ""
line_separator "Component URLs"
EVENT_GATEWAY_URL=$(oc get eventgateway ademo-event-gw -o jsonpath='{..endpoints[?(@.name == "external-route-https")].uri}' | cut -d'/' -f3):443
echo "Event API endpoint base: $EVENT_GATEWAY_URL"
EEM_UI=$(oc get eem ademo-eem -o=jsonpath='{.status.endpoints[?(@.name=="ui")].uri}')
echo "Event Endpoint Management UI: $EEM_UI"
echo ""
echo ""
appUrl=$(oc get routes flight-board -o jsonpath={..spec.host} -n $namespace)
line_separator "Flight Board URLs"
echo Please use the following URLs to access the app.  Please note the use of http and NOT https.
echo
echo FlightBoard: https://$appUrl/FlightBoard
echo FlightBoard Manager: https://$appUrl/FlightBoard/manage-flights.html
echo
echo
