Param (
       [string]$organisation = "",
       [string]$key = ""
       )

$assettypeID = 120571
$ITGbaseURI = "https://api.itglue.com"

Import-Module C:\temp\itglue\modules\itgluepowershell\ITGlueAPI.psd1 -Force
Add-ITGlueAPIKey -Api_Key $key
Add-ITGlueBaseURI -base_uri $ITGbaseURI

function GetAllITGItems ($Resource) {
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

function CreateITGItem ($resource, $body) {
    $item = Invoke-RestMethod -Method POST -ContentType application/vnd.api+json -Uri $ITGbaseURI/$resource -Body $body -Headers $headers
    return $item
}

function UpdateITGItem ($resource, $existingItem, $newBody) {
    $updatedItem = Invoke-RestMethod -Method Patch -Uri "$ITGbaseUri/$Resource/$($existingItem.id)" -Headers $headers -ContentType application/vnd.api+json -Body $newBody
    return $updatedItem
}

function CreateMappedDriveAsset ($tenantInfo) {

    $body = @{
        data = @{
            type       = "flexible-assets"
            attributes = @{
                "organization-id"        = $ITGlueOrganisation
                "flexible-asset-type-id" = $assettypeID
                traits                      = @{
                    "drive-letter"          = $tenantInfo.DriveLetter
                    "drive-label"           = $tenantInfo.DriveLabel
                    "drive-path"            = $tenantInfo.DrivePath
                    "item-level-targetting" = $tenantInfo.DriveFilterGroup

                }
            }
        }
 }


 $tenantAsset = $body | ConvertTo-Json -Depth 10
 return $tenantAsset
}


 
$headers = @{
    "x-api-key" = $key
}

Write-Host Attempting match of ITGlue Company using name $organisation -ForegroundColor Green

$attempted_match = Get-ITGlueOrganizations -filter_name "$organisation"

if($attempted_match.data[0].attributes.name -eq $organisation) {
            Write-Host "Auto-match of ITGlue company successful." -ForegroundColor Green

            $ITGlueOrganisation = $attempted_match.data.id
}
            else {
            Write-Host "No auto-match was found. Please pass the exact name in ITGlue to -organization <string>" -ForegroundColor Red
            Exit
            }


#Import the required module GroupPolicy
$drivearray = @()
try
{
Import-Module GroupPolicy -ErrorAction Stop
}
catch
{
throw "Module GroupPolicy not Installed"
}
        $GPO = Get-GPO -All
 
        foreach ($Policy in $GPO){
 
                $GPOID = $Policy.Id
                $GPODom = $Policy.DomainName
                $GPODisp = $Policy.DisplayName
 
                 if (Test-Path "\\$($GPODom)\SYSVOL\$($GPODom)\Policies\{$($GPOID)}\User\Preferences\Drives\Drives.xml")
                 {
                     [xml]$DriveXML = Get-Content "\\$($GPODom)\SYSVOL\$($GPODom)\Policies\{$($GPOID)}\User\Preferences\Drives\Drives.xml"
 
                            foreach ( $drivemap in $DriveXML.Drives.Drive ){

                                    $GPOName = $GPODisp
                                    $DriveLetter = $drivemap.Properties.Letter + ":"
                                    $DrivePath = $drivemap.Properties.Path
                                    $DriveAction = $drivemap.Properties.action.Replace("U","Update").Replace("C","Create").Replace("D","Delete").Replace("R","Replace")
                                    $DriveLabel = $drivemap.Properties.label
                                    $DrivePersistent = $drivemap.Properties.persistent.Replace("0","False").Replace("1","True")
                                    [string]$DriveFilterGroup = $drivemap.Filters.FilterGroup.Name
 
                                    $Object = New-Object PSObject 
                                    $object | Add-Member -MemberType NoteProperty -Name GPOName -Value $GpoName
                                    $object | Add-Member -MemberType NoteProperty -Name DriveLetter -Value $DriveLetter
                                    $object | Add-Member -MemberType NoteProperty -Name DrivePath -Value $DrivePath
                                    $object | Add-Member -MemberType NoteProperty -Name DriveAction -Value $DriveAction
                                    $object | Add-Member -MemberType NoteProperty -Name DriveLabel -Value $DriveLabel
                                    $object | Add-Member -MemberType NoteProperty -Name DrivePersistent -Value $DrivePersistent
                                    $object | Add-Member -MemberType NoteProperty -Name DriveFilterGroup -Value $DriveFilterGroup
                                    $drivearray += $Object

                                    }
                                     foreach ($obj in $drivearray){
 
                                    $existingAssets = @()
                                    $existingAssets += GetAllITGItems -Resource "flexible_assets?filter[organization_id]=$ITGlueOrganisation&filter[flexible_asset_type_id]=$assetTypeID"
                                    $matchingAsset = $existingAssets | Where-Object {$_.attributes.traits.'drive-path' -contains $obj.DrivePath}

                                        if ($matchingAsset) {
                                            Write-Output "Updating Mapped Drive Flexible Asset for $obj.DriveLabel"
                                            $UpdatedBody = CreateMappedDriveAsset -tenantInfo $obj
                                            $updatedItem = UpdateITGItem -resource flexible_assets -existingItem $matchingAsset -newBody $UpdatedBody
                                            Start-Sleep -Seconds 3
                                            }
                                            else {
                                                Write-Output "Creating Mapped Drive Flexible Asset for $obj.DriveLabel"
                                                $body = CreateMappedDriveAsset -tenantInfo $obj
                                                CreateITGItem -resource flexible_assets -body $body
                                                Start-Sleep -Seconds 3
        
                                            }



                                  }
                            }
                }
        
 

