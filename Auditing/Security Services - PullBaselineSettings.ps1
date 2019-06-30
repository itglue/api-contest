###################################################################################################################################
# Access Key Vault for ITGlue API Key
$connectionName = "AzureRunAsConnection"
try
{
    # Get the connection "AzureRunAsConnection "
    $servicePrincipalConnection=Get-AutomationConnection -Name $connectionName         

    Add-AzureRmAccount `
        -ServicePrincipal `
        -TenantId $servicePrincipalConnection.TenantId `
        -ApplicationId $servicePrincipalConnection.ApplicationId `
        -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint 
}
catch {
    if (!$servicePrincipalConnection)
    {
        $ErrorMessage = "Connection $connectionName not found."
        throw $ErrorMessage
    } else{
        Write-Error -Message $_.Exception
        throw $_.Exception
    }
}
#############################################################################################################################################
# Baseline Variable, add your respective IDs
$ITG_Baseline_ID = "123456789"
$ITG_Flex_Asset_Type_ID = "1111222"

# Setting Azure Runbook Variables
$Az_Baseline_Check_Runbook = "Azure_Baseline_Check_Name" # Running "Security Services - CompareSettings.ps1"
$Az_Resource_Group = "Azure_Resource_Group"
$Az_Automation_Account = "Azure_Automation_Account_Name"
$Az_KeyVault_ITG_Key_Name = "ITG-API-Key-Name"
#############################################################################################################################################
# Getting ITGLUE API Key
$ITG_API_KEY = (Get-AzureKeyVaultSecret -VaultName EntechInternalKeyVault -Name "$Az_KeyVault_ITG_Key_Name").SecretValueText

#############################################################################################################################################
# Building ITGlue Headers
$ITGlue_Headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$ITGlue_Headers.Add("Content-Type", 'application/vnd.api+json')
$ITGlue_Headers.Add('x-api-key', $ITG_API_Key)

#############################################################################################################################################

$Data = Invoke-RestMethod -Method Get -Uri "https://api.itglue.com/flexible_assets/?filter[flexible_asset_type_id]=$ITG_Flex_Asset_Type_ID&page[size]=1000" -Headers $ITGlue_Headers

$SW_Security_Assets = $data.data

# Excluding the baseline Flexible Asset from the list of Sonicwalls to Check, add extra lines with the IDs that we need to exclude for future baselines.
$SW_Security_Assets = $SW_Security_Assets|Where-Object -Property id -NE -Value $ITG_Baseline_ID

$SW_Security_Assets | ForEach-Object {
    # Starts Next Script/Runbook and compares
    # Taking Properties out of the current flexible asset
    $Current_Flex_Asset_ID = $_.id
    $Current_Company_Name = $_.attributes.'organization-name'
    $Current_Company_ITG_ID = $_.attributes.'organization-id'
    
    # Building Paramters to Pass to Next Runbook
    $Param_Pass = @{"ITGClientID"="$Current_Company_ITG_ID";"FlexID"="$Current_Flex_Asset_ID";"CompanyName"="$Current_Company_Name"}

    # Starting The Next Runbook
    Start-AzureRmAutomationRunbook -Wait -Parameters $Param_Pass -Name "$Az_Baseline_Check_Runbook" -ResourceGroupName "$Az_Resource_Group" -MaxWaitSeconds 1000 -AutomationAccountName "$Az_Automation_Account"

    # Clean up variables
    Remove-Variable -Name Current_Flex_Asset_ID,Current_Company_Name,Current_Company_ITG_ID
}