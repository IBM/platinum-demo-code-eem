#!/bin/bash

NAMESPACE=${1:-"cp4i"}
RELEASE_NAME=${2:-"ademo"}
ORG_NAME=${3:-"ibm-demo"}

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

if [[ $OSTYPE == 'darwin'* ]]; then
  echo 'Running on macOS'
  EEM_ROLES=$(cat $SCRIPT_DIR/resources/eem-roles.json | base64)
  EEM_USERS=$(cat $SCRIPT_DIR/resources/eem-users.json | base64)
else
  EEM_ROLES=$(cat $SCRIPT_DIR/resources/eem-roles.json | base64 -w0)
  EEM_USERS=$(cat $SCRIPT_DIR/resources/eem-users.json | base64 -w0)
fi

RESPONSE=$(oc patch secret ademo-eem-ibm-eem-user-credentials -n $NAMESPACE -p '{"data": {"user-credentials.json": "'$EEM_USERS'"}}')
echo Patched ademo-eem-ibm-eem-user-credentials $RESPONSE

RESPONSE=$(oc patch secret ademo-eem-ibm-eem-user-roles -n $NAMESPACE -p '{"data": {"user-mapping.json": "'$EEM_ROLES'"}}')
echo Patched ademo-eem-ibm-eem-user-roles $RESPONSE