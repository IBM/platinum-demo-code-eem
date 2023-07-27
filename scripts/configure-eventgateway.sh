#!/bin/bash

NAMESPACE=${1:-"cp4i"}
RELEASE_NAME=${2:-"ademo"}
ORG_NAME=${3:-"ibm-demo"}

admin_idp=admin/default-idp-1
admin_password=$(oc get secret -n $NAMESPACE ${RELEASE_NAME}-mgmt-admin-pass -o json | jq -r .data.password | base64 --decode)

API_EP=$(oc get route -n $NAMESPACE ${RELEASE_NAME}-mgmt-platform-api -o jsonpath='{.spec.host}')

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


function get_org_id () {
  token=${1}
  
  echo "Getting ID for the admin provider org"
  response=`curl GET https://${API_EP}/api/orgs/admin \
                 -s -k -H "Content-Type: application/json" -H "Accept: application/json" \
                 -H "Authorization: Bearer ${token}" --retry 5`
  $DEBUG && echo "[DEBUG] $(echo ${response} | jq .)"
  main_porg_id=`echo ${response} | jq -r '.id' `
  echo "ID=$main_porg_id"
  RESULT="$main_porg_id"
  return 0
}

function get_keystores () {
  token=${1}
  org_id=${2}
  
  echo "Getting keystores for org ${org_id}"
  
  response=`curl GET https://${API_EP}/api/orgs/${org_id}/keystores \
                 -s -k -H "Content-Type: application/json" -H "Accept: application/json" \
                 -H "Authorization: Bearer ${token}" --retry 5`
  $DEBUG && echo "[DEBUG] $(echo ${response} | jq .)"
  RESULT="$response"
  return 0
}



function get_eventgateways () {
  token=${1}
  
  echo "Getting event gateways"
  
  response=`curl GET https://${API_EP}/api/cloud/integrations/gateway-service/event-gateway \
                 -s -k -H "Content-Type: application/json" -H "Accept: application/json" \
                 -H "Authorization: Bearer ${token}" --retry 5`
  $DEBUG && echo "[DEBUG] $(echo ${response} | jq .)"
  RESULT=`echo ${response} | jq -r '.url'`
  return 0
}

function create_keystore() {
  token=${1}
  org_id=${2}
  private_key=${3}
  public_key=${4}
  name=${5}
  title=${6}

  echo "Authenticate as the ${username} user"

  response=`curl --request POST https://${API_EP}/api/orgs/${org_id}/keystores \
                 -s -k -H "Content-Type: application/json" -H "Accept: application/json" \
                 -H "Authorization: Bearer ${token}" \
                 -d "{ \"name\": \"${name}\",
                       \"title\": \"${title}\",
                       \"summary\": \"\",
                       \"keystore\": \"${public_key}${private_key}\"
                       }" -v --retry 5 --trace curl.out`

  $DEBUG && echo "[DEBUG] $(echo ${response} | jq .)"
  
  if [[ "$(echo ${response} | jq -r '.status')" == "401" ]]; then
    printf "$CROSS"
    echo "[ERROR] Failed to authenticate"
    exit 1
  fi
  RESULT=`echo ${response} | jq -r '.url'`
  return 0
}

function create_truststore() {
  token=${1}
  org_id=${2}
  key_url=${3}

  echo "Authenticate as the ${username} user"

  response=`curl --request POST https://${API_EP}/api/orgs/${org_id}/truststores \
                 -s -k -H "Content-Type: application/json" -H "Accept: application/json" \
                 -H "Authorization: Bearer ${token}" \
                 -d "{ \"name\": \"event-gateway-truststore\",
                       \"title\": \"Event Gateway truststore Platinum Demo\",
                       \"summary\": \"\",
                       \"truststore\": \"${public_key}\"
                       }" -v --retry 5 --trace curl.out`

  $DEBUG && echo "[DEBUG] $(echo ${response} | jq .)"
  
  if [[ "$(echo ${response} | jq -r '.status')" == "401" ]]; then
    printf "$CROSS"
    echo "[ERROR] Failed to authenticate"
    exit 1
  fi
  RESULT=`echo ${response} | jq -r '.url'`
  return 0
}

function create_tls_client_profile() {
  token=${1}
  org_id=${2}
  key_url=${3}
  trust_url=${4}

  echo "Authenticate as the ${username} user"

  response=`curl --request POST https://${API_EP}/api/orgs/${org_id}/tls-client-profiles \
                 -s -k -H "Content-Type: application/json" -H "Accept: application/json" \
                 -H "Authorization: Bearer ${token}" \
                 -d "{ \"ciphers\": [
                            \"TLS_AES_256_GCM_SHA384\",
                            \"TLS_CHACHA20_POLY1305_SHA256\",
                            \"TLS_AES_128_GCM_SHA256\",
                            \"ECDHE_ECDSA_WITH_AES_256_GCM_SHA384\",
                            \"ECDHE_ECDSA_WITH_AES_256_CBC_SHA384\",
                            \"ECDHE_ECDSA_WITH_AES_128_GCM_SHA256\",
                            \"ECDHE_ECDSA_WITH_AES_128_CBC_SHA256\",
                            \"ECDHE_ECDSA_WITH_AES_256_CBC_SHA\",
                            \"ECDHE_ECDSA_WITH_AES_128_CBC_SHA\",
                            \"ECDHE_RSA_WITH_AES_256_GCM_SHA384\",
                            \"ECDHE_RSA_WITH_AES_256_CBC_SHA384\",
                            \"ECDHE_RSA_WITH_AES_128_GCM_SHA256\",
                            \"ECDHE_RSA_WITH_AES_128_CBC_SHA256\",
                            \"ECDHE_RSA_WITH_AES_256_CBC_SHA\",
                            \"ECDHE_RSA_WITH_AES_128_CBC_SHA\",
                            \"DHE_RSA_WITH_AES_256_GCM_SHA384\",
                            \"DHE_RSA_WITH_AES_256_CBC_SHA256\",
                            \"DHE_RSA_WITH_AES_128_GCM_SHA256\",
                            \"DHE_RSA_WITH_AES_128_CBC_SHA256\",
                            \"DHE_RSA_WITH_AES_256_CBC_SHA\",
                            \"DHE_RSA_WITH_AES_128_CBC_SHA\"
                        ],
                       \"title\": \"Event Gateway TLS Client Profile Platinum Demo\",
                       \"name\": \"event-gateway-tls-client-profile-platinum-demo\",
                       \"summary\": \"\",
                       \"insecure_server_connections\": true,
                       \"server_name_indication\": true,
                       \"keystore_url\": \"$key_url\",
                       \"truststore_url\": \"$trust_url\",
                       \"protocols\": [
                            \"tls_v1.2\", 
                            \"tls_v1.3\"
                        ]
                       }" -v --retry 5 --trace curl.out`


  $DEBUG && echo "[DEBUG] $(echo ${response} | jq .)"
  
  if [[ "$(echo ${response} | jq -r '.status')" == "401" ]]; then
    printf "$CROSS"
    echo "[ERROR] Failed to authenticate"
    exit 1
  fi
  RESULT=`echo ${response} | jq -r '.url'`
  return 0
}


function create_tls_server_profile() {
  token=${1}
  org_id=${2}
  key_url=${3}

  echo "Authenticate as the ${username} user"

  response=`curl --request POST https://${API_EP}/api/orgs/${org_id}/tls-server-profiles \
                 -s -k -H "Content-Type: application/json" -H "Accept: application/json" \
                 -H "Authorization: Bearer ${token}" \
                 -d "{ \"ciphers\": [
                            \"TLS_AES_256_GCM_SHA384\",
                            \"TLS_CHACHA20_POLY1305_SHA256\",
                            \"TLS_AES_128_GCM_SHA256\",
                            \"ECDHE_ECDSA_WITH_AES_256_GCM_SHA384\",
                            \"ECDHE_ECDSA_WITH_AES_256_CBC_SHA384\",
                            \"ECDHE_ECDSA_WITH_AES_128_GCM_SHA256\",
                            \"ECDHE_ECDSA_WITH_AES_128_CBC_SHA256\",
                            \"ECDHE_ECDSA_WITH_AES_256_CBC_SHA\",
                            \"ECDHE_ECDSA_WITH_AES_128_CBC_SHA\",
                            \"ECDHE_RSA_WITH_AES_256_GCM_SHA384\",
                            \"ECDHE_RSA_WITH_AES_256_CBC_SHA384\",
                            \"ECDHE_RSA_WITH_AES_128_GCM_SHA256\",
                            \"ECDHE_RSA_WITH_AES_128_CBC_SHA256\",
                            \"ECDHE_RSA_WITH_AES_256_CBC_SHA\",
                            \"ECDHE_RSA_WITH_AES_128_CBC_SHA\",
                            \"DHE_RSA_WITH_AES_256_GCM_SHA384\",
                            \"DHE_RSA_WITH_AES_256_CBC_SHA256\",
                            \"DHE_RSA_WITH_AES_128_GCM_SHA256\",
                            \"DHE_RSA_WITH_AES_128_CBC_SHA256\",
                            \"DHE_RSA_WITH_AES_256_CBC_SHA\",
                            \"DHE_RSA_WITH_AES_128_CBC_SHA\"
                        ],
                       \"title\": \"Event Gateway TLS Server Profile Platinum Demo\",
                       \"name\": \"event-gateway-tls-server-profile-platinum-demo\",
                       \"version\": \"1.0.0\",
                       \"summary\": \"\",
                       \"mutual_authentication\": \"none\",
                       \"limit_renegotiation\": true,
                       \"keystore_url\": \"$key_url\",
                       \"protocols\": [
                            \"tls_v1.2\", 
                            \"tls_v1.3\"
                        ]
                       }" -v --retry 5 --trace curl.out`


  $DEBUG && echo "[DEBUG] $(echo ${response} | jq .)"
  
  if [[ "$(echo ${response} | jq -r '.status')" == "401" ]]; then
    printf "$CROSS"
    echo "[ERROR] Failed to authenticate"
    exit 1
  fi
  RESULT=`echo ${response} | jq -r '.url'`
  return 0
}



function create_event_gateway() {
  token=${1}
  org_id=${2}
  ENDPOINT=${3}
  API_ENDPOINT=${4}
  TLS_CLIENT_PROFILE=${5}
  TLS_SERVER_PROFILE=${6}
  INTEGRATION_URL=${7}

  echo "Authenticate as the ${username} user"

  response=`curl --request POST https://${API_EP}/api/orgs/${org_id}/availability-zones/availability-zone-default/gateway-services \
                 -s -k -H "Content-Type: application/json" -H "Accept: application/json" \
                 -H "Authorization: Bearer ${token}" \
                 -d "{ \"communication_kind\": \"external\",
                       \"communication_to_analytics_with_jwt\": false,
                       \"name\": \"eem-event-gateway\",
                       \"title\": \"EEM Event Gateway\",
                       \"endpoint\": \"$ENDPOINT\",
                       \"api_endpoint_base\": \"$API_ENDPOINT\",
                       \"tls_client_profile_url\": \"$TLS_CLIENT_PROFILE\",
                       \"gateway_service_type\": \"event-gateway\",
                       \"visibility\": {
                            \"type\": \"public\"
                       },
                       \"sni\": [
                        {
                            \"host\": \"*\",
                            \"tls_server_profile_url\": \"$TLS_SERVER_PROFILE\"
                        }
                       ],
                       \"integration_url\": \"$INTEGRATION_URL\"
                       }" -v --retry 5 --trace curl.out`


  $DEBUG && echo "[DEBUG] $(echo ${response} | jq .)"
  
  if [[ "$(echo ${response} | jq -r '.status')" == "401" ]]; then
    printf "$CROSS"
    echo "[ERROR] Failed to authenticate"
    exit 1
  fi
  RESULT=`echo ${response} | jq -r '.url'`
  return 0
}

authenticate "${admin_idp}" "admin" "${admin_password}"
admin_token="${RESULT}"

get_org_id "$admin_token" 
org_id=$RESULT
$DEBUG && echo "[DEBUG] $(echo ${org_id})"

ca_crt=`oc get secret ademo-ingress-ca -o=jsonpath='{.data.ca\.crt}' | base64 -d | tr '\n\r' '*' | sed 's/*/\\\n\\\r/g'`
echo "ca_crt: $ca_crt"
tls_crt=`oc get secret ademo-ingress-ca -o=jsonpath='{.data.tls\.crt}' | base64 -d | tr '\n\r' '*' | sed 's/*/\\\n\\\r/g'`
echo "tls_crt: $tls_crt"
tls_key=`oc get secret ademo-ingress-ca -o=jsonpath='{.data.tls\.key}' | base64 -d | tr '\n\r' '*' | sed 's/*/\\\n\\\r/g'`
echo "tls_key: $tls_key"

#ca_crt=`oc get secret ademo-eem-ibm-eem-manager -o=jsonpath='{.data.ca\.crt}' | base64 -d | tr '\n\r' '*' | sed 's/*/\\\n\\\r/g'`
#echo "ca_crt: $ca_crt"
#tls_crt=`oc get secret ademo-eem-ibm-eem-manager -o=jsonpath='{.data.tls\.crt}' | base64 -d | tr '\n\r' '*' | sed 's/*/\\\n\\\r/g'`
#echo "tls_crt: $tls_crt"
#tls_key=`oc get secret ademo-eem-ibm-eem-manager -o=jsonpath='{.data.tls\.key}' | base64 -d | tr '\n\r' '*' | sed 's/*/\\\n\\\r/g'`
#echo "tls_key: $tls_key"

create_keystore "$admin_token" "$org_id" "$tls_key" "$tls_crt" "event-gateway-keystore" "Event Gateway Keystore Platinum Demo"
keystore_url="${RESULT}"

create_truststore "$admin_token" "$org_id" "$ca_crt"
truststore_url="${RESULT}"

echo "keystore_url=$keystore_url truststore_url=$truststore_url"

create_tls_client_profile "$admin_token" "$org_id" "$keystore_url" "$truststore_url" 
TLS_CLIENT_PROFILE="${RESULT}"

tls_crt=`oc get secret ademo-eem-ibm-eem-manager-ca -o=jsonpath='{.data.tls\.crt}' | base64 -d | tr '\n\r' '*' | sed 's/*/\\\n\\\r/g'`
echo "tls_crt: $tls_crt"

tls_key=`oc get secret ademo-eem-ibm-eem-manager-ca -o=jsonpath='{.data.tls\.key}' | base64 -d | tr '\n\r' '*' | sed 's/*/\\\n\\\r/g'`
echo "tls_key: $tls_key"

create_keystore "$admin_token" "$org_id" "$tls_crt" "$tls_key" "event-gateway-server-profile-key-store" "Event Gateway Server Profile Key Store"
server_profile_keystore_url="${RESULT}"

create_tls_server_profile "$admin_token" "$org_id" "$server_profile_keystore_url"
TLS_SERVER_PROFILE="${RESULT}"

gateway_management_endpoint=`oc get route ademo-eem-ibm-eem-apic -o jsonpath='{.spec.host}'`
echo "Using gateway_management_endpoint=$gateway_management_endpoint"

gateway_client_endpoint=`oc get route ademo-event-gw-ibm-egw-rt -o jsonpath='{.spec.host}'`
echo "Using gateway_client_endpoint=$gateway_client_endpoint"

get_eventgateways "$admin_token"
eventgateways_url="${RESULT}"

create_event_gateway "$admin_token" "$org_id" "https://$gateway_management_endpoint" "$gateway_client_endpoint:443" "$TLS_CLIENT_PROFILE" "$TLS_SERVER_PROFILE" "$eventgateways_url"
