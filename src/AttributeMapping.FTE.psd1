@{
    externalId   = 'externalId'
    name         = @{
        familyName = 'familyName'
        givenName  = 'givenName'
    }
    active       = 'active'
    userName     = 'userName'
    displayName  = 'displayName'
    nickName     = 'nickName'
    userType     = 'userType'
    title        = 'title'
    emails       = @(
        @{
            value = 'email'
        }
    )
    addresses    = @(
        @{
            streetAddress = 'streetAddress'
            locality      = 'locality'
            postalCode    = 'postalCode'
            country       = 'country'
        }
    )
    phoneNumbers = @(
        @{
            value = 'phoneNumber'
        }
    )
    "urn:ietf:params:scim:schemas:extension:enterprise:2.0:User" = @{
        employeeNumber = 'employeeNumber'
        costCenter     = 'costCenter'
        organization   = 'organization'
        division       = 'division'
        department     = 'department'
        manager        = @{
            value = 'manager'
        }
    }
}