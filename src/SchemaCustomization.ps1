# Connecting to Azure Parameters
$tenantID = "3272c93e-8a98-419b-bfd3-2e22147c29e6"
$applicationID = "f9f54fd2-bc58-4a82-b9bf-40d4d4fbebf0"

$CustomSchema=get-content ".\schema.csv"
 
# Authenticate to Microsoft Grpah
  
$url = "https://login.microsoftonline.com/$tenantId/oauth2/token"
$resource = "https://graph.microsoft.com/"
$restbody = @{
         grant_type    = 'client_credentials'
         client_id     = $applicationID
         client_secret = $clientKey
         resource      = $resource
}
     
 # Get the return Auth Token
$token = Invoke-RestMethod -Method POST -Uri $url -Body $restbody
     
# Set the baseurl to MS Graph-API (BETA API)
$baseUrl = 'https://graph.microsoft.com/beta'
         
# Pack the token into a header for future API calls
$header = @{
          'Authorization' = "$($Token.token_type) $($Token.access_token)"
         'Content-type'  = "application/json"
}
 
# Define the UPN for the user we want to get userPurpose for

 
# Build the Base URL for the API call{}
$url = $baseUrl + "/servicePrincipals/9e7bd53b-5056-4b45-805b-e1425042c097/synchronization/jobs/ecma.3272c93e8a98419bbfd32e22147c29e6.7a2286ea-37d2-443a-9dde-63fcdbc152a4/schema"
$namespace=Read-Host "Please provide SCIM namespace URI for your custom attributes"

# Doing a GET for the current Schema of the application
$CurrentSchema = Invoke-RestMethod -Method GET -headers $header -Uri $url 

#Getting the the custom Atts for the txt file 
foreach ($att in $CustomSchema.split(','))
{
    $newAttribute=$null
    $newAttribute=@"
    {
        "anchor": false,
        "caseExact": false,
        "defaultValue": null,
        "flowNullValues": false,
        "multivalued": false,
        "mutability": "Immutable",
        "name": "$namespace`:$att",
        "required": false,
        "type": "String",
        "apiExpressions": [],
        "metadata": [],
        "referencedObjects": []
    }
"@ 

$objectToAdd = ConvertFrom-Json -InputObject $newAttribute
$CurrentSchema.directories[1].objects[0].attributes+=$objectToAdd

}

$SchemaAsJson=ConvertTo-Json -InputObject $CurrentSchema -Depth 20
$urlput= $baseUrl + "/servicePrincipals/9e7bd53b-5056-4b45-805b-e1425042c097/synchronization/jobs/ecma.3272c93e8a98419bbfd32e22147c29e6.7a2286ea-37d2-443a-9dde-63fcdbc152a4/schema"

try {
   Invoke-RestMethod -Method Put -headers $header -Uri $urlput -Body ($SchemaAsJson) -ContentType "application/json" 
   Write-Host "The Schema was successfully updated!!!" -ForegroundColor Green
}
 catch [System.Net.WebException] {   
     $respStream = $_.Exception.Response.GetResponseStream()
     $reader = New-Object System.IO.StreamReader($respStream)
     $respBody = $reader.ReadToEnd() | ConvertFrom-Json
    if ( [string]::IsNullOrEmpty($respbody.error.message ))
    {
        Write-Host $respbody.error.message -ForegroundColor Red

    }
    else
    {
        $respBody;
 
    }
}