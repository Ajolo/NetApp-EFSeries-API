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
# GetStorageSystems


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
# GetEvents

Function GetVolumes ($getIdsOnly) {
    $restParams = @{
        Method     = 'Get'
        Uri        = $EFSeriesC2A+"v2/storage-systems/"+$storageSystemId+"/volumes"
        Headers    = $headers 
        WebSession = $session
    }

    try {
        if ($getIdsOnly -eq $true) {
            (Invoke-RestMethod @restParams).id
        }
        else {
            (Invoke-RestMethod @restParams)
        }
    }
    catch {
        CatchException $restParams
    }
}
# GetVolumes $true # '$false' returns all volume details


Function GetControllerId {
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
# GetControllerId

Function GetStoragePoolId {
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
# GetStoragePoolId

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
# GetHosts

Function GetDriveIds ($getIdsOnly) {
    $restParams = @{
        Method     = 'Get'
        Uri        = $EFSeriesC2A+"v2/storage-systems/"+$storageSystemId+"/drives"
        Headers    = $headers 
        WebSession = $session
    }

    try {
        if ($getIdsOnly -eq $true) {
            (Invoke-RestMethod @restParams).id
        }
        else {
            (Invoke-RestMethod @restParams)
        }
    }
    catch {
        CatchException $restParams
    }
}
# GetDriveIds $true # '$false' returns all drive details

Function GetSnapshots {
    $restParams = @{
        Method     = 'Get'
        Uri        = $EFSeriesC2A+"v2/storage-systems/"+$storageSystemId+"/snapshot-images"
        Headers    = $headers 
        WebSession = $session
    }

    try {
        (Invoke-RestMethod @restParams)
    }
    catch {
        CatchException $restParams
    }
}
# GetSnapshots



# =========================
# POST Functions
# =========================

Function CreateVolume ($volName, $size) {
    $controllerId = GetControllerId
    $poolId = GetStoragePoolId
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
# CreateVolume delThisVolume 25

Function MapVolume ($targetHostId, $targetVolId) {
    $mappingDetails = '
    {
        "mappableObjectId": "' + $targetVolId + '",
        "targetId": "' + $targetHostId + '"
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
# MapVolume "84000000600A098000BF6F310030060D5C3C58CA" "02000000600A098000BF85F300001E555C41E60F" 



# =========================
# DELETE Functions
# =========================

Function DeleteVolume ($targetVolId){
    $restParams = @{
        Method     = 'Delete'
        Uri        = $EFSeriesC2A+"v2/storage-systems/"+$storageSystemId+"/volumes/"+$targetVolId
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
# DeleteVolume 02000000600A098000BF85F300001E615C45CC56



# =========================
# Exception Handler
# =========================

Function CatchException ($restParams) {
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
# Function Calls
# =========================

# new session:
$session = New-Object Microsoft.Powershell.Commands.WebRequestSession

GetHosts