
## Create Self-Signed Certificate on the Device where client app will authenticate
$ClientCertificate = New-SelfSignedCertificate -Subject 'CN=CSV2SCIM' -KeyExportPolicy 'NonExportable' -CertStoreLocation Cert:\CurrentUser\My

## ToDo: Remove private key from certificate before uploading.

## Replace certificates on application registration with newly created certificate
$App = Get-MgApplication -ApplicationId '9341c084-4208-400d-a2bf-89689e658a38' -Property id, displayName, keyCredentials
Update-MgApplication -ApplicationId '9341c084-4208-400d-a2bf-89689e658a38' -KeyCredentials @{
    Type = "AsymmetricX509Cert"
    Usage = "Verify"
    Key = $ClientCertificate.GetRawCertData()
}
