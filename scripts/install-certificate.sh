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

EVENT_GATEWAY_URL=$(oc get eventgatewaycluster ademo-egw -o jsonpath='{..endpoints[?(@.name == "eventGateway")].uri}')
EVENT_GATEWAY_HOST=$(oc get eventgatewaycluster ademo-egw -o jsonpath='{..endpoints[?(@.name == "eventGateway")].uri}' | cut -d: -f1)
mv eem.crt eem.crt.original 2> /dev/null
mv eem.jks eem.jks.original 2> /dev/null
rm eem.crt eem.jks 2> /dev/null

echo Downloading certificate
openssl s_client -connect $EVENT_GATEWAY_URL -servername $EVENT_GATEWAY_HOST </dev/null | sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' > eem.crt

echo
echo Creating keystore
keytool -import -noprompt -trustcacerts -alias eem -file eem.crt \
    -keystore eem.jks -storepass password

oc create secret generic eem-client-app --from-file=eem.jks
