
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

            ## Return Object with SCIM Data Structure
            if ($PassThru) { $ScimObject }
            else { ConvertTo-Json $ScimObject -Depth 5 }
        }
    }
}

Import-Csv ".\sampledata\worker.csv" | ConvertTo-ScimBulkPayload -AttributeMapping @{
    externalId = 'WorkerID'
    name = @{
        familyName = 'LastName'
        givenName  = 'FirstName'
    }
    active     = { $_.'WorkerStatus' -eq 'Active' }
    userName   = 'UserID'
}

#Invoke-RestMethod -Method Post '/bulk' -ContentType 'application/scim+json' -Body $ScimBulkPayload
