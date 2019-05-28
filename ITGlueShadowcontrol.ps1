Param (
       [string]$key = "",
       [string]$SCkey = "",
       [string]$hostname = ""
       )

if (-not ([System.Management.Automation.PSTypeName]'ServerCertificateValidationCallback').Type)
{
$certCallback = @"
    using System;
    using System.Net;
    using System.Net.Security;
    using System.Security.Cryptography.X509Certificates;
    public class ServerCertificateValidationCallback
    {
        public static void Ignore()
        {
            if(ServicePointManager.ServerCertificateValidationCallback ==null)
            {
                ServicePointManager.ServerCertificateValidationCallback += 
                    delegate
                    (
                        Object obj, 
                        X509Certificate certificate, 
                        X509Chain chain, 
                        SslPolicyErrors errors
                    )
                    {
                        return true;
                    };
            }
        }
    }
"@
    Add-Type $certCallback
 }
[ServerCertificateValidationCallback]::Ignore()

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$assettypeID = 108492
$ITGbaseURI = "https://api.itglue.com"
$headers = @{
    "x-api-key" = $key
}

Import-Module C:\temp\itglue\modules\itgluepowershell\ITGlueAPI.psd1 -Force
Add-ITGlueAPIKey -Api_Key $key
Add-ITGlueBaseURI -base_uri $ITGbaseURI

function AttemptMatch($attemptedorganisation) {
$attempted_match = Get-ITGlueOrganizations -filter_name $attemptedorganisation
if($attempted_match.data[0].attributes.name -eq $attemptedorganisation) {
            Write-Host "Auto-match of ITGlue company successful." -ForegroundColor Green

            $ITGlueOrganisation = $attempted_match.data.id
}
            else {
            Write-Host "No auto-match was found. Please pass the exact name in ITGlue to -organization <string>" -ForegroundColor Red
            Exit
            }
        return $ITGlueOrganisation

           
      }




function Get-ObjectMembers {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$True, ValueFromPipeline=$True)]
        [PSCustomObject]$obj
    )
    $obj | Get-Member -MemberType NoteProperty | ForEach-Object {
        $key = $_.Name
        [PSCustomObject]@{Key = $key; Value = $obj."$key"}
    }
}

function GetAllITGItems($Resource) {
    $array = @()
    
    $body = Invoke-RestMethod -Method get -Uri "$ITGbaseURI/$Resource" -Headers $headers -ContentType application/vnd.api+json
    $array += $body.data
    Write-Host "Retrieved $($array.Count) items"
        
    if ($body.links.next) {
        do {
            $body = Invoke-RestMethod -Method get -Uri $body.links.next -Headers $headers -ContentType application/vnd.api+json
            $array += $body.data
            Write-Host "Retrieved $($array.Count) items"
        } while ($body.links.next)
    }
    return $array
}

function Get-ITGlueItem($Resource) {
    $array = @()
 
    $body = Invoke-RestMethod -Method get -Uri $ITGbaseURI/organizations/$ITGlueOrganisation/relationships/configurations -Headers $headers -ContentType application/vnd.api+json
    $array += $body.data
    Write-Host "Retrieved $($array.Count) items"
 
    if ($body.links.next) {
        do {
            $body = Invoke-RestMethod -Method get -Uri $body.links.next -Headers $headers -ContentType application/vnd.api+json
            $array += $body.data
            Write-Host "Retrieved $($array.Count) items"
        } while ($body.links.next)
    }
    return $array
}

function CreateITGItem ($resource, $body) {
    $item = Invoke-RestMethod -Method POST -ContentType application/vnd.api+json -Uri $ITGbaseURI/$resource -Body $body -Headers $headers
    #return $item
}
    
function UpdateITGItem ($resource, $existingItem, $newBody) {
    $updatedItem = Invoke-RestMethod -Method Patch -Uri "$ITGbaseUri/$Resource/$($existingItem.id)" -Headers $headers -ContentType application/vnd.api+json -Body $newBody
    return $updatedItem
}

function BuildShadowControlTenantAsset ($tenantInfo) {
    
    $body = @{
        data = @{
            type       = "flexible-assets"
            attributes = @{
                "organization-id"        = $ITGlueOrganisation
                "flexible-asset-type-id" = $assettypeID
                traits                   = @{
                    "protected-server"        = $obj.ServerID
                    "storagecraft-product"    = $obj.SPName
                    "shadowprotect-version"   = $obj.SPVersion
                    "backup-name"             = $obj.JobName
                    "backup-destination"      = $obj.JobDestination
                    "backup-mode"             = $obj.JobMode
                    "backup-schedule"         = $obj.JobSchedule
                    "imagemanager-version"    = $obj.IMVersion
                    "imagemanager-managed-folders"     = $obj.IMManagedFolders
                    "imagemanager-replication"         = $obj.RepType
                    "imagemanager-replication-jobs"    = $obj.IMJobs
                }
            }
        }
 }
    
    $tenantAsset = $body | ConvertTo-Json -Depth 10
    return $tenantAsset
}

Write-Host Connecting to ShadowControl to retrieve list of connected devices. -ForegroundColor Green

#Connect to Shadowcontrol and query all endpoints for a customer

$endpoints = @()
$hostname = 'https://' + $hostname + '/api/reports/status/?'
$web = invoke-webrequest -Uri $hostname -Headers @{"CMD_TOKEN" = $sckey} -UseBasicParsing 
$endpoints = $web.content | ConvertFrom-Json | Get-ObjectMembers 

$array = @()
foreach ($endpoint in $endpoints.value){
    
    if ($endpoint.shadowprotect.jobs){
    if ($endpoint.shadowprotect.jobs.status -notcontains "offline"){
    $Servername = $endpoint.name
    $Org = $endpoint.org
    $Status = $endpoint.status
    $SPName = $endpoint.shadowprotect.version.name
    $SPVersion = $endpoint.shadowprotect.version.version
    $jobs = $endpoint.shadowprotect.jobs
      foreach ($job in $jobs){  
            $jobname  = $job.name
            $jobdest  = $job.destination 
            $jobmode = $job.last_mode
            $jobsch  = $job.schedule.repeats
                if($jobsch -eq 60){
                        $jobsch = "Hourly"}
                elseif($jobsch -eq 15){
                        $jobsch = "Every 15 Minutes"
                        }
                elseif($jobsch -eq 720){
                        $jobsch = "Every 12 Hours"
                        }
                elseif($jobsch -eq 240){
                        $jobsch = "Every 4 Hours"
                        }
                elseif($jobsch -eq 30){
                        $jobsch = "Every 30 Minutes"
                        }
                elseif($jobsch -eq 660){
                        $jobsch = "Every 11 Hours"
                        }
                elseif($jobsch -eq 480){
                        $jobsch = "Every 8 Hours"
                        }
                elseif($jobsch -eq 125){
                        $jobsch = "Every 2 Hours"
                        }
                elseif($jobsch -eq 120){
                        $jobsch = "Every 2 Hours"
                        }
                elseif($jobsch -eq 180){
                        $jobsch = "Every 3 Hours"
                        }
                elseif($jobsch -eq 600){
                        $jobsch = "Every 10 Hours"
                        }
                elseif($jobsch -eq 300){
                        $jobsch = "Every 5 Hours"
                        }
                    

                $object = New-Object psobject
                $object | Add-Member -MemberType NoteProperty -Name ServerName -Value $Servername
                $object | Add-Member -MemberType NoteProperty -Name SPName -Value $SPName
                $object | Add-Member -MemberType NoteProperty -Name SPVersion -Value $SPVersion
                $object | Add-Member -MemberType NoteProperty -Name Organisation -Value $org
                $object | Add-Member -MemberType NoteProperty -Name Status -Value $status
                $object | Add-Member -MemberType NoteProperty -Name JobName -Value $jobname
                $object | Add-Member -MemberType NoteProperty -Name JobDestination -Value $jobdest
                $object | Add-Member -MemberType NoteProperty -Name JobMode -Value $jobmode
                $object | Add-Member -MemberType NoteProperty -Name JobSchedule -Value $jobsch

            $array += $object
                            }
                                    } 
    
}

}

$IMArray = @()
foreach ($endpoint in $endpoints.value){
    if ($endpoint.imagemanager.folders){
    
    $IMPCName = $endpoint.name
    $IMVersion = $endpoint.imagemanager.version.version
    $IMManagedFolders = $endpoint.imagemanager.folders.path
    $IMManagedFolders = $IMManagedFolders -join "<br>" | Out-String
    

        if ($endpoint.imagemanager.folders.'replication_jobs'){
        
        $RepType = $endpoint.imagemanager.folders.replication_jobs.'target_location_type'
            if($RepType -eq 'local'){
                        $RepType = "Local Drive"}
                elseif($RepType -eq 'ftp'){
                        $RepType = "FTP"
                        }
                elseif($RepType -eq 'cloud_2'){
                        $RepType = "Storagecraft Cloud"
                        }
                elseif($RepType -eq 'network'){
                        $RepType = "Local Network"
                        }

        $IMJobs = $endpoint.imagemanager.folders.replication_jobs.name
        $IMJobs = $IMJobs -join "<br>" | Out-String
       
        
        
        $object2 = New-Object psobject
        $object2 | Add-Member -MemberType NoteProperty -Name ServerName -Value $IMPCName
        $object2 | Add-Member -MemberType NoteProperty -Name IMVersion -Value $IMVersion
        $object2 | Add-Member -MemberType NoteProperty -Name IMManagedFolders -Value $IMManagedFolders
        $object2 | Add-Member -MemberType NoteProperty -Name RepType -Value $RepType
        $object2 | Add-Member -MemberType NoteProperty -Name IMJobs -Value $IMJobs
       

        $IMArray += $object2
        
        }
     
    
    }


}

Write-Host Retrieved devices and information from ShadowControl. -ForegroundColor Green

$allorgs = Get-ITGlueOrganizations -page_size 200
$allorgs = $allorgs.data.attributes.name

Write-Host Starting all organisation loop...

foreach ($org in $allorgs){

$ITGlueOrganisation = AttemptMatch -attemptedorganisation $org

Write-Host Retrieving customer configurations from ITGlue for $org -ForegroundColor Green

$customerservers = Get-ITGlueItem

Start-Sleep -Seconds 3

$customerservers = $customerservers.attributes.name

$protectedservers = @()
foreach ($item in $array){
 foreach ($Srvr in $CustomerServers){
  if($item.ServerName -ne $Srvr){
   #Do not add to $protectedservers
  }
  else {
  #add object to protectedservers
   $protectedservers += $item
  }
 }
}

$IMServers = @()
foreach ($item in $IMarray){
 foreach ($Srvr in $CustomerServers){
  if($item.ServerName -ne $Srvr){
   #Do not add to $protectedservers
  }
  else {
  #add object to protectedservers
   $protectedservers += $item
  }
 }
}

$serverarray = @()
$protectedservers | ForEach-Object{
                # foreach ($prot in $protectedservers){
                if ($serverarray.Count -ne $protectedservers.Count){
                $PServerName = (Get-ITGlueConfigurations -filter_name $_.ServerName).data.attributes.'name' | Select-Object -First 1
                $PSID = (Get-ITGlueConfigurations -filter_name $_.ServerName).data.'id' | Select-Object -First 1
                $jobname = $_.JobName
                if ($jobname -eq $null){
                 $jobname = "Not Applicable"}
                $jobdest = $_.JobDestination
                if ($jobdest -eq $null){
                 $jobdest = "Not Applicable"}
                $jobmode = $_.JobMode
                if ($jobmode -eq $null){
                 $jobmode = "Not Applicable"}
                $jobsch = $_.JobSchedule
                if ($jobsch -eq $null){
                 $jobsch = "Not Applicable"}
                $spname = $_.SPName
                 if ($spname -eq $null){
                 $spname = "ImageManager"}
                $spversion = $_.SPVersion
                if ($spversion -eq $null){
                 $spversion = "Not Applicable"}
                $imversion = $_.IMVersion
                if ($imversion -eq $null){
                 $imversion = "Not Applicable"}
                $immanagedfolders = $_.IMManagedFolders
                if ($immanagedfolders -eq $null){
                 $immanagedfolders = "Not Applicable"}
                $RepType = $_.RepType
                if ($RepType -eq $null){
                 $RepType = "Not Applicable"}
                $IMJobs = $_.IMJobs
                if ($IMJobs -eq $null){
                 $IMJobs = "Not Applicable"}
                $object = New-Object psobject
                $object | Add-Member -MemberType NoteProperty -Name ServerName -Value $PServername
                $object | Add-Member -MemberType NoteProperty -Name ServerID -Value $PSID
                $object | Add-Member -MemberType NoteProperty -Name SPName -Value $SPName
                $object | Add-Member -MemberType NoteProperty -Name SPVersion -Value $SPVersion
                $object | Add-Member -MemberType NoteProperty -Name JobName -Value $jobname
                $object | Add-Member -MemberType NoteProperty -Name JobDestination -Value $jobdest
                $object | Add-Member -MemberType NoteProperty -Name JobMode -Value $jobmode
                $object | Add-Member -MemberType NoteProperty -Name JobSchedule -Value $jobsch
                $object | Add-Member -MemberType NoteProperty -Name IMVersion -Value $imversion
                $object | Add-Member -MemberType NoteProperty -Name IMManagedFolders -Value $immanagedfolders
                $object | Add-Member -MemberType NoteProperty -Name RepType -Value $RepType
                $object | Add-Member -MemberType NoteProperty -Name IMJobs -Value $IMJobs

                $serverarray += $object
                
                                                                        }

                                                }


write-host Finished gathering device information for $org, now updating ITGlue. -ForegroundColor Green

foreach ($obj in $serverarray){
$existingAssets = @()
$existingAssets += GetAllITGItems -Resource "flexible_assets?filter[organization_id]=$ITGlueOrganisation&filter[flexible_asset_type_id]=$assetTypeID"
$matchingAsset = $existingAssets | Where-Object {$_.attributes.traits.'protected-server'.values.name -contains $obj.ServerName}
$matchingAsset = $matchingAsset | Where-Object {$_.attributes.traits.'backup-name' -match $obj.Jobname}

if ($matchingAsset) {
        Write-Output "Updating Shadowcontrol object $($obj.ServerName) for $org"
        $UpdatedBody = BuildShadowControlTenantAsset -tenantInfo $obj
        $updatedItem = UpdateITGItem -resource flexible_assets -existingItem $matchingAsset -newBody $UpdatedBody
        Start-Sleep -Seconds 3
    }
    else {
        Write-Output "Creating Shadowcontrol object $($obj.ServerName) for $org"
        $body = BuildShadowControlTenantAsset -tenantInfo $obj
        CreateITGItem -resource flexible_assets -body $body
        Start-Sleep -Seconds 3
        
    }


    
    }

}