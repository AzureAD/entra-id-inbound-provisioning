# Microsoft Entra API-driven inbound provisioning

This project hosts resources and samples to help you get started with [Microsoft Entra API-driven inbound provisioning](https://learn.microsoft.com/azure/active-directory/app-provisioning/inbound-provisioning-api-concepts). With API-driven inbound provisioning, Microsoft Entra provisioning service now supports integration with any system of record. Customers and partners can use any automation tool of their choice to retrieve workforce data from the system of record and ingest it into Microsoft Entra ID and connected on-premises Active Directory domains.

## Content hierarchy

The project directories are organized by the integration platform / tool that you'd like to use for implementing your API client.

* [**LogicApps** directory](./LogicApps): Do you prefer using Azure LogicApps for your inbound provisioning integration? This sub-directory hosts a sample Logic Apps workflow (CSV2SCIMBulkUpload) to help you get started!
* [**Postman** directory](./Postman): Looking for a Postman collection to evaluate the inbound provisioning API? Your search ends here. This sub-directory has Postman request collection and environment files to help you get started!
* [**PowerShell** directory](./PowerShell): Are you a PowerShell scripting fan? This sub-directory has a sample CSV2SCIM PowerShell script that can read any CSV file and convert the contents to a SCIM bulk request payload that you can send to the inbound provisioning API endpoint.

## Contributing

This project welcomes contributions and suggestions.  Most contributions require you to agree to a
Contributor License Agreement (CLA) declaring that you have the right to, and actually do, grant us
the rights to use your contribution. For details, visit https://cla.opensource.microsoft.com.

When you submit a pull request, a CLA bot will automatically determine whether you need to provide
a CLA and decorate the PR appropriately (e.g., status check, comment). Simply follow the instructions
provided by the bot. You will only need to do this once across all repos using our CLA.

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).
For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or
contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.

## Trademarks

This project may contain trademarks or logos for projects, products, or services. Authorized use of Microsoft 
trademarks or logos is subject to and must follow 
[Microsoft's Trademark & Brand Guidelines](https://www.microsoft.com/en-us/legal/intellectualproperty/trademarks/usage/general).
Use of Microsoft trademarks or logos in modified versions of this project must not cause confusion or imply Microsoft sponsorship.
Any use of third-party trademarks or logos are subject to those third-party's policies.
