#!/bin/bash
# © Copyright IBM Corporation 2022, 2024
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
BLOCK_STORAGE=${2:-"ocs-storagecluster-ceph-rbd"}
INSTALL_CP4I=${3:-true}

if [ -z $NAMESPACE ]
then
    echo "Usage: setup-software.sh <namespace for deployment>"
    exit 1
fi

oc new-project $NAMESPACE 2> /dev/null
oc project $NAMESPACE

if [ "$INSTALL_CP4I" = true ] ; then
  kubectl patch storageclass $BLOCK_STORAGE -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
fi

./install-operators.sh


if [ "$INSTALL_CP4I" = true ] ; then
  echo ""
  line_separator "START - INSTALLING PLATFORM NAVIGATOR"
  cat $SCRIPT_DIR/resources/platform-nav.yaml_template |
  sed "s#{{NAMESPACE}}#$NAMESPACE#g;" > $SCRIPT_DIR/resources/platform-nav.yaml

  oc apply -f resources/platform-nav.yaml
  sleep 30

  END=$((SECONDS+3600))
  PLATFORM_NAV=FAILED

  while [ $SECONDS -lt $END ]; do
    PLATFORM_NAV_PHASE=$(oc get platformnavigator platform-navigator -o=jsonpath={'.status.conditions[].type'})
    if [[ $PLATFORM_NAV_PHASE == "Ready" ]]
    then
      echo "Platform Navigator available"
      PLATFORM_NAV=SUCCESS
      break
    else
      echo "Waiting for Platform Navigator to be available"
      sleep 60
    fi
  done

  if [[ $PLATFORM_NAV == "SUCCESS" ]]
  then
    echo "SUCCESS"
  else
    echo "ERROR: Platform Navigator failed to install after 60 minutes"
    exit 1
  fi
  line_separator "SUCCESS - INSTALLING PLATFORM NAVIGATOR"
fi

echo ""
line_separator "START - INSTALLING API CONNECT"

cat $SCRIPT_DIR/resources/apic-cluster.yaml_template |
  sed "s#{{NAMESPACE}}#$NAMESPACE#g;" > $SCRIPT_DIR/resources/apic-cluster.yaml

oc apply -f resources/apic-cluster.yaml
sleep 30

END=$((SECONDS+3600))
APIC_INSTALL=FAILED

while [ $SECONDS -lt $END ]; do
    API_PHASE=$(oc get apiconnectcluster $API_CONNECT_CLUSTER_NAME -o=jsonpath={'..phase'})
    if [[ $API_PHASE == "Ready" ]]
    then
      echo "API Connect available"
      APIC_INSTALL=SUCCESS
      break
    else
      echo "Waiting for API Connect to be available"
      sleep 60
    fi
done

if [[ $APIC_INSTALL == "SUCCESS" ]]
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
      oc apply -f resources/kafka-users.yaml
      sleep 60
    fi
done

cat $SCRIPT_DIR/resources/kafka-topic.yaml_template |
sed "s#{{NAMESPACE}}#$NAMESPACE#g;" > $SCRIPT_DIR/resources/kafka-topic.yaml

oc apply -f $SCRIPT_DIR/resources/kafka-topic.yaml

line_separator "SUCCESS - IBM EVENT STREAMS CREATED"

echo ""
line_separator "START - INSTALLING IBM EVENT ENDPOINT MANAGEMENT"

APICONNECT_JWKS=$(oc get apiconnectcluster ademo -o=jsonpath='{.status.endpoints[?(@.name=="jwksUrl")].uri}')
echo "Using API Connect JWKS $APICONNECT_JWKS"

APICONNECT_PLATFORM_API=$(oc get apiconnectcluster ademo -o=jsonpath='{.status.endpoints[?(@.name=="platformApi")].uri}')
echo "Using API Connect Platform API $APICONNECT_PLATFORM_API"

APICONNECT_PLATFORM_API_HOSTNAME=$(echo "$APICONNECT_PLATFORM_API" | awk -F/ '{print $3}')
echo "Using $APICONNECT_PLATFORM_API_HOSTNAME to retrieve certificate"
echo | openssl s_client -connect $APICONNECT_PLATFORM_API_HOSTNAME:443 | sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' > certificate.crt

kubectl create secret generic apic-platform-cert --from-file=apic-platform.crt=certificate.crt

cat $SCRIPT_DIR/resources/createEventEndpointManager.yaml_template |
  sed "s#{{NAMESPACE}}#$NAMESPACE#g;" | 
  sed "s#{{JWKS_ENDPOINT}}#$APICONNECT_JWKS#g;" > $SCRIPT_DIR/resources/createEventEndpointManager.yaml

oc apply -f resources/createEventEndpointManager.yaml


END=$((SECONDS+3600))
EVENT_MANAGEMENT=FAILED
while [ $SECONDS -lt $END ]; do
    ES_PHASE=$(oc get EventEndpointManagement ademo-eem -o=jsonpath={'..phase'})
    if [[ $ES_PHASE == "Running" ]]
    then
      echo "Event Endpoint Management available"
      EVENT_MANAGEMENT=SUCCESS
      break
    else
      echo "Waiting for Event Endpoint Management to be available"
      sleep 60
    fi
done

rm resources/createEventEndpointManager.yaml


if [[ $EVENT_MANAGEMENT == "SUCCESS" ]]
then
  echo "SUCCESS"
else
  echo "ERROR: IBM Event Endpoint Management failed to install after 60 minutes"
  exit 1
fi


EEM_GATEWAY_URL=$(oc get eem ademo-eem -o=jsonpath='{.status.endpoints[?(@.name=="gateway")].uri}')
cat $SCRIPT_DIR/resources/createEventGateway.yaml_template |
  sed "s#{{NAMESPACE}}#$NAMESPACE#g;" | 
  sed "s#{{EEM_GATEWAY_URL}}#$EEM_GATEWAY_URL#g;" > $SCRIPT_DIR/resources/createEventGateway.yaml

oc apply -f resources/createEventGateway.yaml


END=$((SECONDS+3600))
EVENT_GATEWAY=FAILED
while [ $SECONDS -lt $END ]; do
    EG_PHASE=$(oc get EventGateway ademo-event-gw -o=jsonpath={'..phase'})
    if [[ $EG_PHASE == "Running" ]]
    then
      echo "Event Gateway available"
      EVENT_GATEWAY=SUCCESS
      break
    else
      echo "Waiting for Event Gateway to be available"
      sleep 60
    fi
done

rm resources/createEventGateway.yaml


if [[ $EVENT_GATEWAY == "SUCCESS" ]]
then
  echo "SUCCESS"
else
  echo "ERROR: IBM Event Gateway failed to install after 60 minutes"
  exit 1
fi

./configure-eventmanagement.sh $NAMESPACE
./configure-apiconnect.sh -n $NAMESPACE -r $API_CONNECT_CLUSTER_NAME
./configure-eventgateway.sh $NAMESPACE

PLATFORM_NAV_USERNAME=$(oc get secret integration-admin-initial-temporary-credentials -o=jsonpath={.data.username} | base64 -d)
PLATFORM_NAV_PASSWORD=$(oc get secret integration-admin-initial-temporary-credentials -o=jsonpath={.data.password} | base64 -d)
echo ""
echo ""
line_separator "User Interfaces"
PLATFORM_NAVIGATOR_URL=$(oc get route platform-navigator-pn -o jsonpath={'.spec.host'})
echo "Platform Navigator URL: https://$PLATFORM_NAVIGATOR_URL"
echo "Username: $PLATFORM_NAV_USERNAME"
echo "Password: $PLATFORM_NAV_PASSWORD"
IBM_EVENT_STREAM_UI=$(oc get EventStreams ademo-es -o jsonpath={'.status.routes.ui'})
echo "Event Streams UI: https://$IBM_EVENT_STREAM_UI"
EEM_UI=$(oc get eem ademo-eem -o=jsonpath='{.status.endpoints[?(@.name=="ui")].uri}')
echo "Event Endpoint Management UI: $EEM_UI"
echo ""
