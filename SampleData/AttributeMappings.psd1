@{
    externalId = 'WorkerID'
    name       = @{
        familyName = 'LastName'
        givenName  = 'FirstName'
    }
    active     = { $_.'WorkerStatus' -eq 'Active' } # This does not work today, need way to transform source data to core user schema.
    userName   = 'UserID'
}
