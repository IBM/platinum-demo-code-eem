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

NAMESPACE=$1
API_CONNECT_CLUSTER_NAME=ademo

if [ -z $NAMESPACE ]
then
    echo "Usage: setup-software.sh <namespace for deployment>"
    exit 1
fi

oc new-project $NAMESPACE 2> /dev/null
oc project $NAMESPACE

echo ""
line_separator "START - VERIFY API CONNECT CONFIGURED"
echo "Checking that API Connect is installed and ready...."
API_INSTALLED=$(oc get apiconnectcluster $API_CONNECT_CLUSTER_NAME -o=jsonpath={'..phase'})
if [[ $API_INSTALLED == "Ready" ]]
then
  echo "API Connect found and ready"
else
  echo "ERROR: API Connect status was $API_INSTALLED"
  echo "Please verify that you have installed and configured API Connect"
  exit 1
fi
line_separator "SUCCESS - VERIFY API CONNECT CONFIGURED"

echo ""
line_separator "START - UPDATING API CONNECT CLUSTER WITH EVENT MANAGEMENT"

oc patch apiconnectcluster $API_CONNECT_CLUSTER_NAME -n $NAMESPACE --patch-file resources/deltaAPIConnectCluster.yaml --type=merge
sleep 30

END=$((SECONDS+3600))
EVENT_MANAGEMENT=FAILED

while [ $SECONDS -lt $END ]; do
    API_PHASE=$(oc get apiconnectcluster $API_CONNECT_CLUSTER_NAME -o=jsonpath={'..phase'})
    if [[ $API_INSTALLED == "Ready" ]]
    then
      echo "Event Management available"
      EVENT_MANAGEMENT=SUCCESS
      break
    else
      echo "Waiting for Event Management to be available"
      sleep 60
    fi
done

if [[ $EVENT_MANAGEMENT == "SUCCESS" ]]
then
  echo "SUCCESS"
else
  echo "ERROR: Event Management failed to install after 60 minutes"
  exit 1
fi

line_separator "SUCCESS - UPDATING API CONNECT CLUSTER WITH EVENT MANAGEMENT"

echo ""
line_separator "START - INSTALLING IBM EVENT STREAMS"
oc apply -f resources/createEventStream.yaml


END=$((SECONDS+3600))
EVENT_STREAM=FAILED
while [ $SECONDS -lt $END ]; do
    ES_PHASE=$(oc get EventStreams ademo-es -o=jsonpath={'..phase'})
    if [[ $ES_PHASE == "Ready" ]]
    then
      echo "Event Streams available"
      EVENT_STREAM=SUCCESS
      break
    else
      echo "Waiting for Event Stream to be available"
      sleep 60
    fi
done

line_separator "SUCCESS - IBM EVENT STREAMS CREATED"

echo ""
echo ""
line_separator "User Interfaces"
PLATFORM_NAVIGATOR_URL=$(oc get route cp4i-navigator-pn -o jsonpath={.spec.host})
echo "Platform Navigator URL: https://$PLATFORM_NAVIGATOR_URL"
IBM_EVENT_STREAM_UI=$(oc get EventStreams ademo-es -o jsonpath={'.status.routes.ui'})
echo "Event Streams UI: https://$IBM_EVENT_STREAM_UI"
echo ""
echo ""
line_separator "Component URLs"
EVENT_GATEWAY_URL=$(oc get eventgatewaycluster ademo-egw -o jsonpath='{..endpoints[?(@.name == "eventGateway")].uri}')
echo "Event API endpoint base: $EVENT_GATEWAY_URL"
EVENT_GATEWAY_MANAGER=$(oc get eventgatewaycluster ademo-egw -o jsonpath='{..endpoints[?(@.name == "eventGatewayManager")].uri}')
echo "Event Management endpoint: $EVENT_GATEWAY_MANAGER"
