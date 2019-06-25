try {
    Import-Module ITGlueAPI -ErrorAction Stop
    Get-Variable ITGlue_API_Key -ErrorAction Stop > $null
    Get-Variable ITGlue_Base_URI -ErrorAction Stop > $null
} catch {
    $apikey = Read-Host "Enter IT Glue API key"
    do{
        $datacenter = Read-Host "Enter IT Glue data center (EU/US)"
    } until($datacenter -eq 'EU' -or $datacenter -eq 'US')

    Add-ITGlueAPIKey -Api_Key $apikey
    Add-ITGlueBaseURI -data_center $datacenter
    Export-ITGlueModuleSettings
}

$flexible_asset_id = Read-Host "Enter flexible asset id (unique ID for asset to update)"

# Create scheduled task
# Action
$action = New-ScheduledTaskAction -Execute 'Powershell.exe' -Argument ('-ExecutionPolicy Bypass -NoProfile -WindowStyle Hidden "{0}\ITGlue-VMHost-FeedFlexibleAssetHyperV.ps1 -flexible_asset_id {1}"' -f $PSScriptRoot, $flexible_asset_id)
# Trigger
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date)
# Settings
$settings = New-ScheduledTaskSettingsSet -WakeToRun -RestartCount 3 -RunOnlyIfNetworkAvailable -StartWhenAvailable -RestartInterval (New-TimeSpan -Minutes 3)
# Add to task scheduler
Register-ScheduledTask -Action $action -Trigger $trigger -TaskPath "\ITGlueSync\" -TaskName "Sync HyperV with IT Glue" -Settings $settings -Force