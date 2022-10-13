
.'.\src\Push-CsvToAzureADProvisioning.ps1' `
    -Path '.\SampleData\csv-with-1000-records.csv' `
    -AttributeMapping @{
        externalId = 'WorkerID'
        name       = @{
            familyName = 'LastName'
            givenName  = 'FirstName'
        }
        active     = { $_.'WorkerStatus' -eq 'Active' } # This does not work today, need way to transform source data to core user schema.
        userName   = 'UserID'
    }


.'.\src\Push-CsvToAzureADProvisioning.ps1' `
    -Path '.\SampleData\csv-with-1000-records.csv' `
    -ServicePrincipalId '0056dd01-38be-424f-9016-0e8f1db8ba7f' `
    -UpdateSchema