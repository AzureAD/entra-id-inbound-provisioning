@{
    externalId= 'WorkerID'
    name       = @{
        familyName = 'LastName'
        givenName  = 'FirstName'
    }
    active     = { $_.'WorkerStatus' -eq 'Active' }
    userName   = 'UserID'
    displayName = 'FullName'
    nickName = 'UserID'
    userType = 'WorkerType'
    title = 'JobTitle'
    "urn:ietf:params:scim:schemas:extension:enterprise:2.0:User" = @{
        employeeNumber = 'WorkerID'
        costCenter = 'CostCenter'
        organization = 'Company'
        division = 'Division'
        department = 'Department'
        manager = @{
            value = 'ManagerID'
        }
    }
}