@{
    externalId = 'WorkerID'
    name       = @{
        familyName = 'LastName'
        givenName  = 'FirstName'
    }
    active     = { $_.'WorkerStatus' -eq 'Active' }
    userName   = 'UserID'
}
