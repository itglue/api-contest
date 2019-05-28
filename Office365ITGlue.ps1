param([string] $varITGKey)

#
# Allows connection via HTTPS
#      

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

#
# Import MSOnline Module
#

Import-Module "c:\temp\itglue\modules\Office365\msonline\MSOnline.psd1"

#
# Variables
#

$key = "$varITGKey"
$ITGbaseURI = "https://api.itglue.com"
$assettypeID = 107594
 
$headers = @{
    "x-api-key" = $key
}

#
# Functinos
#

Function Get-StringHash([String] $String, $HashName = "MD5") { 
    $StringBuilder = New-Object System.Text.StringBuilder 
    [System.Security.Cryptography.HashAlgorithm]::Create($HashName).ComputeHash([System.Text.Encoding]::UTF8.GetBytes($String))| % { 
        [Void]$StringBuilder.Append($_.ToString("x2")) 
    } 
    $StringBuilder.ToString() 
}
     
function Get-ITGlueItem($Resource) {
    $array = @()
 
    $body = Invoke-RestMethod -Method get -Uri "$ITGbaseUri/$Resource" -Headers $headers -ContentType application/vnd.api+json
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
    
function CreateITGItem ($resource, $body) {
    $item = Invoke-RestMethod -Method POST -ContentType application/vnd.api+json -Uri $ITGbaseURI/$resource -Body $body -Headers $headers
    return $item
}
    
function UpdateITGItem ($resource, $existingItem, $newBody) {
    $updatedItem = Invoke-RestMethod -Method Patch -Uri "$ITGbaseUri/$Resource/$($existingItem.id)" -Headers $headers -ContentType application/vnd.api+json -Body $newBody
    return $updatedItem
}
    
function Build365TenantAsset ($tenantInfo) {
    
    $body = @{
        data = @{
            type       = "flexible-assets"
            attributes = @{
                "organization-id"        = $tenantInfo.ITGlueOrgID
                "flexible-asset-type-id" = $assettypeID
                traits                   = @{
                    "tenant-name"      = $tenantInfo.TenantName
                    "tenant-id"        = $tenantInfo.TenantID
                    "initial-domain"   = $tenantInfo.InitialDomain
                    "verified-domains" = $tenantInfo.Domains
                    "licenses"         = $tenantInfo.Licenses
                    "licensed-users"   = $tenantInfo.LicensedUsers
                }
            }
        }
    }
    
    $tenantAsset = $body | ConvertTo-Json -Depth 10
    return $tenantAsset
}

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

#
# Gather all Office 365 passwords from ITGlue 
#

Write-Host "Gathering all Office 365 Passwords from ITGlue" -ForegroundColor Green

$passwords = Get-ITGlueItem -Resource passwords 
$passwords = $passwords | Where {$_.attributes.'password-category-name' -eq 'Microsoft Office 365 Admin'}

$ITGluepasswords = @()

foreach($password in $passwords){
    $details = Get-ITGlueItem -Resource passwords/$($password.id) 
   
        $customer = $details.attributes.'organization-name'
        $customerID = $details.attributes.'organization-id'
        $category = $details.attributes.'password-category-name'
        $itgUsername = $details.attributes.username
        $itgpassword = $details.attributes.password
        $passwordID = $details.id

        $Object = New-Object PSObject 
        $object | Add-Member -MemberType NoteProperty -Name Customer -Value $customer
        $object | Add-Member -MemberType NoteProperty -Name CustomerID -Value $customerID
        $object | Add-Member -MemberType NoteProperty -Name Category -Value $category
        $object | Add-Member -MemberType NoteProperty -Name itgUsername -Value $itgUsername
        $object | Add-Member -MemberType NoteProperty -Name itgPassword -Value $itgpassword
        $object | Add-Member -MemberType NoteProperty -Name PasswordID -Value $passwordID
        $ITGluepasswords += $object

    }


Write-Host "Passwords gathered and sorted, now starting all customers loop.." -ForegroundColor Green

foreach ($itgluepassword in $ITGluepasswords){

$o365user = $ITGluepassword.itgUsername 
$o365pass = $ITGluepassword.itgPassword 
$pass= convertto-securestring -string $o365pass -asplaintext -force
$mycred = new-object -typename System.Management.Automation.PSCredential -argumentlist $o365user,$pass
$O365Cred = Get-Credential $mycred
Connect-MsolService -Credential $O365Cred

$ITGlueOrganisation = AttemptMatch -attemptedorganisation $ITGluepassword.Customer

try 

{$customer = Get-MsolCompanyInformation

    
$365domains = @()
    

    Write-Host "Getting domains for $($customer.DisplayName)" -ForegroundColor Green
    $companyInfo = Get-MSOLCompanyInformation | select objectID
    
    $customerDomains = Get-MsolDomain -TenantId $companyInfo.ObjectId | Where-Object {$_.status -contains "Verified"}
    $initialDomain = $customerDomains | Where-Object {$_.isInitial}
    $Licenses = $null
    $licenseTable = $null
    $Licenses = Get-MsolAccountSku -TenantId $customer.TenantId
    if ($licenses) {
        $licenseTableTop = "<br/><table class=`"table table-bordered table-hover`" style=`"width:600px`"><thead><tr><th>License Name</th><th>Active</th><th>Consumed</th><th>Unused</th></tr></thead><tbody><tr><td>"
        $licenseTableBottom = "</td></tr></tbody></table>"
        $licensesColl = @()
        foreach ($license in $licenses) {
            $licenseString = "$($license.SkuPartNumber)</td><td>$($license.ActiveUnits) active</td><td>$($license.ConsumedUnits) consumed</td><td>$($license.ActiveUnits - $license.ConsumedUnits) unused"
            $licensesColl += $licenseString
        }
        if ($licensesColl) {
            $licenseString = $licensesColl -join "</td></tr><tr><td>"
        }
        $licenseTable = "{0}{1}{2}" -f $licenseTableTop, $licenseString, $licenseTableBottom
    }
    $licensedUserTable = $null
    $licensedUsers = $null
    $licensedUsers = get-msoluser -TenantId $customer.TenantId -All | Where-Object {$_.islicensed} | Sort-Object UserPrincipalName
    if ($licensedUsers) {
        $licensedUsersTableTop = "<br/><table class=`"table table-bordered table-hover`" style=`"width:80%`"><thead><tr><th>Display Name</th><th>Addresses</th><th>Assigned Licenses</th></tr></thead><tbody><tr><td>"
        $licensedUsersTableBottom = "</td></tr></tbody></table>"
        $licensedUserColl = @()
        foreach ($user in $licensedUsers) {
           
            $aliases = (($user.ProxyAddresses | Where-Object {$_ -cnotmatch "SMTP" -and $_ -notmatch ".onmicrosoft.com"}) -replace "SMTP:", " ") -join "<br/>"
            $licensedUserString = "$($user.DisplayName)</td><td><strong>$($user.UserPrincipalName)</strong><br/>$aliases</td><td>$(($user.Licenses.accountsku.skupartnumber) -join "<br/>")"
            $licensedUserColl += $licensedUserString
        }
        if ($licensedUserColl) {
            $licensedUserString = $licensedUserColl -join "</td></tr><tr><td>"
        }
        $licensedUserTable = "{0}{1}{2}" -f $licensedUsersTableTop, $licensedUserString, $licensedUsersTableBottom
    
    
    }
        
        
    $hash = [ordered]@{
        ITGlueOrgID       = $ITGlueOrganisation
        ITGlueOrgName     = $itgluepassword.Customer
        TenantName        = $customer.displayname
        Domains           = $customerDomains.name
        TenantId          = $customer.TenantId
        InitialDomain     = $initialDomain.name
        Licenses          = $licenseTable
        LicensedUsers     = $licensedUserTable
    }
    $object = New-Object psobject -Property $hash
    $365domains += $object
}        
catch {
Write-Host "Failed to connect to Office 365 for $($ITGluepassword.Customer), see error below:"
Write-Error $_}
    
foreach ($obj in $365domains){
    if ($obj -ne $null){
    $existingAssets = @()
    $existingAssets += GetAllITGItems -Resource "flexible_assets?filter[organization_id]=$ITGlueOrganisation&filter[flexible_asset_type_id]=$assetTypeID"
    $matchingAsset = $existingAssets | Where-Object {$_.attributes.traits.'tenant-name' -contains $obj.TenantName}
        
    if ($matchingAsset) {
        Write-Host "Updating Office 365 tenant for $($obj.ITGlueOrgName)"
        $UpdatedBody = Build365TenantAsset -tenantInfo $obj
        $updatedItem = UpdateITGItem -resource flexible_assets -existingItem $matchingAsset -newBody $UpdatedBody
    }
    else {
        Write-Host "Creating Office 365 tenant for $($obj.ITGlueOrgName)"
        $newBody = Build365TenantAsset -tenantInfo $obj
        $newItem = CreateITGItem -resource flexible_assets -body $newBody
    }
}

}

}


