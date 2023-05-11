#!/bin/bash

namespace=${1:-"cp4i"}
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

function wait_for_pipeline_types () {
    echo "Checking for pipeline types to be created...."
    createdTime=""
    wait_time=1
    time=0

    while [[ -z "$createdTime" ]]; do
      createdTime=$(oc get crd triggertemplates.triggers.tekton.dev -o jsonpath={..status} 2>/dev/null)
      ((time = time + $wait_time))
      sleep $wait_time
      if [ $time -ge 300 ]; then
        echo "ERROR: Failed after waiting for 5 minutes"
        exit 1
      fi
      if [ $time -ge 180 ]; then
        echo "INFO: Waited over three minute"
        exit 1
      fi
    done

}


function wait_for_operator_start() {
    subscriptionName=${1}
    installedNamespace=${2}
    echo "Waiting on subscription $subscriptionName in namespace $installedNamespace"

    wait_time=1
    time=0
    currentCSV=""
    while [[ -z "$currentCSV" ]]; do
      currentCSV=$(oc get subscriptions -n ${installedNamespace} ${subscriptionName} -o jsonpath={.status.currentCSV} 2>/dev/null)
      ((time = time + $wait_time))
      sleep $wait_time
      if [ $time -ge 300 ]; then
        echo "ERROR: Failed after waiting for 5 minutes"
        exit 1
      fi
    done

    echo "Waiting on CSV status $currentCSV"
    phase=""
    until [[ "$phase" == "Succeeded" ]]; do
      phase=$(oc get csv -n ${installedNamespace} ${currentCSV} -o jsonpath={.status.phase} 2>/dev/null)
      sleep $wait_time
      if [ $time -ge 600 ]; then
        echo "ERROR: Failed after waiting for 10 minutes"
        exit 1
      fi
      if [ $time -ge 300 ]; then
        echo "INFO: Waited over five minute and the status is $phase"
        exit 1
      fi
    done

}

oc new-project $namespace

oc apply -f $SCRIPT_DIR/resources/pipeline-operator-subscription.yaml

wait_for_operator_start openshift-pipelines-operator openshift-operators

wait_for_pipeline_types 

cat $SCRIPT_DIR/resources/apic-operator-subscription.yaml_template |
  sed "s#{{NAMESPACE}}#$namespace#g;" > $SCRIPT_DIR/resources/apic-operator-subscription.yaml

oc apply -f $SCRIPT_DIR/resources/apic-operator-subscription.yaml

rm $SCRIPT_DIR/resources/apic-operator-subscription.yaml

wait_for_operator_start ibm-apiconnect $namespace

cat $SCRIPT_DIR/resources/es-operator-subscription.yaml_template |
  sed "s#{{NAMESPACE}}#$namespace#g;" > $SCRIPT_DIR/resources/es-operator-subscription.yaml

oc apply -f $SCRIPT_DIR/resources/es-operator-subscription.yaml

rm $SCRIPT_DIR/resources/es-operator-subscription.yaml

wait_for_operator_start ibm-eventstreams  $namespace

echo "Completed installation of API Connect and Event Streams operators successfully"