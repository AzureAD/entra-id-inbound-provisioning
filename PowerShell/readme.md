# CSV2SCIM bulk upload PowerShell script
Many enterprises rely on CSV extracts shared by their HR teams as the source for identities. The CSV2SCIM PowerShell script is a sample asset provided by Microsoft to enable the conversion of CSV files into a SCIM bulk request payload that can be directly consumed by the Inbound Provisioning API endpoint. 

## Usage

```powershell
CSV2SCIM.ps1 -Path <path-to-csv-file> 
[-ScimSchemaNamespace <customSCIMSchemaNamespace>] 
[-AttributeMapping $AttributeMapping] 
[-ServicePrincipalId <spn-guid>] 
[-ValidateAttributeMapping]
[-UpdateSchema]
[-ClientId <client-id>]
[-ClientCertificate <certificate-object>]
```

