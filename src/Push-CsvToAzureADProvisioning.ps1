<#
.SYNOPSIS
    Generate and send user data to Azure AD Provisioning.
.EXAMPLE
    PS > Push-CsvToAzureADProvisioning.ps1 -Path '.\SampleData\csv-with-1000-records.csv'

    Generate a SCIM bulk request payload from CSV file.

.EXAMPLE
    PS > Push-CsvToAzureADProvisioning.ps1 -Path '.\SampleData\csv-with-1000-records.csv' -ServicePrincipalId 00000000-0000-0000-0000-000000000000

    Generate a SCIM bulk request payload from CSV file and send SCIM bulk request to Azure AD.
    
.EXAMPLE
    PS > Push-CsvToAzureADProvisioning.ps1 -Path '.\SampleData\csv-with-1000-records.csv' -ServicePrincipalId 00000000-0000-0000-0000-000000000000 -UpdateSchema

    Update schema on Azure AD provisioning application based on CSV file.
#>
[CmdletBinding(DefaultParameterSetName = 'GenerateScimPayload')]
param (
    # 
    [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
    [string] $Path,
    # 
    [Parameter(Mandatory = $false)]
    [string] $ScimSchemaNamespace = "urn:ietf:params:scim:schemas:extension:csv:1.0:User",
    # 
    [Parameter(Mandatory = $false, ParameterSetName = 'GenerateScimPayload')]
    [Parameter(Mandatory = $false, ParameterSetName = 'SendScimRequest')]
    [hashtable] $AttributeMapping,
    # 
    [Parameter(Mandatory = $true, ParameterSetName = 'SendScimRequest')]
    [Parameter(Mandatory = $true, ParameterSetName = 'UpdateScimSchema')]
    [string] $TenantId,
    # 
    [Parameter(Mandatory = $true, ParameterSetName = 'SendScimRequest')]
    [Parameter(Mandatory = $true, ParameterSetName = 'UpdateScimSchema')]
    [string] $ServicePrincipalId,
    # 
    [Parameter(Mandatory = $false)]
    [string] $ClientId,
    #
    [Parameter(Mandatory = $false)]
    [System.Security.Cryptography.X509Certificates.X509Certificate2] $ClientCertificate,
    # 
    [Parameter(Mandatory = $true, ParameterSetName = 'UpdateScimSchema')]
    [switch] $UpdateSchema
)

#region Helper Functions

<#
.SYNOPSIS
    Connect Script
#>   
function Connect-ScriptAuth {
    [CmdletBinding(DefaultParameterSetName = 'PublicClient')]
    param (
        # 
        [Parameter(Mandatory = $false, ParameterSetName = 'PublicClient', Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [Parameter(Mandatory = $true, ParameterSetName = 'ConfidentialClient', Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string] $ClientId,
        # 
        [Parameter(Mandatory = $true, ParameterSetName = 'ConfidentialClient', ValueFromPipelineByPropertyName = $true)]
        [System.Security.Cryptography.X509Certificates.X509Certificate2] $ClientCertificate,
        # 
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [string] $TenantId
    )

    ## Import Mg Modules
    Import-Module Microsoft.Graph.Authentication -ErrorAction Stop

    ## Connect to MgGraph Module
    if ($ClientCertificate) {
        Connect-MgGraph -TenantId $TenantId -ClientId $ClientId -Certificate $ClientCertificate -ErrorAction Stop
    }
    elseif ($ClientId) {
        Connect-MgGraph -Scopes 'Directory.ReadWrite.All' -TenantId $TenantId -ClientId $ClientId -ErrorAction Stop
    }
    else {
        Connect-MgGraph -Scopes 'Directory.ReadWrite.All' -TenantId $TenantId -ErrorAction Stop
    }
}

<#
.SYNOPSIS
    Convert Object(s) to SCIM Bulk Payload Format
#>   
function ConvertTo-ScimBulkPayload {
    [CmdletBinding()]
    param (
        # Resource Data
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [object[]] $InputObject,
        # 
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [Alias('Namespace')]
        [string] $ScimSchemaNamespace,
        # Map input object properties to SCIM core user schema
        [Parameter(Mandatory = $false)]
        [hashtable] $AttributeMapping,
        # Operations per bulk request
        [Parameter(Mandatory = $false)]
        [int] $OperationsPerRequest = 50,
        # PassThru Object
        [Parameter(Mandatory = $false)]
        [switch] $PassThru
    )

    begin {
        $ScimBulkObject = [PSCustomObject][ordered]@{
            "schemas"      = @("urn:ietf:params:scim:api:messages:2.0:BulkRequest")
            "Operations"   = New-Object System.Collections.Generic.List[pscustomobject]
            "failOnErrors" = $null
        }
        $paramConvertToScimPayload = @{}
        if ($AttributeMapping) { $paramConvertToScimPayload['AttributeMapping'] = $AttributeMapping }
        $ScimBulkObjectInstance = $ScimBulkObject.psobject.Copy()
    }

    process {
        foreach ($obj in $InputObject) {

            #ToDo: Request batching: If the CSV file has more than 50 lines, create multiple SCIM bulk requests with batch size of 50 records in each request. Start new bulk object when max OperationsPerRequest is reached.
            $ScimOperationObject = [PSCustomObject][ordered]@{
                "method" = "POST"
                "bulkId" = [string](New-Guid)
                "path"   = "/Users"
                "data"   = ConvertTo-ScimPayload $obj -ScimSchemaNamespace $ScimSchemaNamespace -PassThru @paramConvertToScimPayload
            }
            $ScimBulkObjectInstance.Operations.Add($ScimOperationObject)

            # Output object when max operations has been reached
            if ($ScimBulkObjectInstance.Operations.Count -ge $OperationsPerRequest) {
                if ($PassThru) { $ScimBulkObjectInstance }
                else { ConvertTo-Json $ScimBulkObjectInstance -Depth 10 }
                $ScimBulkObjectInstance = $ScimBulkObject.psobject.Copy()
                $ScimBulkObjectInstance.Operations = New-Object System.Collections.Generic.List[pscustomobject]
            }
        }
    }

    end {
        if ($ScimBulkObjectInstance.Operations.Count -gt 0) {
            ## Return Object with SCIM Data Structure
            if ($PassThru) { $ScimBulkObjectInstance }
            else { ConvertTo-Json $ScimBulkObjectInstance -Depth 10 }
        }
    }
}

<#
.SYNOPSIS
    Convert Object(s) to SCIM Payload Format
#>
function ConvertTo-ScimPayload {
    [CmdletBinding()]
    param (
        # Resource Data
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [object[]] $InputObject,
        # 
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [Alias('Namespace')]
        [string] $ScimSchemaNamespace,
        # 
        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [hashtable] $AttributeMapping = @{
            "externalId" = "externalId"
            "name"       = @{
                "familyName" = "familyName"
                "givenName"  = "givenName"
            }
            "active"     = "active"
            "userName"   = "userName"
        },
        # PassThru Object
        [Parameter(Mandatory = $false)]
        [switch] $PassThru
    )

    process {
        foreach ($obj in $InputObject) {
            $ScimObject = [PSCustomObject][ordered]@{
                schemas                                               = @(
                    "urn:ietf:params:scim:schemas:core:2.0:User"
                    "urn:ietf:params:scim:schemas:extension:enterprise:2.0:User"
                    $ScimSchemaNamespace
                )
                id                                                    = [string](New-Guid)
                externalId                                            = $obj.($AttributeMapping["externalId"])
                name                                                  = @{
                    familyName = $obj.($AttributeMapping["name"]["familyName"])
                    givenName  = $obj.($AttributeMapping["name"]["givenName"])
                }
                active                                                = $obj.($AttributeMapping["active"])
                userName                                              = $obj.($AttributeMapping["userName"])
                "$ScimSchemaNamespace" = $obj
            }

            ## ToDo: Dynamically add additional core attributes to output object based on AttributeMapping.
            # Write warning when AttributeMapping variable contains attribute not part of core schema. https://www.rfc-editor.org/rfc/rfc7643.html#section-3.1
            # Need way to handle nested attribute components such as name with components of familyName and givenName.
            # Support transformations such as active -eq "Inactive" to $false bool.

            ## Return Object with SCIM Data Structure
            if ($PassThru) { $ScimObject }
            else { ConvertTo-Json $ScimObject -Depth 5 }
        }
    }
}

<#
.SYNOPSIS
    Send SCIM Bulk Payloads to Azure AD
#>
function Invoke-AzureADBulkScimRequest {
    [CmdletBinding()]
    param (
        # Json
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string[]] $Body,
        # 
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [string] $ServicePrincipalId
    )

    begin {
        ## Import Mg Modules
        Import-Module Microsoft.Graph.Applications -ErrorAction Stop

        ## Connect to MgGraph Module
        #Connect-MgGraph -Scopes 'Directory.ReadWrite.All' -ErrorAction Stop
        $previousProfile = Get-MgProfile
        if ($previousProfile.Name -ne 'beta') {
            Select-MgProfile -Name 'beta'
        }

        ## Lookup Service Principal
        $SyncJob = Get-MgServicePrincipalSynchronizationJob -ServicePrincipalId $ServicePrincipalId
    }
    
    process {
        foreach ($_body in $Body) {
            #Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/beta/servicePrincipals/$ServicePrincipalId/synchronization/jobs/$($SyncJob.Id)/bulkUpload" -ContentType 'application/scim+json' -Body $_body
            ## Use backend hostname until published behind graph.
            Invoke-RestMethod -Method POST -Uri "https://na.h1.upload.syncfabric.windowsazure.com/servicePrincipals/$ServicePrincipalId/synchronization/jobs/$($SyncJob.Id)/bulkUpload" -Headers @{ Authorization = $MsalToken.CreateAuthorizationHeader() } -ContentType 'application/scim+json' -Body $_body -SkipCertificateCheck | Out-Null
        }
    }

    end {
        if ($previousProfile.Name -ne (Get-MgProfile).Name) {
            Select-MgProfile -Name $previousProfile.Name
        }
    }
}


<#
.SYNOPSIS
    Update schema of Azure AD Provisioning app
#>
function Set-AzureADProvisioningAppSchema {
    [CmdletBinding()]
    param (
        # Resource Data
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [object[]] $InputObject,
        # 
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [Alias('Namespace')]
        [string] $ScimSchemaNamespace,
        #
        [Parameter(Mandatory = $true)]
        [string] $TenantId,
        # 
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [string] $ServicePrincipalId
    )

    begin {
        [bool] $UpdateComplete = $false

        ## Import Mg Modules
        Import-Module Microsoft.Graph.Applications -ErrorAction Stop

        ## Connect to MgGraph Module
        #Connect-MgGraph -Scopes 'Directory.ReadWrite.All' -TenantId $TenantId -ErrorAction Stop
        $previousProfile = Get-MgProfile
        if ($previousProfile.Name -ne 'beta') {
            Select-MgProfile -Name 'beta'
        }

        ## Lookup Service Principal
        $SyncJob = Get-MgServicePrincipalSynchronizationJob -ServicePrincipalId $ServicePrincipalId
        # Get the current Schema of the application
        $SyncJobSchema = Get-MgServicePrincipalSynchronizationJobSchema -ServicePrincipalId $servicePrincipalId -SynchronizationJobId $SyncJob.Id
    }
    
    process {
        if ($UpdateComplete) { return }

        [string[]] $AttributeNames = $null
        if ($InputObject[0] -is [string]) {
            $AttributeNames = $InputObject[0].Trim(',').Split(',').Trim()
        }
        elseif ($InputObject[0] -is [hashtable] -or $InputObject[0] -is [System.Collections.Specialized.OrderedDictionary] -or $InputObject[0].GetType().FullName.StartsWith('System.Collections.Generic.Dictionary')) {
            $AttributeNames = $InputObject[0].Keys
        }
        else {
            $AttributeNames = $InputObject[0].psobject.Properties.Name
        }

        ## Add custom schema attributes
        foreach ($AttributeName in $AttributeNames) {
            ## ToDo: Auto-select the correct directory that is not AD or AAD. Look at id, name or Version.
            if ($SyncJobSchema.Directories[0].Objects[0].Attributes.Name.Contains("$ScimSchemaNamespace`:$AttributeName")) {
                Write-Warning "Skipping Attribute Name [$ScimSchemaNamespace`:$AttributeName] already found in schema."
            }
            else {
                $newAttribute = @{
                    anchor            = $false
                    caseExact         = $false
                    #defaultValue = $null
                    flowNullValues    = $false
                    multivalued       = $false
                    mutability        = "ReadWrite"
                    name              = "$ScimSchemaNamespace`:$AttributeName"
                    required          = $false
                    type              = "String"
                    apiExpressions    = @()
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

        $UpdateComplete = $true
    }

    end {
        if ($previousProfile.Name -ne (Get-MgProfile).Name) {
            Select-MgProfile -Name $previousProfile.Name
        }
    }
}

#endregion

## Define Connect Parameters
$paramConnectMgGraph = @{
    TenantId = $TenantId
}
if ($ClientCertificate) {
    $paramConnectMgGraph['ClientId'] = $ClientId
    $paramConnectMgGraph['Certificate'] = $ClientCertificate
}
elseif ($ClientId) {
    $paramConnectMgGraph['ClientId'] = $ClientId
    $paramConnectMgGraph['Scope'] = 'Directory.ReadWrite.All'
}
else {
    $paramConnectMgGraph['Scope'] = 'Directory.ReadWrite.All'
}

## MSAL.PS only needed until published to graph.
Import-Module MSAL.PS -ErrorAction Stop

switch ($PSCmdlet.ParameterSetName) {
    'GenerateScimPayload' {
        Import-Csv -Path $Path | ConvertTo-ScimBulkPayload -ScimSchemaNamespace $ScimSchemaNamespace -AttributeMapping $AttributeMapping
    }
    'SendScimRequest' {
        Connect-MgGraph @paramConnectMgGraph -ErrorAction Stop
        ## MSAL.PS only needed until published to graph.
        $MsalToken = Get-MsalToken -ClientId '14d82eec-204b-4c2f-b7e8-296a70dab67e' -TenantId $TenantId -Scopes 'Directory.ReadWrite.All' -LoginHint (Get-MgContext).Account
        Import-Csv -Path $Path | ConvertTo-ScimBulkPayload -ScimSchemaNamespace $ScimSchemaNamespace -AttributeMapping $AttributeMapping | Invoke-AzureADBulkScimRequest -ServicePrincipalId $ServicePrincipalId
    }
    'UpdateScimSchema' {
        Connect-MgGraph @paramConnectMgGraph -ErrorAction Stop
        Get-Content -Path $Path -First 1 | Set-AzureADProvisioningAppSchema -ScimSchemaNamespace $ScimSchemaNamespace -TenantId $TenantId -ServicePrincipalId $ServicePrincipalId
    }
}

## ToDo: Update synopsis, examples, and parameter descriptions
## ToDo: Add example with AttributeMappings from .psd1 file

## ToDo: Check status and resend data for failed records: After timed delay of 40 minutes, query Provisioning Logs API endpoint for failed records and resend data.

## ToDo: New mode to create scheduled task with correct parameters for easy setup on Windows Server.

## ToDo: Accept AttributeMappings from .psd1 file on Scim generation commands?
