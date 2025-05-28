#!/bin/bash
#******************************************************************************
# Licensed Materials - Property of IBM
# (c) Copyright IBM Corporation 2023, 2024. All Rights Reserved.
#
# Note to U.S. Government Users Restricted Rights:
# Use, duplication or disclosure restricted by GSA ADP Schedule
# Contract with IBM Corp.
#******************************************************************************

namespace=${1:-"cp4i"}
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
INSTALL_CP4I=${2:-true}

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
      currentCSV=$(oc get sub -n ${installedNamespace} ${subscriptionName} -o jsonpath={.status.currentCSV} 2>/dev/null)
      ((time = time + $wait_time))
      sleep $wait_time
      if [ $time -ge 240 ]; then
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
      if [ $time -ge 240 ]; then
        echo "INFO: Waited over four minutes and the status is $phase"
        exit 1
      fi
    done

}

oc new-project $namespace
echo "Create the namespace $namespace"

if [ "$INSTALL_CP4I" = true ] ; then
    echo "Apply IBM Catalog..."
    oc apply -f $SCRIPT_DIR/resources/ibm-catalog-source.yaml
    oc apply -f $SCRIPT_DIR/resources/operator-group.yaml

    echo "Install IBM Common Services..."
    cat $SCRIPT_DIR/resources/ibm-common-services.yaml_template |
      sed "s#{{NAMESPACE}}#$namespace#g;" > $SCRIPT_DIR/resources/ibm-common-services.yaml
    oc apply -f $SCRIPT_DIR/resources/ibm-common-services.yaml
    rm $SCRIPT_DIR/resources/ibm-common-services.yaml
    wait_for_operator_start ibm-common-service-operator $namespace
  
    echo "Install Cert Manager..."
    cat $SCRIPT_DIR/resources/cert-manager-redhat.yaml_template |
      sed "s#{{NAMESPACE}}#$namespace#g;" > $SCRIPT_DIR/resources/cert-manager-redhat.yaml
    oc apply -f $SCRIPT_DIR/resources/cert-manager-redhat.yaml
    rm $SCRIPT_DIR/resources/cert-manager-redhat.yaml
    wait_for_operator_start openshift-cert-manager-operator cert-manager-operator

    echo "Install Platform Nav..."
    cat $SCRIPT_DIR/resources/platform-nav-operator-subscription.yaml_template |
      sed "s#{{NAMESPACE}}#$namespace#g;" > $SCRIPT_DIR/resources/platform-nav-operator-subscription.yaml
    oc apply -f $SCRIPT_DIR/resources/platform-nav-operator-subscription.yaml
    rm $SCRIPT_DIR/resources/platform-nav-operator-subscription.yaml
    wait_for_operator_start ibm-integration-platform-navigator $namespace

fi

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


cat $SCRIPT_DIR/resources/eem-operator-subscription.yaml_template |
  sed "s#{{NAMESPACE}}#$namespace#g;" > $SCRIPT_DIR/resources/eem-operator-subscription.yaml

oc apply -f $SCRIPT_DIR/resources/eem-operator-subscription.yaml

rm $SCRIPT_DIR/resources/eem-operator-subscription.yaml

wait_for_operator_start ibm-eventendpointmanagement  $namespace


echo "Completed installation of API Connect and Event Streams operators successfully"