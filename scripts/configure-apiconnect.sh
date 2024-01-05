#!/bin/bash
#******************************************************************************
# Licensed Materials - Property of IBM
# (c) Copyright IBM Corporation 2023, 2024. All Rights Reserved.
#
# Note to U.S. Government Users Restricted Rights:
# Use, duplication or disclosure restricted by GSA ADP Schedule
# Contract with IBM Corp.
#******************************************************************************

#******************************************************************************
# PLEASE NOTE: The configure-apic-v10.sh is for Demos only and not recommended for use anywhere else.
# The script uses unsupported internal features that are NOT suitable for production usecases.
#
# PREREQUISITES:
#   - Logged into cluster on the OC CLI (https://docs.openshift.com/container-platform/4.4/cli_reference/openshift_cli/getting-started-cli.html)
#
# PARAMETERS:
#   -n : <NAMESPACE> (string), Defaults to "cp4i"
#   -r : <RELEASE_NAME> (string), Defaults to "ademo"
#
# USAGE:
#   With default values
#     ./configure-apiconnect.sh
#
#   Overriding the NAMESPACE and release-name
#     ./configure-apiconnect -n cp4i-prod -r prod

CURRENT_DIR=$(dirname $0)

NAMESPACE="cp4i"
RELEASE_NAME="ademo"
ORG_NAME="ibm-demo"
DEBUG=true
TICK="\xE2\x9C\x85"
CROSS="\xE2\x9D\x8C"

function usage() {
  echo "Usage: $0 -n <NAMESPACE> -r <RELEASE_NAME>"
}

while getopts "a:n:r:" opt; do
  case ${opt} in
  n)
    NAMESPACE="$OPTARG"
    ;;
  r)
    RELEASE_NAME="$OPTARG"
    ;;
  \?)
    usage
    exit
    ;;
  esac
done

set -e

NAMESPACE="${NAMESPACE}"
PORG_ADMIN_EMAIL=${PORG_ADMIN_EMAIL:-"cp4i-admin@apiconnect.net"} # update to recipient of portal site creation email
PROVIDER_SECRET_NAME="cp4i-admin-creds"                           # corresponds to credentials obj currently hard-coded in configmap

# obtain endpoint info from APIC v10 routes
APIM_UI_EP=$(oc get route -n $NAMESPACE ${RELEASE_NAME}-mgmt-api-manager -o jsonpath='{.spec.host}')
CMC_UI_EP=$(oc get route -n $NAMESPACE ${RELEASE_NAME}-mgmt-admin -o jsonpath='{.spec.host}')
C_API_EP=$(oc get route -n $NAMESPACE ${RELEASE_NAME}-mgmt-consumer-api -o jsonpath='{.spec.host}')
API_EP=$(oc get route -n $NAMESPACE ${RELEASE_NAME}-mgmt-platform-api -o jsonpath='{.spec.host}')
PTL_WEB_EP=$(oc get route -n $NAMESPACE ${RELEASE_NAME}-ptl-portal-web -o jsonpath='{.spec.host}')
GW_EP=$(oc get route -n $NAMESPACE ${RELEASE_NAME}-gw-gateway -o jsonpath='{.spec.host}')

admin_idp=admin/default-idp-1
admin_password=$(oc get secret -n $NAMESPACE ${RELEASE_NAME}-mgmt-admin-pass -o json | jq -r .data.password | base64 --decode)

provider_user_registry=api-manager-lur
provider_idp=provider/default-idp-2
provider_username=apiconnect-admin
provider_email=${PORG_ADMIN_EMAIL:-"cp4i-admin@apiconnect.net"} # update to recipient of portal site creation email
provider_password=engageibmAPI1
provider_firstname=ApiConnect
provider_lastname=Administrator

MAIN_PORG_TITLE="(${ORG_NAME})"
MAIN_CATALOG="sandbox"
MAIN_CATALOG_TITLE="(${MAIN_CATALOG})"

RESULT=""

function authenticate() {
  realm=${1}
  username=${2}
  password=${3}

  echo "Authenticate as the ${username} user"

  response=`curl -X POST https://${API_EP}/api/token \
                 -s -k -H "Content-Type: application/json" -H "Accept: application/json" \
                 -d "{ \"realm\": \"${realm}\",
                       \"username\": \"${username}\",
                       \"password\": \"${password}\",
                       \"client_id\": \"599b7aef-8841-4ee2-88a0-84d49c4d6ff2\",
                       \"client_secret\": \"0ea28423-e73b-47d4-b40e-ddb45c48bb0c\",
                       \"grant_type\": \"password\" }" --retry 5`

  $DEBUG && echo "[DEBUG] $(echo ${response} | jq .)"
  
  if [[ "$(echo ${response} | jq -r '.status')" == "401" ]]; then
    printf "$CROSS"
    echo "[ERROR] Failed to authenticate"
    exit 1
  fi
  RESULT=`echo ${response} | jq -r '.access_token'`
  return 0
}

function create_org() {
  token=${1}
  org_name=${2}
  org_title=${3}
  owner_url=${4}

  echo "Checking if the provider org named ${org_name} already exists"
  response=`curl GET https://${API_EP}/api/orgs/${org_name} \
                 -s -k -H "Content-Type: application/json" -H "Accept: application/json" \
                 -H "Authorization: Bearer ${token}" --retry 5`
  $DEBUG && echo "[DEBUG] $(echo ${response} | jq .)"
  main_porg_url=`echo ${response} | jq -r '.url' | sed "s/^.*$NAMESPACE\/$RELEASE_NAME//"`

  if [[ "${main_porg_url}" == "null" ]]; then
    echo "Create the ${org_name} Provider Organization"
    response=`curl https://${API_EP}/api/cloud/orgs \
                   -s -k -H "Content-Type: application/json" -H "Accept: application/json" \
                   -H "Authorization: Bearer ${token}" \
                   -d "{ \"name\": \"${org_name}\",
                         \"title\": \"${org_title}\",
                         \"org_type\": \"provider\",
                         \"owner_url\": \"${owner_url}\" }" --retry 5`

    $DEBUG && echo "[DEBUG] $(echo ${response} | jq .)"
    main_porg_url=`echo ${response} | jq -r '.url' | sed "s/^.*$NAMESPACE\/$RELEASE_NAME//"`
    porg_id=$(echo ${response} | jq -r '.id')
  else
    porg_id=$(echo ${response} | jq -r '.id')
  fi
  RESULT="$main_porg_url"
  return 0
}

function add_cs_admin_user() {
  token=${1}
  org_name=${2}
  porg_url=${3}

  echo "Get the Provider Organization Roles for ${org_name}"
  
  headers="-H \"Accept: application/json\" -H \"Authorization: Bearer ${token}\""
  response=`curl -X GET ${porg_url}/roles \
                 -s -k -H "Accept: application/json" \
                 -H "Authorization: Bearer ${token}" --retry 5`

  $DEBUG && echo "[DEBUG] $(echo ${response})"
  administrator_role_url=$(echo ${response} | jq -r '.results[]|select(.name=="administrator")|.url')
  $DEBUG && echo "administrator_role_url=${administrator_role_url}"

  echo "Add the CS admin user to the list of members for ${org_name}"
  member_json='{
    "name": "cs-admin",
    "user": {
      "identity_provider": "integration-keycloak",
      "url": "https://'${API_EP}'/api/user-registries/admin/integration-keycloak/users/integration-admin"
    },
    "role_urls": [
      "'${administrator_role_url}'"
    ]
  }'

  headers="-H \"Content-Type: application/json\" -H \"Accept: application/json\" -H \"Authorization: Bearer ${token}\""
  data="-d \"$(echo $member_json | jq -c .)\""
  response=`curl -X POST ${porg_url}/members \
                 -s -k -H "Content-Type: application/json" -H "Accept: application/json" \
                 -H "Authorization: Bearer ${token}" \
                 -d ''$(echo $member_json | jq -c .)'' --retry 5`

  $DEBUG && echo "[DEBUG] $(echo ${response} | jq .)"
  return 0
}

function add_catalog() {
  token=${1}
  org_name=${2}
  porg_url=${3}
  catalog_name=${4}
  catalog_title=${5}

  echo "Checking if the catalog named ${catalog_name} already exists"
  response=`curl -X GET https://${API_EP}/api/catalogs/${org_name}/${catalog_name} \
                 -s -k -H "Content-Type: application/json" -H "Accept: application/json" \
                 -H "Authorization: Bearer ${token}" --retry 5`

  $DEBUG && echo "[DEBUG] $(echo ${response} | jq .)"

  catalogId=`echo ${response} | jq -r '.url' | sed "s/^.*$NAMESPACE\/$RELEASE_NAME//"`
  catalog_url="${catalogId}"

  $DEBUG && echo "[DEBUG] $(echo catalog_url=${catalog_url})"

  if [[ "${catalogId}" == "null" ]]; then
    echo "Create the Catalog"
    response=`curl -X POST ${porg_url}/catalogs \
                   -s -k -H "Content-Type: application/json" -H "Accept: application/json" \
                   -H "Authorization: Bearer ${token}" \
                   -d "{ \"name\": \"${catalog_name}\",
                         \"title\": \"${catalog_title}\" }" --retry 5`

    $DEBUG && echo "[DEBUG] $(echo ${response} | jq .)"
    catalogId=`echo ${response} | jq -r '.url' | sed "s/^.*$NAMESPACE\/$RELEASE_NAME//"`
    catalog_url="${catalogId}"
    $DEBUG && echo "[DEBUG] $(echo catalog_url=${catalog_url})"
  fi

  echo "Add a portal to the catalog named ${catalog_name}"
  response=`curl -X PUT ${catalog_url}/settings \
                 -s -k -H "Content-Type: application/json" -H "Accept: application/json" \
                 -H "Authorization: Bearer ${token}" \
                 -d "{
                       \"portal\": {
                         \"type\": \"drupal\",
                         \"endpoint\": \"https://${PTL_WEB_EP}/${org_name}/${catalog_name}\",
                         \"portal_service_url\": \"https://${API_EP}/api/orgs/${org_name}/portal-services/portal-service\"
                       }
                     }" --retry 5`
  
  $DEBUG && echo "[DEBUG] $(echo ${response})"
  return 0
}

function publishAPI() {

  token=${1}
  org_name=${2}
  catalog=${3}
  api=${4}
  product=${5}
  current_dir=$(dirname $0)

  # Publish product
  echo "[INFO]  Publishing product..."
  RES=$(curl -kLsS -X POST https://${API_EP}/api/catalogs/${org_name}/${catalog}/publish \
    -H "accept: application/json" \
    -H "authorization: Bearer ${token}" \
    -H "content-type: multipart/form-data" \
    -F "openapi=@${current_dir}/${api};type=application/yaml" \
    -F "product=@${current_dir}/${product};type=application/yaml" --retry 5)
  handle_res "${RES}"

  echo -e "[INFO]  ${TICK} Product published"
}

function handle_res() {
  local body=$1
  local status=$(echo ${body} | jq -r ".status")
  $DEBUG && echo "[DEBUG] res body: ${body}"
  $DEBUG && echo "[DEBUG] res status: ${status}"
  if [[ $status == "null" ]]; then
    OUTPUT="${body}"
  elif [[ $status == "400" ]]; then
    if [[ $body == *"already exists"* || $body == *"already subscribed"* ]]; then
      OUTPUT="${body}"
      echo "[INFO]  Resource already exists, continuing..."
    else
      echo -e "[ERROR] ${CROSS} Got 400 bad request"
      exit 1
    fi
  elif [[ $status == "409" ]]; then
    OUTPUT="${body}"
    echo "[INFO]  Resource already exists, continuing..."
  else
    echo -e "[ERROR] ${CROSS} Request failed: ${body}..."
    exit 1
  fi
}

authenticate "${admin_idp}" "admin" "${admin_password}"
admin_token="${RESULT}"

echo "Get the Admin Organization User Registries"
response=`curl -X GET https://${API_EP}/api/orgs/admin/user-registries \
               -s -k -H "Accept: application/json" \
               -H "Authorization: Bearer ${admin_token}" --retry 5`


$DEBUG && echo "[DEBUG] $(echo ${response} | jq .)"
api_manager_lur_url=$(echo ${response} | jq -r '.results[]|select(.name=="api-manager-lur")|.url')
api_manager_lur_id=$(echo ${response} | jq -r '.results[]|select(.name=="api-manager-lur")|.id')

$DEBUG && echo "api_manager_lur_url=${api_manager_lur_url}"
$DEBUG && echo "api_manager_lur_id=${api_manager_lur_id}"

echo "Get the Cloud Scope User Registries Setting"
response=`curl -X GET https://${API_EP}/api/cloud/settings/user-registries \
               -s -k -H "Accept: application/json" \
               -H "Authorization: Bearer ${admin_token}" --retry 5`
$DEBUG && echo "[DEBUG] $(echo ${response} | jq .)"

echo "Add the api-manager-lur to the list of providers"
new_registry_settings=$(echo ${response} | jq -c ".provider_user_registry_urls += [\"${api_manager_lur_url}\"]")
response=`curl -X PUT https://${API_EP}/api/cloud/settings/user-registries \
               -s -k -H "Content-Type: application/json" -H "Accept: application/json" \
               -H "Authorization: Bearer ${admin_token}" \
               -d ''${new_registry_settings}'' --retry 5`


$DEBUG && echo "[DEBUG] $(echo ${response} | jq .)"

echo "Checking if the user named ${provider_username} already exists"
response=`curl GET https://${API_EP}/api/user-registries/admin/${provider_user_registry}/users/${provider_username} \
               -s -k -H "Content-Type: application/json" -H "Accept: application/json" \
               -H "Authorization: Bearer ${admin_token}" --retry 5`

$DEBUG && echo "[DEBUG] $(echo ${response} | jq .)"
owner_url=`echo ${response} | jq -r '.url' | sed "s/\/integration\/apis\/$NAMESPACE\/$RELEASE_NAME//"`
if [[ "${owner_url}" == "null" ]]; then
  echo "Create the user named ${provider_username}"
    response=`curl https://${API_EP}/api/user-registries/admin/${provider_user_registry}/users \
                 -s -k -H "Content-Type: application/json" -H "Accept: application/json" \
                 -H "Authorization: Bearer ${admin_token}" \
                 -d "{ \"username\": \"${provider_username}\",
                       \"password\": \"${provider_password}\",
                       \"email\": \"${provider_email}\",
                       \"first_name\": \"${provider_firstname}\",
                       \"last_name\": \"${provider_lastname}\" }" --retry 5`

  $DEBUG && echo "[DEBUG] $(echo ${response} | jq .)"
  owner_url=`echo ${response} | jq -r '.url' | sed "s/\/integration\/apis\/$NAMESPACE\/$RELEASE_NAME//"`
fi
$DEBUG && echo "owner_url=${owner_url}"

echo "Create ${PROVIDER_SECRET_NAME} secret with credentials for the user named ${provider_username}"
OC_CMD=$(oc create secret generic -n ${NAMESPACE} ${PROVIDER_SECRET_NAME} \
  --from-literal=username=${provider_username} \
  --from-literal=password=${provider_password} || true)

status=$(echo ${body})
$DEBUG && echo "Create ${PROVIDER_SECRET_NAME} returned ${status}"

authenticate "${provider_idp}" "${provider_username}" "${provider_password}"
provider_token="${RESULT}"

# Main org/catalog
create_org "$admin_token" "${ORG_NAME}" "${MAIN_PORG_TITLE}" "${owner_url}"
main_porg_url="${RESULT}"
$DEBUG && echo "[DEBUG] $(echo token=${provider_token} org_name=${ORG_NAME} porg_url=${main_porg_url})"
add_cs_admin_user "${provider_token}" "${ORG_NAME}" "${main_porg_url}"
add_catalog "${provider_token}" "${ORG_NAME}" "${main_porg_url}" "${MAIN_CATALOG}" "${MAIN_CATALOG_TITLE}"

# pull together any necessary info from in-cluster resources
PROVIDER_CREDENTIALS=$(oc get secret $PROVIDER_SECRET_NAME -n $NAMESPACE -o json | jq .data)

for i in $(seq 1 60); do
  PORTAL_WWW_POD=$(oc get pods -n $NAMESPACE | grep -m1 "${RELEASE_NAME}-ptl.*www" | awk '{print $1}')
  $DEBUG && echo "[DEBUG] PORTAL_WWW_POD=${PORTAL_WWW_POD}"
  PORTAL_SITE_UUID=$(oc exec -n $NAMESPACE -it $PORTAL_WWW_POD -c admin -- /opt/ibm/bin/list_sites | awk '{print $1}')
  $DEBUG && echo "[DEBUG] PORTAL_SITE_UUID=${PORTAL_SITE_UUID}"
  PORTAL_SITE_RESET_URL=$(oc exec -n $NAMESPACE -it $PORTAL_WWW_POD -c admin -- /opt/ibm/bin/site_login_link $PORTAL_SITE_UUID | tail -1)
  $DEBUG && echo "[DEBUG] PORTAL_SITE_RESET_URL=${PORTAL_SITE_RESET_URL}"
  if [[ "$PORTAL_SITE_RESET_URL" =~ "https://$PTL_WEB_EP" ]]; then
    printf "$TICK"
    echo "[OK] Got the portal_site_password_reset_link"
    break
  else
    echo "Waiting for the portal_site_password_reset_link to be available (Attempt $i of 60)."
    echo "Checking again in one minute..."
    sleep 60
  fi
done

publishAPI "${provider_token}" "${ORG_NAME}" "${MAIN_CATALOG}" "resources/FlightAPI.yaml" "resources/FlightProduct.yaml"

API_MANAGER_USER=$(echo $PROVIDER_CREDENTIALS | jq -r .username | base64 --decode)
API_MANAGER_PASS=$(echo $PROVIDER_CREDENTIALS | jq -r .password | base64 --decode)

printf "$TICK"
echo "
********** Configuration **********
api_manager_ui: https://$APIM_UI_EP/manager
cloud_manager_ui: https://$CMC_UI_EP/admin
platform_api: https://$API_EP/api
consumer_api: https://$C_API_EP/consumer-api
provider_credentials (api manager):
  username: ${API_MANAGER_USER}
  password: ${API_MANAGER_PASS}
portal_site_password_reset_link: $PORTAL_SITE_RESET_URL"
