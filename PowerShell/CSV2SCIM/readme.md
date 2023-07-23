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
[-RestartService]
```

## How to use the PowerShell script

Refer to the instructions [Quickstart API-driven inbound provisioning with PowerShell](https://aka.ms/Entra/InboundProvWithPowerShell).

## How to file issues and get help  

This sample asset uses GitHub Issues to track bugs and feature requests. Please search the existing 
issues before filing new issues to avoid duplicates.  For new issues, file your bug or 
feature request as a new Issue.

For help and questions about Entra ID API-driven inbound provisioning, refer to the [documentation](https://aka.ms/Entra/ProvisionFromAnySource)

