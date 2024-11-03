#! /usr/bin/bash

MANAGED_IDENTITY_CLIENT_ID=""
APPLICATION_SERVICE_PRINCIPAL_CLIENT_ID=""
FUNCTION_APP_NAME=""
FUNCTION_NAME=""

source ./environment_variables.sh

token=""


if command -v az >/dev/null; then

    echo -e "\e[93mUsing AZ CLI to log in...\e[37m"
    if ! az account show >/dev/null 2>&1; then 
        az login --identity --username "${MANAGED_IDENTITY_CLIENT_ID}" > /dev/null
    fi

    echo -e "\e[93mAcquiring Bearer Token...\e[37m"
    token=$(az account get-access-token --resource "api://${APPLICATION_SERVICE_PRINCIPAL_CLIENT_ID}" --query accessToken -o tsv)

fi


if [[ -z "${token}" ]]; then
    echo -e "\e[93mAZ CLI not found-- Defaulting to curl...\e[37m"
    echo -e "\e[93mAcquiring Bearer Token...\e[37m"
    token=$(curl -s \
        -H "Metadata: true" \
        "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=api://${APPLICATION_SERVICE_PRINCIPAL_CLIENT_ID}&client_id=${MANAGED_IDENTITY_CLIENT_ID}" | \
        jq --raw-output '.access_token')
fi 


echo -e "\e[93mMaking request with bearer token...\e[37m"
response=$(curl -s -X GET -H "Authorization: Bearer ${token}" "https://${FUNCTION_APP_NAME}.azurewebsites.net/api/${FUNCTION_NAME}")
echo -e "Response: \e[92m${response}\e[37m"
