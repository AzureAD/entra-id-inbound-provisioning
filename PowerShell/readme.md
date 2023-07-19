# CSV2SCIM bulk upload PowerShell script
Many enterprises rely on CSV extracts shared by their HR teams as the source for identities. The CSV2SCIM PowerShell script is a sample script to enable conversion of CSV files into a SCIM bulk request payload that can be directly consumed by the inbound provisioning [/bulkUpload](https://learn.microsoft.com/graph/api/synchronization-synchronizationjob-post-bulkupload) API endpoint. 

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

