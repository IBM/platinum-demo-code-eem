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

NAMESPACE=${1:-"cp4i"}
API_CONNECT_CLUSTER_NAME=ademo
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

if [ -z $NAMESPACE ]
then
    echo "Usage: setup-software.sh <namespace for deployment>"
    exit 1
fi

oc new-project $NAMESPACE 2> /dev/null
oc project $NAMESPACE

./install-operators.sh

echo ""
line_separator "START - INSTALLING API CONNECT"

cat $SCRIPT_DIR/resources/apic-cluster.yaml_template |
  sed "s#{{NAMESPACE}}#$NAMESPACE#g;" > $SCRIPT_DIR/resources/apic-cluster.yaml

oc apply -f resources/apic-cluster.yaml
sleep 30

END=$((SECONDS+3600))
EVENT_MANAGEMENT=FAILED

while [ $SECONDS -lt $END ]; do
    API_PHASE=$(oc get apiconnectcluster $API_CONNECT_CLUSTER_NAME -o=jsonpath={'..phase'})
    if [[ $API_PHASE == "Ready" ]]
    then
      echo "API Connect available"
      EVENT_MANAGEMENT=SUCCESS
      break
    else
      echo "Waiting for API Connect to be available"
      sleep 60
    fi
done

if [[ $EVENT_MANAGEMENT == "SUCCESS" ]]
then
  echo "SUCCESS"
else
  echo "ERROR: API Connect failed to install after 60 minutes"
  exit 1
fi

line_separator "SUCCESS - INSTALLING API CONNECT"

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

./configure-apiconnect.sh -n $NAMESPACE -r $API_CONNECT_CLUSTER_NAME

echo ""
echo ""
line_separator "User Interfaces"
PLATFORM_NAVIGATOR_URL=$(oc get route platform-navigator-pn -o jsonpath={'.spec.host'})
echo "Platform Navigator URL: https://$PLATFORM_NAVIGATOR_URL"
IBM_EVENT_STREAM_UI=$(oc get EventStreams ademo-es -o jsonpath={'.status.routes.ui'})
echo "Event Streams UI: https://$IBM_EVENT_STREAM_UI"
echo ""
