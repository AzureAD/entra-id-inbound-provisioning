
### Load Attribute Mapping Definitions for each Data Source
$EmployeeAttributeMapping = Import-PowerShellDataFile '.\Samples\Sample1\AttributeMapping.Employee.psd1'
$ContractorAttributeMapping = Import-PowerShellDataFile '.\Samples\Sample1\AttributeMapping.Contractor.psd1'
$InternAttributeMapping = Import-PowerShellDataFile '.\Samples\Sample1\AttributeMapping.Intern.psd1'


### Test SCIM Bulk Payload Generation
## Generate SCIM Bulk Payloads for Employee Data Using Employee Attribute Mapping Definition
.\src\CSV2SCIM.ps1 -Path '.\Samples\Sample1\employeeData.csv' -AttributeMapping $EmployeeAttributeMapping

## Generate SCIM Bulk Payloads for Contractor Data Using Contractor Attribute Mapping Definition
.\src\CSV2SCIM.ps1 -Path '.\Samples\Sample1\contractorData.csv' -AttributeMapping $ContractorAttributeMapping

## Generate SCIM Bulk Payloads for Intern Data Using Intern Attribute Mapping Definition
.\src\CSV2SCIM.ps1 -Path '.\Samples\Sample1\internData.csv' -AttributeMapping $InternAttributeMapping


### Send Requests to Azure AD
## Generate SCIM Bulk Payloads for Employee Data Using Employee Attribute Mapping Definition and Send Requests to Azure AD
.\src\CSV2SCIM.ps1 -Path '.\Samples\Sample1\employeeData.csv' -AttributeMapping $EmployeeAttributeMapping `
    -TenantId 'contoso.onmicrosoft.com' -ServicePrincipalId '00000000-0000-0000-0000-000000000000'

## Generate SCIM Bulk Payloads for Contractor Data Using Contractor Attribute Mapping Definition and Send Requests to Azure AD
.\src\CSV2SCIM.ps1 -Path '.\Samples\Sample1\contractorData.csv' -AttributeMapping $ContractorAttributeMapping `
    -TenantId 'contoso.onmicrosoft.com' -ServicePrincipalId '00000000-0000-0000-0000-000000000000'

## Generate SCIM Bulk Payloads for Intern Data Using Intern Attribute Mapping Definition and Send Requests to Azure AD
.\src\CSV2SCIM.ps1 -Path '.\Samples\Sample1\internData.csv' -AttributeMapping $InternAttributeMapping `
    -TenantId 'contoso.onmicrosoft.com' -ServicePrincipalId '00000000-0000-0000-0000-000000000000'
