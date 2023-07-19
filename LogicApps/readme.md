[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FAzureAD%2Fentra-id-inbound-provisioning%2Fmain%2FLogicApps%2Fcsv2scimbulkupload-template.json)

# CSV2SCIMBulkUpload
Simple Azure Logic Apps workflow that converts a CSV file containing user records to a SCIM bulk upload request that can be sent to the Entra ID provisioning service [/bulkUpload](https://learn.microsoft.com/graph/api/synchronization-synchronizationjob-post-bulkupload) API endpoint.

## Credits
The workflow reuses the awesome [CSVtoJSONcore](https://github.com/joelbyford/CSVtoJSONcore/) Azure function. 

