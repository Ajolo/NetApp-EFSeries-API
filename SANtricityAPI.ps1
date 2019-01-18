# EF-Series System Manager API Test

# =========================
# Globals
# =========================

# tell powershell to use alt security protocols for connection
[Net.ServicePointManager]::SecurityProtocol = "Tls12, Tls11, Tls, Ssl3"
add-type @"
    using System.Net;
    using System.Security.Cryptography.X509Certificates;
    public class TrustAllCertsPolicy : ICertificatePolicy {
        public bool CheckValidationResult(
            ServicePoint srvPoint, X509Certificate certificate,
            WebRequest request, int certificateProblem) {
            return true;
        }
    }
"@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy

# node IPs
$EFSeriesC2A = "https://0.0.0.0:8443/devmgr"

# creds
$username = "admin"
$pass = "redacted"

# persist web session after logging in 
$session = New-Object Microsoft.Powershell.Commands.WebRequestSession

# headers
$headers = @{}
$headers.Add('accept','application/json')
$headers.Add('Content-Type','application/json')

# misc
$storageSystemId = "1"



# =========================
# Initiate Session
# =========================
# as alternative, can also store creds as plaintext in url:
# Invoke-RestMethod -Method Get -Uri ($EFSeriesC2A+"devmgr/utils/login?uid=admin&pwd=myPassword123&xsrf=false&onlycheck=false") -Headers $headers

Function LoginAPI ($username, $pass) {
    $credentialsJSON = '
    {
      "userId": "' + $username + '", 
      "password": "' + $pass + '"
    }'

    $restParams = @{
        Method     = 'Post'
        Uri        = $EFSeriesC2A+"utils/login"
        Headers    = $headers 
        Body       = $credentialsJSON
        WebSession = $session
    }

    Invoke-RestMethod @restParams
}
# LoginAPI $username $pass



# =========================
# GET Functions
# =========================
# Ex endpoints: 
# Invoke-RestMethod -Method Get -Uri ($EFSeriesC2A+"devmgr/utils/about") -Headers $headers
# Invoke-RestMethod -Method Get -Uri ($EFSeriesC2A+"devmgr/utils/buildinfo") -Headers $headers

Function GetStorageSystems {
    $restParams = @{
        Method     = 'Get'
        Uri        = $EFSeriesC2A+"v2/storage-systems"
        Headers    = $headers 
        WebSession = $session
    }

    try {
        Invoke-RestMethod @restParams
    }
    catch {
        CatchException $restParams
    }
}
GetStorageSystems


Function GetEvents {
    $restParams = @{
        Method     = 'Get'
        Uri        = $EFSeriesC2A+"v2/events"
        Headers    = $headers 
        WebSession = $session
    }

    try {
        Invoke-RestMethod @restParams
    }
    catch {
        CatchException $restParams
    }
}
GetEvents

Function GetVolumes {
    $restParams = @{
        Method     = 'Get'
        Uri        = $EFSeriesC2A+"v2/storage-systems/"+$storageSystemId+"/volumes"
        Headers    = $headers 
        WebSession = $session
    }

    try {
        Invoke-RestMethod @restParams
    }
    catch {
        CatchException $restParams
    }
}
GetVolumes


Function GetControllerID {
    $restParams = @{
        Method     = 'Get'
        Uri        = $EFSeriesC2A+"v2/storage-systems/"+$storageSystemId+"/controllers"
        Headers    = $headers 
        WebSession = $session
    }  
      
    try {
        (Invoke-RestMethod @restParams).controllerRef[0]
    }
    catch {
        CatchException $restParams
    }

}
GetControllerID

Function GetStoragePool {
    $restParams = @{
        Method     = 'Get'
        Uri        = $EFSeriesC2A+"v2/storage-systems/"+$storageSystemId+"/storage-pools"
        Headers    = $headers 
        WebSession = $session
    }

    try {
        (Invoke-RestMethod @restParams).volumeGroupRef
    }
    catch {
        CatchException $restParams
    }
}
GetStoragePool

Function GetHosts {
    $restParams = @{
        Method     = 'Get'
        Uri        = $EFSeriesC2A+"v2/storage-systems/"+$storageSystemId+"/hosts"
        Headers    = $headers 
        WebSession = $session
    }

    try {
        Invoke-RestMethod @restParams
    }
    catch {
        CatchException $restParams
    }
}
GetHosts



# =========================
# POST Functions
# =========================

Function CreateVolume ($volName, $size) {
    $controllerId = GetControllerID
    $poolId = GetStoragePool
    $volumeDetails = '
    {
       "poolId": "' + $poolId + '",
       "name": "' + $volName + '",
       "sizeUnit": "gb",
       "size": "' + $size + '",
       "segSize": 0,
       "dataAssuranceEnabled": false,
       "owningControllerId": "' + $controllerId + '",
       "metaTags": [
        {
            "key": "string",
            "value": "string"
        }
       ] 
    }'
    
    $restParams = @{
        Method     = 'Post'
        Uri        = $EFSeriesC2A+"v2/storage-systems/"+$storageSystemId+"/volumes"
        Headers    = $headers
        Body       = $volumeDetails 
        WebSession = $session
    }

    try {
        Invoke-RestMethod @restParams
    }
    catch {
        CatchException $restParams
    }
}
CreateVolume mapThisVol 25



# =========================
# Volume Mapping
# =========================

Function MapVolume ($targetHost, $targetVol) {
    $mappingDetails = '
    {
        "mappableObjectId": "' + $targetVol + '",
        "targetId": "' + $targetHost + '"
    }'

    $restParams = @{
        Method     = 'Post'
        Uri        = $EFSeriesC2A+"v2/storage-systems/"+$storageSystemId+"/volume-mappings"
        Headers    = $headers 
        Body       = $mappingDetails
        WebSession = $session
    }
    
    try {
        Invoke-RestMethod @restParams
    }
    catch {
        CatchException $restParams
    }
}
# MapVolume <target host id> <target volume id>
MapVolume "84000000600A098000BF6F310030060D5C3C58CA" "02000000600A098000BF85F300001E555C41E60F" 



# =========================
# Exception Handler
# =========================

Function CatchException ($restParams) {
    Write-Host $restParams
    if ($_.Exception.Message -like "*401*") {
        Write-Host "Not logged in -- attempting log in now . . ."
        LoginAPI $username $pass
        Invoke-RestMethod @restParams
    }
    else {
        Write-Host ($_.Exception.Message)
    }
}



# =========================
# WIP
# =========================

# diskDriveIds might expect [ "0, 1, 2, ... etc " ] instead of ex. below
$filesystem = '
{
    "raidLevel": "0",
    "diskDriveIds": [ "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10" ], 
    "eraseSecuredDrives": true,
    "name": "mySecondPool"
}'
# -ContentType 'application/json'
# Invoke-RestMethod -Method Post -Uri ($EFSeriesC2A+"devmgr/v2/storage-systems/1/storage-pools") -Headers $headers -Body $filesystem -ContentType 'application/json' -WebSession $session