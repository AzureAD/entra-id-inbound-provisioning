
## Create Self-Signed Certificate on the Device where client app will authenticate
$ClientCertificate = New-SelfSignedCertificate -Subject 'CN=CSV2SCIM' -KeyExportPolicy 'NonExportable' -CertStoreLocation Cert:\CurrentUser\My
$ClientCertificate
$ThumbPrint = $ClientCertificate.ThumbPrint
Connect-MgGraph -Scopes "Application.ReadWrite.All"
## Replace certificates on application registration with newly created certificate
# Insert the objectId of your application registration where the public certificate should be uploaded.
Update-MgApplication -ApplicationId '00000000-0000-0000-0000-000000000000' -KeyCredentials @{
    Type = "AsymmetricX509Cert"
    Usage = "Verify"
    Key = $ClientCertificate.RawData
}
