<#
.SYNOPSIS
    Generate and send user data to Microsoft Entra ID Provisioning /bulkUpload API endpoint.

.DESCRIPTION
    There are 5 execution modes:
        - ValidateAttributeMapping
        - GenerateScimPayload
        - SendScimRequest
        - UpdateScimSchema
        - GetPreviousCycleLogs

    The following module must be installed:
    Install-Module -Name Microsoft.Graph.Applications,Microsoft.Graph.Reports

.EXAMPLE
    PS > $AttributeMapping = Import-PowerShellDataFile '.\Samples\AttributeMapping.psd1'
    PS > CSV2SCIM.ps1 -Path '.\Samples\csv-with-1000-records.csv' -AttributeMapping $AttributeMapping -ValidateAttributeMapping

    Validate Attribute Mapping Against SCIM Schema.   

.EXAMPLE
    PS > CSV2SCIM.ps1 -Path '.\Samples\csv-with-1000-records.csv' -ScimSchemaNamespace 'urn:ietf:params:scim:schemas:extension:csv:1.0:User' -AttributeMapping @{ externalId = 'WorkerID'; userName = 'UserID'; active = { $_.'WorkerStatus' -eq 'Active' } }

    Generate a SCIM bulk request payload with all attributes from CSV file using schema extension "urn:ietf:params:scim:schemas:extension:csv:1.0:User" and attribute mappings for externalId, userName, and active.

.EXAMPLE
    PS > $AttributeMapping = Import-PowerShellDataFile '.\Samples\AttributeMapping.psd1'
    PS > CSV2SCIM.ps1 -Path '.\Samples\csv-with-1000-records.csv' -AttributeMapping $AttributeMapping

    Generate a SCIM bulk request payload from CSV file using AttributeMapping file.

.EXAMPLE
    PS > CSV2SCIM.ps1 -Path '.\Samples\csv-with-1000-records.csv' -AttributeMapping $AttributeMapping -TenantId 00000000-0000-0000-0000-000000000000 -ServicePrincipalId 00000000-0000-0000-0000-000000000000
    PS > $AttributeMapping = Import-PowerShellDataFile '.\Samples\AttributeMapping.psd1'

         Generate a SCIM bulk request payload from CSV file and send SCIM bulk request to Entra ID.
    
    
    
.EXAMPLE
    PS > $AttributeMapping = Import-PowerShellDataFile '.\Samples\AttributeMapping.psd1'
    PS > CSV2SCIM.ps1 -Path '.\Samples\csv-with-1000-records.csv' -AttributeMapping $AttributeMapping -TenantId 00000000-0000-0000-0000-000000000000 -ServicePrincipalId 00000000-0000-0000-0000-000000000000 -ClientId 00000000-0000-0000-0000-000000000000 -ClientCertificate (Get-ChildItem Cert:\CurrentUser\My\0000000000000000000000000000000000000000)

    Generate a SCIM bulk request payload from CSV file and send SCIM bulk request to Entra ID using service principal with certificate authentication.

.EXAMPLE
    PS > CSV2SCIM.ps1 -Path '.\Samples\csv-with-1000-records.csv' -ScimSchemaNamespace 'urn:ietf:params:scim:schemas:extension:csv:1.0:User' -TenantId 00000000-0000-0000-0000-000000000000 -ServicePrincipalId 00000000-0000-0000-0000-000000000000 -UpdateSchema

    Update schema on Entra ID provisioning application with schema extension 'urn:ietf:params:scim:schemas:extension:csv:1.0:User' based on CSV file.

.EXAMPLE
    PS > CSV2SCIM.ps1 -TenantId 00000000-0000-0000-0000-000000000000 -ServicePrincipalId 00000000-0000-0000-0000-000000000000 -GetPreviousCycleLogs

    Get provisioning statistics from provisioning logs for the latest cycle and show log details in the console.

.EXAMPLE
    PS > $ProvisioningLogsDetails = CSV2SCIM.ps1 -TenantId 00000000-0000-0000-0000-000000000000 -ServicePrincipalId 00000000-0000-0000-0000-000000000000 -GetPreviousCycleLogs -NumberOfCycles 2
 
    Get provisioning statistics from provisioning logs for the latest 2 cycles and save the log details to a variable for futher analysis.

.EXAMPLE
    PS > CSV2SCIM.ps1 -ServicePrincipalId 00000000-0000-0000-0000-000000000000 -TenantId 00000000-0000-0000-0000-000000000000 -Path ".\Samples\csv-with-2-records.csv" -RestartService -AttributeMapping $attributMapping
    
     Generate a SCIM bulk request payload from CSV file, send SCIM bulk request to Entra ID and restart the provisioning service
    

#>
[CmdletBinding(DefaultParameterSetName = 'GenerateScimPayload')]
param (
    # Path to CSV file
    [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'GenerateScimPayload')]
    [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'SendScimRequest')]
    [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'UpdateScimSchema')]
    [Parameter(Mandatory = $false, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ValidateAttributeMapping')]
    [string] $Path,
    [Parameter(Mandatory = $false,ParameterSetName = 'SendScimRequest')]
    [switch] $RestartService,
    # Map all input properties to specified custom SCIM namespace. For example: "urn:ietf:params:scim:schemas:extension:csv:1.0:User"
    [Parameter(Mandatory = $false, ParameterSetName = 'GenerateScimPayload')]
    [Parameter(Mandatory = $false, ParameterSetName = 'SendScimRequest')]
    [Parameter(Mandatory = $true, ParameterSetName = 'UpdateScimSchema')]
    [ValidatePattern('urn:.*')]
    [string] $ScimSchemaNamespace,
    # Map input properties to SCIM attributes
    [Parameter(Mandatory = $true, ParameterSetName = 'ValidateAttributeMapping')]
    [Parameter(Mandatory = $false, ParameterSetName = 'GenerateScimPayload')]
    [Parameter(Mandatory = $false, ParameterSetName = 'SendScimRequest')]
    [hashtable] $AttributeMapping,
    # Tenant Id containing the provisioning application
    [Parameter(Mandatory = $false, ParameterSetName = 'SendScimRequest')]
    [Parameter(Mandatory = $false, ParameterSetName = 'UpdateScimSchema')]
    [Parameter(Mandatory = $false, ParameterSetName = 'GetPreviousCycleLogs')]
    [string] $TenantId,
    # Service Principal Id for the provisioning application
    [Parameter(Mandatory = $true, ParameterSetName = 'SendScimRequest')]
    [Parameter(Mandatory = $true, ParameterSetName = 'UpdateScimSchema')]
    [Parameter(Mandatory = $true, ParameterSetName = 'GetPreviousCycleLogs')]
    [string] $ServicePrincipalId,
    # Id of client application used to authenticate to tenant and MS Graph
    [Parameter(Mandatory = $false, ParameterSetName = 'SendScimRequest')]
    [Parameter(Mandatory = $false, ParameterSetName = 'UpdateScimSchema')]
    [Parameter(Mandatory = $false, ParameterSetName = 'GetPreviousCycleLogs')]	
    [string] $ClientId,
    # Certificate used to authenticate as client application
    [Parameter(Mandatory = $false, ParameterSetName = 'SendScimRequest')]
    [Parameter(Mandatory = $false, ParameterSetName = 'UpdateScimSchema')]
    [Parameter(Mandatory = $false, ParameterSetName = 'GetPreviousCycleLogs')]	
    [System.Security.Cryptography.X509Certificates.X509Certificate2] $ClientCertificate,
    # Update provisioning application schema to include custom SCIM namespace for all input properties
    [Parameter(Mandatory = $true, ParameterSetName = 'UpdateScimSchema')]
    [switch] $UpdateSchema,
    # Validate Attribute Mapping structure matches standard SCIM namespaces
    [Parameter(Mandatory = $true, ParameterSetName = 'ValidateAttributeMapping')]
    [switch] $ValidateAttributeMapping,
    # Get provisioning logs and statistics for the previous cycle
    [Parameter(Mandatory = $true, ParameterSetName = 'GetPreviousCycleLogs')]
    [switch] $GetPreviousCycleLogs,
    # Number of previous cycles to return
    [Parameter(Mandatory = $false, ParameterSetName = 'GetPreviousCycleLogs')]
    [int] $NumberOfCycles = 1
)

#region Script Variables and Functions

### Cache SCIM Schema Representions for Validation
$script:ScimSchemas = @{
    "urn:ietf:params:scim:schemas:core:2.0:User"                 = '{"id":"urn:ietf:params:scim:schemas:core:2.0:User","name":"User","description":"User Account","attributes":[{"name":"userName","type":"string","multiValued":false,"description":"Unique identifier for the User, typically used by the user to directly authenticate to the service provider. Each User MUST include a non-empty userName value.  This identifier MUST be unique across the service provider''s entire set of Users. REQUIRED.","required":true,"caseExact":false,"mutability":"readWrite","returned":"default","uniqueness":"server"},{"name":"name","type":"complex","multiValued":false,"description":"The components of the user''s real name. Providers MAY return just the full name as a single string in the formatted sub-attribute, or they MAY return just the individual component attributes using the other sub-attributes, or they MAY return both.  If both variants are returned, they SHOULD be describing the same name, with the formatted name indicating how the component attributes should be combined.","required":false,"subAttributes":[{"name":"formatted","type":"string","multiValued":false,"description":"The full name, including all middle names, titles, and suffixes as appropriate, formatted for display (e.g., ''Ms. Barbara J Jensen, III'').","required":false,"caseExact":false,"mutability":"readWrite","returned":"default","uniqueness":"none"},{"name":"familyName","type":"string","multiValued":false,"description":"The family name of the User, or last name in most Western languages (e.g., ''Jensen'' given the full name ''Ms. Barbara J Jensen, III'').","required":false,"caseExact":false,"mutability":"readWrite","returned":"default","uniqueness":"none"},{"name":"givenName","type":"string","multiValued":false,"description":"The given name of the User, or first name in most Western languages (e.g., ''Barbara'' given the full name ''Ms. Barbara J Jensen, III'').","required":false,"caseExact":false,"mutability":"readWrite","returned":"default","uniqueness":"none"},{"name":"middleName","type":"string","multiValued":false,"description":"The middle name(s) of the User (e.g., ''Jane'' given the full name ''Ms. Barbara J Jensen, III'').","required":false,"caseExact":false,"mutability":"readWrite","returned":"default","uniqueness":"none"},{"name":"honorificPrefix","type":"string","multiValued":false,"description":"The honorific prefix(es) of the User, or title in most Western languages (e.g., ''Ms.'' given the full name ''Ms. Barbara J Jensen, III'').","required":false,"caseExact":false,"mutability":"readWrite","returned":"default","uniqueness":"none"},{"name":"honorificSuffix","type":"string","multiValued":false,"description":"The honorific suffix(es) of the User, or suffix in most Western languages (e.g., ''III'' given the full name ''Ms. Barbara J Jensen, III'').","required":false,"caseExact":false,"mutability":"readWrite","returned":"default","uniqueness":"none"}],"mutability":"readWrite","returned":"default","uniqueness":"none"},{"name":"displayName","type":"string","multiValued":false,"description":"The name of the User, suitable for display to end-users.  The name SHOULD be the full name of the User being described, if known.","required":false,"caseExact":false,"mutability":"readWrite","returned":"default","uniqueness":"none"},{"name":"nickName","type":"string","multiValued":false,"description":"The casual way to address the user in real life, e.g., ''Bob'' or ''Bobby'' instead of ''Robert''.  This attribute SHOULD NOT be used to represent a User''s username (e.g., ''bjensen'' or ''mpepperidge'').","required":false,"caseExact":false,"mutability":"readWrite","returned":"default","uniqueness":"none"},{"name":"profileUrl","type":"reference","referenceTypes":["external"],"multiValued":false,"description":"A fully qualified URL pointing to a page representing the User''s online profile.","required":false,"caseExact":false,"mutability":"readWrite","returned":"default","uniqueness":"none"},{"name":"title","type":"string","multiValued":false,"description":"The user''s title, such as \"Vice President.\"","required":false,"caseExact":false,"mutability":"readWrite","returned":"default","uniqueness":"none"},{"name":"userType","type":"string","multiValued":false,"description":"Used to identify the relationship between the organization and the user.  Typical values used might be ''Contractor'', ''Employee'', ''Intern'', ''Temp'', ''External'', and ''Unknown'', but any value may be used.","required":false,"caseExact":false,"mutability":"readWrite","returned":"default","uniqueness":"none"},{"name":"preferredLanguage","type":"string","multiValued":false,"description":"Indicates the User''s preferred written or spoken language.  Generally used for selecting a localized user interface; e.g., ''en_US'' specifies the language English and country US.","required":false,"caseExact":false,"mutability":"readWrite","returned":"default","uniqueness":"none"},{"name":"locale","type":"string","multiValued":false,"description":"Used to indicate the User''s default location for purposes of localizing items such as currency, date time format, or numerical representations.","required":false,"caseExact":false,"mutability":"readWrite","returned":"default","uniqueness":"none"},{"name":"timezone","type":"string","multiValued":false,"description":"The User''s time zone in the ''Olson'' time zone database format, e.g., ''America/Los_Angeles''.","required":false,"caseExact":false,"mutability":"readWrite","returned":"default","uniqueness":"none"},{"name":"active","type":"boolean","multiValued":false,"description":"A Boolean value indicating the User''s administrative status.","required":false,"mutability":"readWrite","returned":"default"},{"name":"password","type":"string","multiValued":false,"description":"The User''s cleartext password.  This attribute is intended to be used as a means to specify an initial password when creating a new User or to reset an existing User''s password.","required":false,"caseExact":false,"mutability":"writeOnly","returned":"never","uniqueness":"none"},{"name":"emails","type":"complex","multiValued":true,"description":"Email addresses for the user.  The value SHOULD be canonicalized by the service provider, e.g., ''bjensen@example.com'' instead of ''bjensen@EXAMPLE.COM''. Canonical type values of ''work'', ''home'', and ''other''.","required":false,"subAttributes":[{"name":"value","type":"string","multiValued":false,"description":"Email addresses for the user.  The value SHOULD be canonicalized by the service provider, e.g., ''bjensen@example.com'' instead of ''bjensen@EXAMPLE.COM''. Canonical type values of ''work'', ''home'', and ''other''.","required":false,"caseExact":false,"mutability":"readWrite","returned":"default","uniqueness":"none"},{"name":"display","type":"string","multiValued":false,"description":"A human-readable name, primarily used for display purposes.  READ-ONLY.","required":false,"caseExact":false,"mutability":"readWrite","returned":"default","uniqueness":"none"},{"name":"type","type":"string","multiValued":false,"description":"A label indicating the attribute''s function, e.g., ''work'' or ''home''.","required":false,"caseExact":false,"canonicalValues":["work","home","other"],"mutability":"readWrite","returned":"default","uniqueness":"none"},{"name":"primary","type":"boolean","multiValued":false,"description":"A Boolean value indicating the ''primary'' or preferred attribute value for this attribute, e.g., the preferred mailing address or primary email address.  The primary attribute value ''true'' MUST appear no more than once.","required":false,"mutability":"readWrite","returned":"default"}],"mutability":"readWrite","returned":"default","uniqueness":"none"},{"name":"phoneNumbers","type":"complex","multiValued":true,"description":"Phone numbers for the User.  The value SHOULD be canonicalized by the service provider according to the format specified in RFC 3966, e.g., ''tel:+1-201-555-0123''. Canonical type values of ''work'', ''home'', ''mobile'', ''fax'', ''pager'', and ''other''.","required":false,"subAttributes":[{"name":"value","type":"string","multiValued":false,"description":"Phone number of the User.","required":false,"caseExact":false,"mutability":"readWrite","returned":"default","uniqueness":"none"},{"name":"display","type":"string","multiValued":false,"description":"A human-readable name, primarily used for display purposes.  READ-ONLY.","required":false,"caseExact":false,"mutability":"readWrite","returned":"default","uniqueness":"none"},{"name":"type","type":"string","multiValued":false,"description":"A label indicating the attribute''s function, e.g., ''work'', ''home'', ''mobile''.","required":false,"caseExact":false,"canonicalValues":["work","home","mobile","fax","pager","other"],"mutability":"readWrite","returned":"default","uniqueness":"none"},{"name":"primary","type":"boolean","multiValued":false,"description":"A Boolean value indicating the ''primary'' or preferred attribute value for this attribute, e.g., the preferred phone number or primary phone number.  The primary attribute value ''true'' MUST appear no more than once.","required":false,"mutability":"readWrite","returned":"default"}],"mutability":"readWrite","returned":"default"},{"name":"ims","type":"complex","multiValued":true,"description":"Instant messaging addresses for the User.","required":false,"subAttributes":[{"name":"value","type":"string","multiValued":false,"description":"Instant messaging address for the User.","required":false,"caseExact":false,"mutability":"readWrite","returned":"default","uniqueness":"none"},{"name":"display","type":"string","multiValued":false,"description":"A human-readable name, primarily used for display purposes.  READ-ONLY.","required":false,"caseExact":false,"mutability":"readWrite","returned":"default","uniqueness":"none"},{"name":"type","type":"string","multiValued":false,"description":"A label indicating the attribute''s function, e.g., ''aim'', ''gtalk'', ''xmpp''.","required":false,"caseExact":false,"canonicalValues":["aim","gtalk","icq","xmpp","msn","skype","qq","yahoo"],"mutability":"readWrite","returned":"default","uniqueness":"none"},{"name":"primary","type":"boolean","multiValued":false,"description":"A Boolean value indicating the ''primary'' or preferred attribute value for this attribute, e.g., the preferred messenger or primary messenger.  The primary attribute value ''true'' MUST appear no more than once.","required":false,"mutability":"readWrite","returned":"default"}],"mutability":"readWrite","returned":"default"},{"name":"photos","type":"complex","multiValued":true,"description":"URLs of photos of the User.","required":false,"subAttributes":[{"name":"value","type":"reference","referenceTypes":["external"],"multiValued":false,"description":"URL of a photo of the User.","required":false,"caseExact":false,"mutability":"readWrite","returned":"default","uniqueness":"none"},{"name":"display","type":"string","multiValued":false,"description":"A human-readable name, primarily used for display purposes.  READ-ONLY.","required":false,"caseExact":false,"mutability":"readWrite","returned":"default","uniqueness":"none"},{"name":"type","type":"string","multiValued":false,"description":"A label indicating the attribute''s function, i.e., ''photo'' or ''thumbnail''.","required":false,"caseExact":false,"canonicalValues":["photo","thumbnail"],"mutability":"readWrite","returned":"default","uniqueness":"none"},{"name":"primary","type":"boolean","multiValued":false,"description":"A Boolean value indicating the ''primary'' or preferred attribute value for this attribute, e.g., the preferred photo or thumbnail.  The primary attribute value ''true'' MUST appear no more than once.","required":false,"mutability":"readWrite","returned":"default"}],"mutability":"readWrite","returned":"default"},{"name":"addresses","type":"complex","multiValued":true,"description":"A physical mailing address for this User. Canonical type values of ''work'', ''home'', and ''other''.  This attribute is a complex type with the following sub-attributes.","required":false,"subAttributes":[{"name":"formatted","type":"string","multiValued":false,"description":"The full mailing address, formatted for display or use with a mailing label.  This attribute MAY contain newlines.","required":false,"caseExact":false,"mutability":"readWrite","returned":"default","uniqueness":"none"},{"name":"streetAddress","type":"string","multiValued":false,"description":"The full street address component, which may include house number, street name, P.O. box, and multi-line extended street address information.  This attribute MAY contain newlines.","required":false,"caseExact":false,"mutability":"readWrite","returned":"default","uniqueness":"none"},{"name":"locality","type":"string","multiValued":false,"description":"The city or locality component.","required":false,"caseExact":false,"mutability":"readWrite","returned":"default","uniqueness":"none"},{"name":"region","type":"string","multiValued":false,"description":"The state or region component.","required":false,"caseExact":false,"mutability":"readWrite","returned":"default","uniqueness":"none"},{"name":"postalCode","type":"string","multiValued":false,"description":"The zip code or postal code component.","required":false,"caseExact":false,"mutability":"readWrite","returned":"default","uniqueness":"none"},{"name":"country","type":"string","multiValued":false,"description":"The country name component.","required":false,"caseExact":false,"mutability":"readWrite","returned":"default","uniqueness":"none"},{"name":"type","type":"string","multiValued":false,"description":"A label indicating the attribute''s function, e.g., ''work'' or ''home''.","required":false,"caseExact":false,"canonicalValues":["work","home","other"],"mutability":"readWrite","returned":"default","uniqueness":"none"}],"mutability":"readWrite","returned":"default","uniqueness":"none"},{"name":"groups","type":"complex","multiValued":true,"description":"A list of groups to which the user belongs, either through direct membership, through nested groups, or dynamically calculated.","required":false,"subAttributes":[{"name":"value","type":"string","multiValued":false,"description":"The identifier of the User''s group.","required":false,"caseExact":false,"mutability":"readOnly","returned":"default","uniqueness":"none"},{"name":"$ref","type":"reference","referenceTypes":["User","Group"],"multiValued":false,"description":"The URI of the corresponding ''Group'' resource to which the user belongs.","required":false,"caseExact":false,"mutability":"readOnly","returned":"default","uniqueness":"none"},{"name":"display","type":"string","multiValued":false,"description":"A human-readable name, primarily used for display purposes.  READ-ONLY.","required":false,"caseExact":false,"mutability":"readOnly","returned":"default","uniqueness":"none"},{"name":"type","type":"string","multiValued":false,"description":"A label indicating the attribute''s function, e.g., ''direct'' or ''indirect''.","required":false,"caseExact":false,"canonicalValues":["direct","indirect"],"mutability":"readOnly","returned":"default","uniqueness":"none"}],"mutability":"readOnly","returned":"default"},{"name":"entitlements","type":"complex","multiValued":true,"description":"A list of entitlements for the User that represent a thing the User has.","required":false,"subAttributes":[{"name":"value","type":"string","multiValued":false,"description":"The value of an entitlement.","required":false,"caseExact":false,"mutability":"readWrite","returned":"default","uniqueness":"none"},{"name":"display","type":"string","multiValued":false,"description":"A human-readable name, primarily used for display purposes.  READ-ONLY.","required":false,"caseExact":false,"mutability":"readWrite","returned":"default","uniqueness":"none"},{"name":"type","type":"string","multiValued":false,"description":"A label indicating the attribute''s function.","required":false,"caseExact":false,"mutability":"readWrite","returned":"default","uniqueness":"none"},{"name":"primary","type":"boolean","multiValued":false,"description":"A Boolean value indicating the ''primary'' or preferred attribute value for this attribute.  The primary attribute value ''true'' MUST appear no more than once.","required":false,"mutability":"readWrite","returned":"default"}],"mutability":"readWrite","returned":"default"},{"name":"roles","type":"complex","multiValued":true,"description":"A list of roles for the User that collectively represent who the User is, e.g., ''Student'', ''Faculty''.","required":false,"subAttributes":[{"name":"value","type":"string","multiValued":false,"description":"The value of a role.","required":false,"caseExact":false,"mutability":"readWrite","returned":"default","uniqueness":"none"},{"name":"display","type":"string","multiValued":false,"description":"A human-readable name, primarily used for display purposes.  READ-ONLY.","required":false,"caseExact":false,"mutability":"readWrite","returned":"default","uniqueness":"none"},{"name":"type","type":"string","multiValued":false,"description":"A label indicating the attribute''s function.","required":false,"caseExact":false,"canonicalValues":[],"mutability":"readWrite","returned":"default","uniqueness":"none"},{"name":"primary","type":"boolean","multiValued":false,"description":"A Boolean value indicating the ''primary'' or preferred attribute value for this attribute.  The primary attribute value ''true'' MUST appear no more than once.","required":false,"mutability":"readWrite","returned":"default"}],"mutability":"readWrite","returned":"default"},{"name":"x509Certificates","type":"complex","multiValued":true,"description":"A list of certificates issued to the User.","required":false,"caseExact":false,"subAttributes":[{"name":"value","type":"binary","multiValued":false,"description":"The value of an X.509 certificate.","required":false,"caseExact":false,"mutability":"readWrite","returned":"default","uniqueness":"none"},{"name":"display","type":"string","multiValued":false,"description":"A human-readable name, primarily used for display purposes.  READ-ONLY.","required":false,"caseExact":false,"mutability":"readWrite","returned":"default","uniqueness":"none"},{"name":"type","type":"string","multiValued":false,"description":"A label indicating the attribute''s function.","required":false,"caseExact":false,"canonicalValues":[],"mutability":"readWrite","returned":"default","uniqueness":"none"},{"name":"primary","type":"boolean","multiValued":false,"description":"A Boolean value indicating the ''primary'' or preferred attribute value for this attribute.  The primary attribute value ''true'' MUST appear no more than once.","required":false,"mutability":"readWrite","returned":"default"}],"mutability":"readWrite","returned":"default"}],"meta":{"resourceType":"Schema","location":"/v2/Schemas/urn:ietf:params:scim:schemas:core:2.0:User"}}' | ConvertFrom-Json
    "urn:ietf:params:scim:schemas:extension:enterprise:2.0:User" = '{"id":"urn:ietf:params:scim:schemas:extension:enterprise:2.0:User","name":"EnterpriseUser","description":"Enterprise User","attributes":[{"name":"employeeNumber","type":"string","multiValued":false,"description":"Numeric or alphanumeric identifier assigned to a person, typically based on order of hire or association with anorganization.","required":false,"caseExact":false,"mutability":"readWrite","returned":"default","uniqueness":"none"},{"name":"costCenter","type":"string","multiValued":false,"description":"Identifies the name of a cost center.","required":false,"caseExact":false,"mutability":"readWrite","returned":"default","uniqueness":"none"},{"name":"organization","type":"string","multiValued":false,"description":"Identifies the name of an organization.","required":false,"caseExact":false,"mutability":"readWrite","returned":"default","uniqueness":"none"},{"name":"division","type":"string","multiValued":false,"description":"Identifies the name of a division.","required":false,"caseExact":false,"mutability":"readWrite","returned":"default","uniqueness":"none"},{"name":"department","type":"string","multiValued":false,"description":"Identifies the name of a department.","required":false,"caseExact":false,"mutability":"readWrite","returned":"default","uniqueness":"none"},{"name":"manager","type":"complex","multiValued":false,"description":"The User''s manager. A complex type that optionally allows service providers to represent organizational hierarchy by referencing the ''id'' attribute of another User.","required":false,"subAttributes":[{"name":"value","type":"string","multiValued":false,"description":"The id of the SCIM resource representingthe User''s manager.  REQUIRED.","required":false,"caseExact":false,"mutability":"readWrite","returned":"default","uniqueness":"none"},{"name":"$ref","type":"reference","referenceTypes":["User"],"multiValued":false,"description":"The URI of the SCIM resource representing the User''s manager.  REQUIRED.","required":false,"caseExact":false,"mutability":"readWrite","returned":"default","uniqueness":"none"},{"name":"displayName","type":"string","multiValued":false,"description":"The displayName of the User''s manager. OPTIONAL and READ-ONLY.","required":false,"caseExact":false,"mutability":"readOnly","returned":"default","uniqueness":"none"}],"mutability":"readWrite","returned":"default"}],"meta":{"resourceType":"Schema","location":"/v2/Schemas/urn:ietf:params:scim:schemas:extension:enterprise:2.0:User"}}' | ConvertFrom-Json
}

<#
.SYNOPSIS
    Validate Attribute Mapping Against SCIM Schema
#>
function Test-ScimAttributeMapping {
    [CmdletBinding()]
    param (
        # Map input properties to SCIM attributes
        [Parameter(Mandatory = $true)]
        [hashtable] $AttributeMapping,
        # SCIM schema namespace for attribute mapping
        [Parameter(Mandatory = $true)]
        [string] $ScimSchemaNamespace,
        # List of attribute names through sub-attribute names
        [Parameter(Mandatory = $false)]
        [string[]] $HierarchyPath
    )

    ## Initialize
    $result = $true

    foreach ($_PropertyMapping in $AttributeMapping.GetEnumerator()) {

        if ($_PropertyMapping.Key -in 'id', 'externalId') { continue }

        [string[]] $NewHierarchyPath = $HierarchyPath + $_PropertyMapping.Key

        if ($_PropertyMapping.Key -is [string]) {
            if ($_PropertyMapping.Key.StartsWith('urn:')) {
                if ($ScimSchemas.ContainsKey($_PropertyMapping.Key)) {
                    $nestedResult = Test-ScimAttributeMapping $_PropertyMapping.Value $_PropertyMapping.Key
                    $result = $result -and $nestedResult
                }
                else {
                    Write-Warning ('SCIM Schema Namespace [{0}] was not be validated because no schema representation has been defined.' -f $_PropertyMapping.Key)
                }
            }
            elseif ($ScimSchemas.ContainsKey($ScimSchemaNamespace)) {
                $ScimSchemaAttribute = $ScimSchemas[$ScimSchemaNamespace].attributes | Where-Object name -EQ $NewHierarchyPath[0]
                for ($i = 1; $i -lt $NewHierarchyPath.Count; $i++) {
                    $ScimSchemaAttribute = $ScimSchemaAttribute.subAttributes | Where-Object name -EQ $NewHierarchyPath[$i]
                }
                if (!$ScimSchemaAttribute) {
                    Write-Error ('Attribute [{0}] does not exist in SCIM Schema Namespace [{1}].' -f ($NewHierarchyPath -join '.'), $ScimSchemaNamespace)
                    $result = $false
                }
                else {
                    if ($ScimSchemaAttribute.multiValued -and $_PropertyMapping.Value -isnot [array]) {
                        Write-Error ('Attribute [{0}] is multivalued in SCIM Schema Namespace [{1}] and must contain an array.' -f ($NewHierarchyPath -join '.'), $ScimSchemaNamespace)
                        $result = $false
                    }
                    foreach ($_PropertyMappingValue in $_PropertyMapping.Value) {
                        if ($ScimSchemaAttribute.type -eq 'Complex' -and $_PropertyMappingValue -is [string]) {
                            Write-Error ('Attribute [{0}] of Type [{2}] in SCIM Schema Namespace [{1}] cannot have simple mapping.' -f ($NewHierarchyPath -join '.'), $ScimSchemaNamespace, $ScimSchemaAttribute.type)
                            $result = $false
                        }
                        elseif ($ScimSchemaAttribute.type -ne 'Complex' -and ($_PropertyMappingValue -is [hashtable] -or $_PropertyMappingValue -is [System.Collections.Specialized.OrderedDictionary])) {
                            Write-Error ('Attribute [{0}] of Type [{2}] in SCIM Schema Namespace [{1}] cannot have complex mapping.' -f ($NewHierarchyPath -join '.'), $ScimSchemaNamespace, $ScimSchemaAttribute.type)
                            $result = $false
                        }
                        elseif ($_PropertyMappingValue -is [hashtable] -or $_PropertyMappingValue -is [System.Collections.Specialized.OrderedDictionary]) {
                            $nestedResult = Test-ScimAttributeMapping $_PropertyMappingValue $ScimSchemaNamespace $NewHierarchyPath
                            $result = $result -and $nestedResult
                        }
                    }
                }
            }
        }
        else {
            Write-Error ('Attribute Mapping Key [{0}] is invalid.' -f $_PropertyMapping.Key)
            $result = $false
        }
    }

    return $result
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
        # Map all input properties to specified custom SCIM namespace
        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [Alias('Namespace')]
        [string] $ScimSchemaNamespace,
        # Map input properties to SCIM attributes
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

            $ScimOperationObject = [PSCustomObject][ordered]@{
                "method" = "POST"
                "bulkId" = [string](New-Guid)
                "path"   = "/Users"
                "data"   = ConvertTo-ScimPayload $obj -ScimSchemaNamespace $ScimSchemaNamespace -PassThru @paramConvertToScimPayload
            }
            $ScimBulkObjectInstance.Operations.Add($ScimOperationObject)

            # Output object when max operations has been reached
            if ($OperationsPerRequest -gt 0 -and $ScimBulkObjectInstance.Operations.Count -ge $OperationsPerRequest) {
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
        # Map all input properties to specified custom SCIM namespace
        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [Alias('Namespace')]
        [string] $ScimSchemaNamespace,
        # Map input properties to SCIM attributes
        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [hashtable] $AttributeMapping = @{
            "externalId" = "externalId"
            "userName"   = "userName"
            "active"     = "active"
        },
        # PassThru Object
        [Parameter(Mandatory = $false)]
        [switch] $PassThru
    )

    begin {
        function Resolve-ScimAttributeMapping {
            param (
                # Resource Data
                [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
                [object] $InputObject,
                # Map input properties to SCIM attributes
                [Parameter(Mandatory = $true)]
                [hashtable] $AttributeMapping,
                # Add to existing hashtable or dictionary
                [Parameter(Mandatory = $false)]
                [object] $TargetObject = @{}
            )

            foreach ($_AttributeMapping in $AttributeMapping.GetEnumerator()) {

                if ($_AttributeMapping.Key -is [string] -and $_AttributeMapping.Key.StartsWith('urn:')) {
                    if (!$TargetObject['schemas'].Contains($_AttributeMapping.Key)) { $TargetObject['schemas'] += $_AttributeMapping.Key }
                }

                if ($_AttributeMapping.Value -is [array]) {
                    ## Force array output
                    $TargetObject[$_AttributeMapping.Key] = @(Resolve-PropertyMappingValue $InputObject $_AttributeMapping.Value)
                }
                else {
                    $TargetObject[$_AttributeMapping.Key] = Resolve-PropertyMappingValue $InputObject $_AttributeMapping.Value
                }
            }

            return $TargetObject
        }

        function Resolve-PropertyMappingValue {
            param (
                # Resource Data
                [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
                [object] $InputObject,
                # Property mapping value to output
                [Parameter(Mandatory = $true)]
                [object] $PropertyMappingValue
            )

            foreach ($_PropertyMappingValue in $PropertyMappingValue) {
                if ($_PropertyMappingValue -is [scriptblock]) {
                    Invoke-Transformation $InputObject $_PropertyMappingValue
                }
                elseif ($_PropertyMappingValue -is [hashtable] -or $_PropertyMappingValue -is [System.Collections.Specialized.OrderedDictionary]) {
                    Resolve-ScimAttributeMapping $InputObject $_PropertyMappingValue
                }
                else {
                    $InputObject.($_PropertyMappingValue)
                }
            }
        }

        # function Invoke-PropertyMapping {
        #     param (
        #         # Resource Data
        #         [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        #         [object] $InputObject,
        #         # Map input properties to another
        #         [Parameter(Mandatory = $true)]
        #         [object] $PropertyMapping
        #     )

        #     foreach ($_PropertyMapping in $PropertyMapping) {
        #         if ($_PropertyMapping -is [scriptblock]) {
        #             Invoke-Transformation $InputObject $_PropertyMapping
        #         }
        #         elseif ($_PropertyMapping -is [hashtable] -or $_PropertyMapping -is [System.Collections.Specialized.OrderedDictionary]) {
        #             $TargetObject = @{}
        #             foreach ($_PropertyMapping2 in $_PropertyMapping.GetEnumerator()) {
        #                 $TargetObject[$_PropertyMapping2.Key] = Invoke-PropertyMapping2 $InputObject $_PropertyMapping2.Value
        #             }
        #             Write-Output $TargetObject
        #         }
        #         else {
        #             $InputObject.($_PropertyMapping)
        #         }
        #     }
        # }

        function Invoke-Transformation {
            param (
                # Resource Data
                [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
                [object] $InputObject,
                # Transformation Script Block
                [Parameter(Mandatory = $true)]
                [scriptblock] $ScriptBlock
            )
    
            process {
                ## Using Import-PowerShellDataFile to load a scriptblock wraps it in another scriptblock so handling that with loop
                $ScriptBlockResult = $ScriptBlock
                while ($ScriptBlockResult -is [scriptblock]) {
                    $ScriptBlockResult = ForEach-Object -InputObject $InputObject -Process $ScriptBlockResult
                }

                return $ScriptBlockResult
            }
        }
    }

    process {
        foreach ($obj in $InputObject) {
            ## Generate Core SCIM Data Structure
            $ScimObject = [ordered]@{
                schemas = [string[]]("urn:ietf:params:scim:schemas:core:2.0:User", "urn:ietf:params:scim:schemas:extension:enterprise:2.0:User")
                #id = [string](New-Guid)
            }

            ## Add Attributes to SCIM Data Structure
            $ScimObject = Resolve-ScimAttributeMapping $obj -AttributeMapping $AttributeMapping -TargetObject $ScimObject
            if ($ScimSchemaNamespace) {
                $ScimObject[$ScimSchemaNamespace] = $obj
                $ScimObject['schemas'] += $ScimSchemaNamespace
            }

            ## Return Object with SCIM Data Structure
            #$ScimObject = [PSCustomObject]$ScimObject
            if ($PassThru) { $ScimObject }
            else { ConvertTo-Json $ScimObject -Depth 5 }
        }
    }
}

<#
.SYNOPSIS
    Send SCIM Bulk Payloads to Entra ID
#>
function Invoke-AzureADBulkScimRequest {
    [CmdletBinding()]
    param (
        # SCIM JSON Payload(s)
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string[]] $Body,
        # Service Principal Id for the provisioning application
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [string] $ServicePrincipalId
    )

    begin {
        ## Import Mg Modules
        Import-Module Microsoft.Graph.Applications -ErrorAction Stop

        ## Connect to MgGraph Module
        #Connect-MgGraph -Scopes 'Directory.ReadWrite.All' -ErrorAction Stop
    #    $previousProfile = Get-MgProfile
     #   if ($previousProfile.Name -ne 'beta') {
      #      Select-MgProfile -Name 'beta'
       # }

        ## Lookup Service Principal
        $ServicePrincipalId = Get-MgServicePrincipal -Filter "id eq '$ServicePrincipalId' or appId eq '$ServicePrincipalId'" -Select id | Select-Object -ExpandProperty id
        #$ServicePrincipal = Get-MgServicePrincipal -ServicePrincipalId $ServicePrincipalId -ErrorAction Stop
        $SyncJob = Get-MgServicePrincipalSynchronizationJob -ServicePrincipalId $ServicePrincipalId -ErrorAction Stop
        if ($RestartService)
        {
            Suspend-MgServicePrincipalSynchronizationJob -ServicePrincipalId $ServicePrincipalId -SynchronizationJobId $SyncJob.Id
        }
    }
    
    process {
        foreach ($_body in $Body) {
            Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/beta/servicePrincipals/$ServicePrincipalId/synchronization/jobs/$($SyncJob.Id)/bulkUpload" -ContentType 'application/scim+json' -Body $_body
        }
    }

    end {
        if ($RestartService)
        {
            Start-MgServicePrincipalSynchronizationJob -ServicePrincipalId $ServicePrincipalId -SynchronizationJobId $SyncJob.Id
        }
   #     if ($previousProfile.Name -ne (Get-MgProfile).Name) {
    #        Select-MgProfile -Name $previousProfile.Name
     #   }
    }
}


<#
.SYNOPSIS
    Update schema of Entra ID Provisioning app
#>
function Set-AzureADProvisioningAppSchema {
    [CmdletBinding()]
    param (
        # Resource Data
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [object[]] $InputObject,
        # Map all input properties to specified custom SCIM namespace
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [Alias('Namespace')]
        [string] $ScimSchemaNamespace,
        # Service Principal Id for the provisioning application
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [string] $ServicePrincipalId
    )

    begin {
        [bool] $UpdateComplete = $false

        ## Import Mg Modules
        Import-Module Microsoft.Graph.Applications -ErrorAction Stop

        ## Connect to MgGraph Module
        #Connect-MgGraph -Scopes 'Directory.ReadWrite.All' -ErrorAction Stop
     #   $previousProfile = Get-MgProfile
      #  if ($previousProfile.Name -ne 'beta') {
       #     Select-MgProfile -Name 'beta'
        #}

        ## Lookup Service Principal
        $ServicePrincipalId = Get-MgServicePrincipal -Filter "id eq '$ServicePrincipalId' or appId eq '$ServicePrincipalId'" -Select id | Select-Object -ExpandProperty id
        #$ServicePrincipal = Get-MgServicePrincipal -ServicePrincipalId $ServicePrincipalId -ErrorAction Stop
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
     #   if ($previousProfile.Name -ne (Get-MgProfile).Name) {
      #      Select-MgProfile -Name $previousProfile.Name
       # }
    }
}

<#
.SYNOPSIS
    Get Provisioning CycleId History
#>
function Get-ProvisioningCycleIdHistory {
    [CmdletBinding()]
    param (
        # Service Principal Id of the provisioning application
        [Parameter(Mandatory = $true)]
        [string] $ServicePrincipalId,
        # Number of CycleIds to return
        [Parameter(Mandatory = $true)]
        [int] $NumberOfCycles
    )

    begin {
     #   $previousProfile = Get-MgProfile
      #  if ($previousProfile.Name -ne 'beta') {
       #     Select-MgProfile -Name 'beta'
        #}

        $ServicePrincipalId = Get-MgServicePrincipal -Filter "id eq '$ServicePrincipalId' or appId eq '$ServicePrincipalId'" -Select id | Select-Object -ExpandProperty id
        $SyncJob = Get-MgServicePrincipalSynchronizationJob -ServicePrincipalId $ServicePrincipalId -ErrorAction Stop
        [string[]] $cylceIDs = @()
    }

    process {
        $qryStatement = "jobid eq '$($SyncJob.Id)'"
        for ($i = 0; $i -lt $NumberOfCycles; $i++) {
            if ($cylceIDs.Count -gt 0) {
                $qryStatement += " and cycleId ne '$($cylceIDs[-1])'"
            }
            $CycleLogEntry = Get-MgAuditLogProvisioning -Filter $qryStatement -Top 1
            if ($null -ne $CycleLogEntry -and $null -ne $CycleLogEntry.CycleId) {
                $CycleLogEntry.CycleId
                $cylceIDs += $CycleLogEntry.CycleId
            }
            else { break }
        }
    }

    end {
     #   if ($previousProfile.Name -ne (Get-MgProfile).Name) {
      #      Select-MgProfile -Name $previousProfile.Name
       # }
    }
}

<#
.SYNOPSIS
    Get Provisioning Logs by CycleId
#>
function Get-ProvisioningCycleLogs {
    [CmdletBinding()]
    param (
        # Provisioning CycleId
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string[]] $CycleId,
        # Summarize Logs by ChangeId
        [Parameter(Mandatory = $false)]
        [switch] $SummarizeByChangeId,
        # Show provisioning statistics for each cycle
        [Parameter(Mandatory = $false)]
        [switch] $ShowCycleStatistics
    )

    process {
        foreach ($_cycleId in $CycleId) {

            if ($SummarizeByChangeId) {
                ## Output Logs Summarized by ChangeId
                $CycleLogs = Get-MgAuditLogProvisioning -Filter "cycleId eq '$_cycleId'" -All
                $CycleLogsByChangeId = $CycleLogs | Group-Object -Property ChangeId

                foreach ($log in $CycleLogsByChangeId) {
                    [PSCustomObject][ordered]@{
                        "ChangeId"         = $log.Group[0].ChangeId
                        "SourceId"         = $log.Group[0].SourceIdentity.Id
                        "TargetId"         = $log.Group[0].TargetIdentity.Id
                        "DisplayName"      = $log.Group[0].TargetIdentity.DisplayName
                        "Action"           = $log.Group.ProvisioningAction
                        "Status"           = $log.Group.ProvisioningStatusInfo.Status
                        "ActivityDateTime" = $log.Group[0].ActivityDateTime
                        "CycleId"          = $log.Group[0].CycleId
                        "ProvisioningLogs" = $log.Group
                    }
                }
            }
            else {
                ## Output Logs Directly
                Get-MgAuditLogProvisioning -Filter "cycleId eq '$_cycleId'" -All -OutVariable CycleLogs
                $CycleLogsByChangeId = $CycleLogs | Group-Object -Property ChangeId -NoElement
            }

            if ($ShowCycleStatistics) {
                Get-ProvisioningLogStatistics $CycleLogs -WriteToConsole | Out-Null
            }
        }
    }
}

<#
.SYNOPSIS
    Get Statistics for Set of Provisioning Logs
#>
function Get-ProvisioningLogStatistics {
    [CmdletBinding()]
    param (
        # Provisioning Logs
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [object[]] $ProvisioningLogs,
        # Summarize Logs by CycleId
        [Parameter(Mandatory = $false)]
        [switch] $SummarizeByCycleId,
        # Write Summary to Host Console in addition to Standard Output
        [Parameter(Mandatory = $false)]
        [switch] $WriteToConsole
    )

    begin {
        function New-CycleSummary ($CycleId) {
            return [pscustomobject][ordered]@{
                CycleId          = $CycleId
                StartDateTime    = $null
                EndDateTime      = $null
                Changes          = 0
                Users            = 0
                ActionStatistics = @(
                    New-ActionStatusStatistics 'Create'
                    New-ActionStatusStatistics 'Update'
                    New-ActionStatusStatistics 'Delete'
                    New-ActionStatusStatistics 'Disable'
                    New-ActionStatusStatistics 'StagedDelete'
                    New-ActionStatusStatistics 'Other'
                )
            }
        }

        function New-ActionStatusStatistics ($Action) {
            return [PSCustomObject][ordered]@{
                Action  = $Action
                Success = 0
                Failure = 0
                Skipped = 0
                Warning = 0
            }
        }

        $CycleSummary = New-CycleSummary
        $CycleSummary.CycleId = New-Object 'System.Collections.Generic.List[string]'
        $CycleTracker = @{
            ChangeIds = New-Object 'System.Collections.Generic.HashSet[string]'
            UserIds   = New-Object 'System.Collections.Generic.HashSet[string]'
        }

        $CycleSummaries = [ordered]@{}
        $CycleTrackers = @{}
    }

    process {
        foreach ($ProvisioningLog in $ProvisioningLogs) {
            if ($SummarizeByCycleId) {
                if (!$CycleSummaries.Contains($ProvisioningLog.CycleId)) {
                    ## New CycleSummary object for new CycleId
                    $CycleSummaries[$ProvisioningLog.CycleId] = $CycleSummary = New-CycleSummary $ProvisioningLog.CycleId
                    $CycleTrackers[$ProvisioningLog.CycleId] = $CycleTracker = @{
                        ChangeIds = New-Object 'System.Collections.Generic.HashSet[string]'
                        UserIds   = New-Object 'System.Collections.Generic.HashSet[string]'
                    }
                }
                else {
                    $CycleSummary = $CycleSummaries[$ProvisioningLog.CycleId]
                    $CycleTracker = $CycleTrackers[$ProvisioningLog.CycleId]
                }
            }
            else {
                ## Add CycleId to a single summary object
                if (!$CycleSummary.CycleId.Contains($ProvisioningLog.CycleId)) { $CycleSummary.CycleId.Add($ProvisioningLog.CycleId) }
            }

            ## Update log date range
            if ($null -eq $CycleSummary.StartDateTime -or $ProvisioningLog.ActivityDateTime -lt $CycleSummary.StartDateTime) {
                $CycleSummary.StartDateTime = $ProvisioningLog.ActivityDateTime
            }
            if ($null -eq $CycleSummary.EndDateTime -or $ProvisioningLog.ActivityDateTime -gt $CycleSummary.EndDateTime) {
                $CycleSummary.EndDateTime = $ProvisioningLog.ActivityDateTime
            }

            ## Update summary object with statistics
            if ($CycleTracker.ChangeIds.Add($ProvisioningLog.ChangeId)) { $CycleSummary.Changes++ }
            if ($CycleTracker.UserIds.Add($ProvisioningLog.SourceIdentity.Id)) { $CycleSummary.Users++ }

            $CycleSummary.ActionStatistics | Where-Object Action -EQ $ProvisioningLog.ProvisioningAction | ForEach-Object { $_.($ProvisioningLog.ProvisioningStatusInfo.Status)++ }
        }
    }

    end {
        if ($SummarizeByCycleID) {
            [array] $CycleSummaries = $CycleSummaries.Values
        }
        else {
            [array] $CycleSummaries = $CycleSummary
        }

        foreach ($CycleSummary in $CycleSummaries) {
            Write-Output $CycleSummary

            if ($WriteToConsole) {
                Write-Host ('')
                Write-Host ("CycleId: {0}" -f ($CycleSummary.CycleId -join ', '))
                Write-Host ("Timespan: {0} - {1} ({2})" -f $CycleSummary.StartDateTime, $CycleSummary.EndDateTime, ($CycleSummary.EndDateTime - $CycleSummary.StartDateTime))
                Write-Host ("Total Changes: {0}" -f $CycleSummary.Changes)
                Write-Host ("Total Users: {0}" -f $CycleSummary.Users)
                Write-Host ('')

                $TableRowPattern = '{0,-12} {1,7} {2,7} {3,7} {4,7} {5,7}'
                Write-Host ($TableRowPattern -f 'Action', 'Success', 'Failure', 'Skipped', 'Warning', 'Total')
                Write-Host ($TableRowPattern -f '------', '-------', '-------', '-------', '-------', '-----')
                foreach ($row in $CycleSummary.ActionStatistics) {
                    Write-Host ($TableRowPattern -f $row.Action, $row.Success, $row.Failure, $row.Skipped, $row.Warning, ($row.Success + $row.Failure + $row.Skipped + $row.Warning))
                }
                Write-Host ('')
            }
        }
    }
}

#endregion


## Define Connect Parameters
$paramConnectMgGraph = @{}
if ($TenantId) { $paramConnectMgGraph['TenantId'] = $TenantId }
if ($ClientCertificate) {
    $paramConnectMgGraph['ClientId'] = $ClientId
    $paramConnectMgGraph['Certificate'] = $ClientCertificate
}
elseif ($ClientId) {
    $paramConnectMgGraph['ClientId'] = $ClientId
    $paramConnectMgGraph['Scopes'] = 'Application.ReadWrite.All', 'AuditLog.Read.All','SynchronizationData-User.Upload' 
}
else {
    $paramConnectMgGraph['Scopes'] = 'Application.ReadWrite.All', 'AuditLog.Read.All','SynchronizationData-User.Upload'
}

switch ($PSCmdlet.ParameterSetName) {
    'ValidateAttributeMapping' {
        Test-ScimAttributeMapping $AttributeMapping -ScimSchemaNamespace 'urn:ietf:params:scim:schemas:core:2.0:User'
    }
    'GenerateScimPayload' {
        if (Test-ScimAttributeMapping $AttributeMapping -ScimSchemaNamespace 'urn:ietf:params:scim:schemas:core:2.0:User') {
            Import-Csv -Path $Path | ConvertTo-ScimBulkPayload -ScimSchemaNamespace $ScimSchemaNamespace -AttributeMapping $AttributeMapping
        }
    }
    'SendScimRequest' {
        if (Test-ScimAttributeMapping $AttributeMapping -ScimSchemaNamespace 'urn:ietf:params:scim:schemas:core:2.0:User') {
            Import-Module Microsoft.Graph.Applications -ErrorAction Stop
            Connect-MgGraph @paramConnectMgGraph -ErrorAction Stop | Out-Null

            Import-Csv -Path $Path | ConvertTo-ScimBulkPayload -ScimSchemaNamespace $ScimSchemaNamespace -AttributeMapping $AttributeMapping | Invoke-AzureADBulkScimRequest -ServicePrincipalId $ServicePrincipalId -ErrorAction Stop
        }
    }
    'UpdateScimSchema' {
        Import-Module Microsoft.Graph.Applications -ErrorAction Stop
        Connect-MgGraph @paramConnectMgGraph -ErrorAction Stop | Out-Null

        Get-Content -Path $Path -First 1 | Set-AzureADProvisioningAppSchema -ScimSchemaNamespace $ScimSchemaNamespace -ServicePrincipalId $ServicePrincipalId
    }
    'GetPreviousCycleLogs' {
        Import-Module Microsoft.Graph.Applications,Microsoft.Graph.Reports -MaximumVersion 1.99.0 -ErrorAction Stop
        Connect-MgGraph @paramConnectMgGraph -ErrorAction Stop | Out-Null
       
        Get-ProvisioningCycleIdHistory $ServicePrincipalId -NumberOfCycles $NumberOfCycles | Get-ProvisioningCycleLogs -SummarizeByChangeId -ShowCycleStatistics
    }
}
