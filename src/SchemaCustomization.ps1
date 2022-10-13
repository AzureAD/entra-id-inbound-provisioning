## Import Mg Modules
Import-Module Microsoft.Graph.Applications -ErrorAction Stop

## Connect to MgGraph Module
Connect-MgGraph -Scopes 'Directory.ReadWrite.All' -ErrorAction Stop
Select-MgProfile -Name beta

## Parameters
$servicePrincipalId = 'a678ea24-a8dc-4ac6-89f4-96b597c36620'
#$namespace = Read-Host "Please provide SCIM namespace URI for your custom attributes"
$namespace = "urn:ietf:params:scim:schemas:extension:csv:1.0:User"
$CustomSchema = Import-Csv -Path ".\sampledata\csv-with-1000-records.csv"

## Lookup Service Principal
$SyncJob = Get-MgServicePrincipalSynchronizationJob -ServicePrincipalId $servicePrincipalId
     

# Define the UPN for the user we want to get userPurpose for


# Doing a GET for the current Schema of the application
$SyncJobSchema = Get-MgServicePrincipalSynchronizationJobSchema -ServicePrincipalId $servicePrincipalId -SynchronizationJobId $SyncJob.Id
#$CurrentSchema = Invoke-RestMethod -Method GET -headers $header -Uri $url 

## Add custom schema attributes
foreach ($AttributeName in $CustomSchema[0].psobject.Properties.Name) {
    
    if ($SyncJobSchema.Directories[0].Objects[0].Attributes.Name.Contains($AttributeName)) {
        Write-Warning "Attribute Name [$AttributeName] already found in schema."
    }
    else {
        $newAttribute = @{
            anchor = $false
            caseExact = $false
            #defaultValue = $null
            flowNullValues = $false
            multivalued = $false
            mutability      = "ReadWrite"
            name = "$namespace`:$AttributeName"
            required = $false
            type = "String"
            apiExpressions = @()
            metadata          = @()
            referencedObjects = @()
        }
        $SyncJobSchema.Directories[0].Objects[0].Attributes += $newAttribute
    }

}

# There is currently a bug in Update-MgServicePrincipalSynchronizationJobSchema that is preventing its use.
# See issue: https://github.com/microsoftgraph/msgraph-sdk-powershell/issues/1134
# Update-MgServicePrincipalSynchronizationJobSchema -ServicePrincipalId $servicePrincipalId -SynchronizationJobId $SyncJob.Id -Directories $SyncJobSchema.Directories
Invoke-MgGraphRequest -Method PUT -Uri "https://graph.microsoft.com/beta/servicePrincipals/$servicePrincipalId/synchronization/jobs/$($SyncJob.Id)/schema" -Body $SyncJobSchema.ToJsonString()




# #Getting the the custom Atts for the txt file 
# foreach ($att in $CustomSchema.split(','))
# {
#     $newAttribute=$null
#     $newAttribute=@"
#     {
#         "anchor": false,
#         "caseExact": false,
#         "defaultValue": null,
#         "flowNullValues": false,
#         "multivalued": false,
#         "mutability": "ReadWrite",
#         "name": "$namespace`:$att",
#         "required": false,
#         "type": "String",
#         "apiExpressions": [],
#         "metadata": [],
#         "referencedObjects": []
#     }
# "@ 

# $objectToAdd = ConvertFrom-Json -InputObject $newAttribute
# $CurrentSchema.directories[1].objects[0].attributes+=$objectToAdd

# }

# $SchemaAsJson=ConvertTo-Json -InputObject $CurrentSchema -Depth 20
# $urlput= $baseUrl + "/servicePrincipals/9e7bd53b-5056-4b45-805b-e1425042c097/synchronization/jobs/ecma.3272c93e8a98419bbfd32e22147c29e6.7a2286ea-37d2-443a-9dde-63fcdbc152a4/schema"

# try {
#    Invoke-RestMethod -Method Put -headers $header -Uri $urlput -Body ($SchemaAsJson) -ContentType "application/json" 
#    Write-Host "The Schema was successfully updated!!!" -ForegroundColor Green
# }
#  catch [System.Net.WebException] {   
#      $respStream = $_.Exception.Response.GetResponseStream()
#      $reader = New-Object System.IO.StreamReader($respStream)
#      $respBody = $reader.ReadToEnd() | ConvertFrom-Json
#     if ( [string]::IsNullOrEmpty($respbody.error.message ))
#     {
#         Write-Host $respbody.error.message -ForegroundColor Red

#     }
#     else
#     {
#         $respBody;
 
#     }
# }