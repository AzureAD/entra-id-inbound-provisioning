
<#
.SYNOPSIS
    Convert Object(s) to SCIM Bulk Payload Format
.EXAMPLE
    PS C:\>

#>
function ConvertTo-ScimBulkPayload {
    [CmdletBinding()]
    param (
        # Resource Data
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [object[]] $InputObject,
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
    }

    process {
        foreach ($obj in $InputObject) {
            #ToDo: Request batching: If the CSV file has more than 50 lines, create multiple SCIM bulk requests with batch size of 50 records in each request. Start new bulk object when max OperationsPerRequest is reached.
            $ScimOperationObject = [PSCustomObject][ordered]@{
                "method" = "POST"
                "bulkId" = [string](New-Guid)
                "path"   = "/users"
                "data"   = ConvertTo-ScimPayload $obj -PassThru @paramConvertToScimPayload
            }
            $ScimBulkObject.Operations.Add($ScimOperationObject)
        }
    }

    end {
        ## Return Object with SCIM Data Structure
        if ($PassThru) { $ScimBulkObject }
        else { ConvertTo-Json $ScimBulkObject -Depth 10 }
    }
}

<#
.SYNOPSIS
    Convert Object(s) to SCIM Payload Format
.EXAMPLE
    PS C:\>

#>
function ConvertTo-ScimPayload {
    [CmdletBinding()]
    param (
        # Resource Data
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [object[]] $InputObject,
        # 
        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [hashtable] $AttributeMapping = @{
            "externalId"      = "externalId"
            "name" = @{
                "familyName" = "familyName"
                "givenName"  = "givenName"
            }
            "active"          = "active"
            "userName"        = "userName"
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
                    "urn:ietf:params:scim:schemas:extension:csv:1.0:User"
                )
                id                                                    = [string](New-Guid)
                externalId                                            = $obj.($AttributeMapping["externalId"])
                name                                                  = @{
                    familyName = $obj.($AttributeMapping["name"]["familyName"])
                    givenName  = $obj.($AttributeMapping["name"]["givenName"])
                }
                active                                                = $obj.($AttributeMapping["active"])
                userName                                              = $obj.($AttributeMapping["userName"])
                "urn:ietf:params:scim:schemas:extension:csv:1.0:User" = $obj
            }

            ## ToDo: Dynamically add additional core attributes to output object based on AttributeMapping.
            # Write warning when AttributeMapping variable contains attribute not part of core schema. https://www.rfc-editor.org/rfc/rfc7643.html#section-3.1
            # Need way to handle nested attribute components such as name with components of familyName and givenName.

            ## Return Object with SCIM Data Structure
            if ($PassThru) { $ScimObject }
            else { ConvertTo-Json $ScimObject -Depth 5 }
        }
    }
}

## ToDo: Add function for updating schema on Azure AD app based on sample input.


## Sample usage
Import-Csv ".\sampledata\csv-with-1000-records.csv" | Select-Object -First 2 | ConvertTo-ScimBulkPayload -AttributeMapping @{
    externalId = 'WorkerID'
    name = @{
        familyName = 'LastName'
        givenName  = 'FirstName'
    }
    active     = { $_.'WorkerStatus' -eq 'Active' } # This does not work today, need way to transform source data to core user schema.
    userName   = 'UserID'
}

## ToDo: Post requests directly to the API endpoint: Accept Provisioning Job ID/API endpoint as input, authenticate using Graph API and send the SCIM payloads directly to the API endpoint. This logic should be added to a new function that allows pipeline input.
#Invoke-RestMethod -Method Post '/bulk' -ContentType 'application/scim+json' -Body $ScimBulkPayload

## ToDo: Check status and resend data for failed records: After timed delay of 40 minutes, query Provisioning Logs API endpoint for failed records and resend data.
