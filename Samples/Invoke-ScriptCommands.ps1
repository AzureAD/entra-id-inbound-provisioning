# ## Test Update Schema
# .'.\src\CSV2SCIM.ps1' `
#     -Path '.\Samples\csv-with-1000-records.csv' `
#     -TenantId 'saziatestaad.onmicrosoft.com' `
#     -ServicePrincipalId '995aed29-05e3-4f1a-883e-f17b023d5c81' `
#     #-ClientId 'e57a5d25-7fd7-4988-b185-f575eea5d1a9' -ClientCertificate (Get-ChildItem 'Cert:\CurrentUser\My\A5C63F1E5C07F6C20A3BA85513D0B82EF53E1925') `
#     -UpdateSchema
# exit

# ## Validate Attribute Mapping
# $AttributeMapping = Import-PowerShellDataFile '.\Samples\AttributeMapping.psd1'
# .'.\src\CSV2SCIM.ps1' `
#     -Path '.\Samples\csv-with-1000-records.csv' `
#     -AttributeMapping $AttributeMapping `
#     -ValidateAttributeMapping
# exit

# ## Test Generation
# $AttributeMapping = Import-PowerShellDataFile '.\Samples\AttributeMapping.psd1'
# $data = .'.\src\CSV2SCIM.ps1' `
#     -Path '.\Samples\csv-with-1000-records.csv' `
#     -AttributeMapping $AttributeMapping
# $data
# exit

# ## Test Generation and Send Request to Azure AD
# $AttributeMapping = Import-PowerShellDataFile '.\Samples\AttributeMapping.psd1'
# .'.\src\CSV2SCIM.ps1' `
#     -Path '.\Samples\csv-with-1000-records.csv' `
#     -TenantId 'saziatestaad.onmicrosoft.com' `
#     -ServicePrincipalId '30242ce7-13d1-4d46-9cf1-a4fe5dcee2da' `
#     -AttributeMapping $AttributeMapping `
#     -Verbose
# exit

# ## Test Generation and Send Request to Azure AD using Certificate
# $AttributeMapping = Import-PowerShellDataFile '.\Samples\AttributeMapping.psd1'
# .'.\src\CSV2SCIM.ps1' `
#     -Path '.\Samples\csv-with-2-records.csv' `
#     -AttributeMapping $AttributeMapping `
#     -TenantId 'saziatestaad.onmicrosoft.com' -ServicePrincipalId '30242ce7-13d1-4d46-9cf1-a4fe5dcee2da' `
#     -ClientId '3762674d-470e-41db-9115-9f2914ccded4' -ClientCertificate (Get-ChildItem Cert:\CurrentUser\My\0C02922A88A933EA400354E7AB1DB1BABCAC340F) `
#     -Verbose
# exit


## Test Minimums
.'.\src\CSV2SCIM.ps1' `
    -Path '.\Samples\csv-with-2-records.csv' `
    -TenantId 'saziatestaad.onmicrosoft.com' `
    -ServicePrincipalId '30242ce7-13d1-4d46-9cf1-a4fe5dcee2da' `
    -AttributeMapping @{ externalId = 'WorkerID'; userName = 'UserID' } `
    -Verbose
exit
