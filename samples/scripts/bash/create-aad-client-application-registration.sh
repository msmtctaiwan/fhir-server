#!/bin/bash

APIAPPID=""
DISPLAYNAME=""
REPLYURL="https://www.getpostman.com/oauth2/callback"
IDENTIFIERURI="" 

usage ()
{
  echo "Usage: "
  echo "  $0 -a <api aad app id> -d <display name> -r <reply url>"
  exit
}

while [[ $# -gt 0 ]]
do
key="$1"

case $key in
    -a|--api-app-id|--app-id)
    APIAPPID="$2"
    shift # past argument
    shift # past value
    ;;
    -d|--display-name)
    DISPLAYNAME="$2"
    shift # past argument
    shift # past value
    ;;
    -r|--reply-url)
    REPLYURL="$2"
    shift # past argument
    shift # past value
    ;;
    -i|--identifier-uri)
    IDENTIFIERURI="$2"
    shift # past argument
    shift # past value
    ;;
    -h|--help)
    usage
    ;;
    *)    # unknown option
    echo "Unknown argument $1"
    usage
    ;;
esac
done


[ -z $APIAPPID ] && echo "Please provide FHIR Service API App ID" && usage
[ -z $DISPLAYNAME ] && echo "Please provide Display Name" && usage

if [[ -z $IDENTIFIERURI ]]; then
    IDENTIFIERURI="https://${DISPLAYNAME}"
fi

context=$(az account show)
if [[ $? -ne 0 ]]; then
    echo "Please log in with 'az login' and set an account with 'az account set'"
    exit 1
fi

#Grab a few details we will need
apiAppReg=$(az ad app show --id $APIAPPID)
apiAppId=$(echo $apiAppReg | jq -r .appId)
apiAppScopeId=$(echo $apiAppReg | jq -r .additionalProperties.oauth2Permissions[0].id)

# Some GUID values for Azure Active Directory 
# https://blogs.msdn.microsoft.com/aaddevsup/2018/06/06/guid-table-for-windows-azure-active-directory-permissions/ 
# Windows AAD Resource ID: 
windowsAadResourceId="00000002-0000-0000-c000-000000000000" 
# 'Sign in and read user profile' permission (scope) 
signInScope="311a71cc-e848-46a1-bdf8-97ff7156d8e6" 

aadPermissions="{ \"resourceAppId\": \"${windowsAadResourceId}\", \"resourceAccess\": [{ \"id\": \"${signInScope}\", \"type\": \"Scope\"}]}"
apiPermissions="{ \"resourceAppId\": \"${apiAppId}\", \"resourceAccess\": [{ \"id\": \"${apiAppScopeId}\", \"type\": \"Scope\"}]}"

apiPermissionsManifest="[${aadPermissions},${apiPermissions}]"


#Create app registration for client application
clientSecret=$(uuidgen | base64)
clientAppReg=$(az ad app create --display-name ${DISPLAYNAME} --password ${clientSecret} --identifier-uris "${IDENTIFIERURI}" --required-resource-access "${apiPermissionsManifest}" --reply-urls ${REPLYURL})
clientAppId=$(echo $clientAppReg | jq -r .appId)
apiAppAudience=$(echo $apiAppReg | jq -r .identifierUris[0])
aadTenantId=$(echo $context | jq -r .tenantId)
environmentName=$(echo $context | jq -r .environmentName)
aadEndpoint=$(az cloud show --name $environmentName | jq -r .endpoints.activeDirectory)
authUrl="${aadEndpoint}/${aadTenantId}/oauth2/authorize?resource=${apiAppAudience}"
tokenUrl="${aadEndpoint}/${aadTenantId}/oauth2/token"

#Service principal for API 
sp=$(az ad sp create --id ${clientAppId})

#Return summary information
cat << EOF
{ 
    "AppId": "${clientAppId}", 
    "AppSecret": "${clientSecret}",
    "ReplyUrl": "${REPLYURL}",
    "AuthUrl": "${authUrl}",
    "TokenUrl": "${tokenUrl}"
}
EOF
