Param(
    [int32]$ITGClientID,
    [int32]$FlexID,
    [string]$CompanyName
    )

#############################################################################################################################################
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
# Azure Variable Set
$Az_KeyValut_Secret_Name = "ITG-API-KEY"
$Az_KeyValut_Secret_Username = "CWM-API-Username"
$Az_KeyValut_Secret_Password = "CWM-API-Password"
# Created Baseline unique ITGlue ID
$ITG_Baseline_ID = "123123123"

#############################################################################################################################################
# Clean Company Name to make compatible with URL encoding
$URL_CompanyName = [uri]::EscapeDataString($CompanyName)
$URL_CompanyName|Write-Output

#############################################################################################################################################
# Connectwise Manage Variables
$CMW_API_Auth_Prefix = "company+"
$SW_MGMT_Port = "1234"
$ITG_SW_SOP_URL = "https://company.itglue.com/11111/docs/111111"
$CWM_API_Base_URI = "https://cw.company.com/v4_6_release/apis/3.0"
$CWM_Service_Board_Name = "Incoming"

#############################################################################################################################################
# Getting ITGLUE API Key
$ITG_API_KEY = (Get-AzureKeyVaultSecret -VaultName EntechInternalKeyVault -Name "$Az_KeyValut_Secret_Name").SecretValueText

#############################################################################################################################################
# Getting ConnectWise Manage API Keys
$CWM_API_Username_Key = (Get-AzureKeyVaultSecret -VaultName EntechInternalKeyVault -Name "$Az_KeyValut_Secret_Username").SecretValueText
$CWM_API_Password_Key = (Get-AzureKeyVaultSecret -VaultName EntechInternalKeyVault -Name "$Az_KeyValut_Secret_Password").SecretValueText

#############################################################################################################################################
# Building ITGlue Headers
$ITGlue_Headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$ITGlue_Headers.Add("Content-Type", 'application/vnd.api+json')
$ITGlue_Headers.Add('x-api-key', $ITG_API_Key)

#############################################################################################################################################
# Building ConnectWise Manage Headers
# First need to convert credentials to Base64, accepted by CWM API
# Need to add entech+ to the username
$CWM_API_Username_Key = "$CMW_API_Auth_Prefix" + $CWM_API_Username_Key

$CWM_credPair = "$($CWM_API_Username_Key):$($CWM_API_Password_Key)"
$CWM_encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($CWM_credPair))

$CWM_Headers = @{ Authorization = "Basic $CWM_encodedCredentials" }


# Search URI for Company ID by using the name of the company. Company name should be synced with ITGlue EXACTLY so shouldn't have an issue here.
$CWM_Get_ID_URI = "https://cw.entechus.com/v4_6_release/apis/3.0/company/companies?conditions=name=""$URL_CompanyName"" and status/id in (1, 18)"
$CWM_Get_ID_URI|Write-Output

$CWM_API_Results = Invoke-RestMethod -Method Get -Uri $CWM_Get_ID_URI -Headers $CWM_headers
$CWM_API_Results|Write-Output

$CWM_Company_Identifier = $CWM_API_Results.identifier
$CWM_Company_Identifier|Write-Output
#############################################################################################################################################
# Building Compare Object Properties Function
Function Compare-ObjectProperties {
    Param(
        [PSObject]$ReferenceObject,
        [PSObject]$DifferenceObject 
    )
    $objprops = $ReferenceObject | Get-Member -MemberType Property,NoteProperty | % Name
    $objprops += $DifferenceObject | Get-Member -MemberType Property,NoteProperty | % Name
    $objprops = $objprops | Sort | Select -Unique
    $diffs = @()
    foreach ($objprop in $objprops) {
        $diff = Compare-Object $ReferenceObject $DifferenceObject -Property $objprop
        if ($diff) {            
            $diffprops = @{
                SettingName=$objprop
                SOPSetting=($diff | ? {$_.SideIndicator -eq '<='} | % $($objprop))
                SonicwallSetting=($diff | ? {$_.SideIndicator -eq '=>'} | % $($objprop))
            }
            $diffs += New-Object PSObject -Property $diffprops
        }        
    }
    if ($diffs) {return ($diffs | Select SettingName,SOPSetting,SonicwallSetting)}     
}

#############################################################################################################################################
# Querying ITGlue for Baseline Settings and Current Sonicwall Settings

$SWSS_Baseline_Settings =  Invoke-RestMethod -Method Get -Uri "https://api.itglue.com/flexible_assets/$ITG_Baseline_ID" -Headers $ITGlue_Headers
$SWSS_Baseline_Settings = $SWSS_Baseline_Settings.data.attributes.traits
$SWSS_Current_Client = Invoke-RestMethod -Method Get -Uri "https://api.itglue.com/flexible_assets/$FlexID" -Headers $ITGlue_Headers
$SWSS_Current_Client_Settings = $SWSS_Current_Client.data.attributes.traits

$Current_Flex_Uri = $SWSS_Current_Client.data.attributes.'resource-url'
$Current_Org_Name = $SWSS_Current_Client.data.attributes.'organization-name'
$Current_Ext_IP = $SWSS_Current_client.data.attributes.traits.'external-ip'
$SW_SerialNumber = $SWSS_Current_Client.data.attributes.traits.'sonicwall-serial-number'
$SW_Tagged_Config_URL = $SWSS_Current_Client.data.attributes.traits.sonicwall.values.'resource-url'
$SW_Tagged_Config_Name = $SWSS_Current_Client.data.attributes.traits.sonicwall.values.name

$Differences = Compare-ObjectProperties -ReferenceObject $SWSS_Baseline_Settings -DifferenceObject $SWSS_Current_Client_Settings


# Excludes all properties from the object that we don't want the difference of, could be modified to pull only the settings we want.
$SS_Dif = $Differences | Where-Object {
    $_.SettingName -ne 'sonicwall' -and
    $_.SettingName -ne 'sonicwall-model' -and 
    $_.SettingName -ne 'sonicwall-serial-number' -and 
    $_.SettingName -ne 'allowed-countries' -and 
    $_.SettingName -ne 'blocked-countries' -and 
    $_.SettingName -ne 'last-modified-date' -and 
    $_.SettingName -ne 'sonicwall-firmware-version' -and 
    $_.SettingName -ne 'up-time' -and 
    $_.SettingName -ne 'external-ip' -and
    $_.SettingName -ne 'log-low-danger-spyware' -and
    $_.SettingName -ne 'log-medium-danger-spyware' -and
    $_.SettingName -ne 'log-high-danger-spyware' -and
    $_.SettingName -ne 'log-high-priority-attacks' -and
    $_.SettingName -ne 'log-medium-priority-attacks' -and
    $_.SettingName -ne 'log-low-priority-attacks'
}

# Only Include Settings with Enabled in it, Calling Primary as it will not include sub settings for each security service.
$SS_Dif2 = $Differences | Where-Object {$_.SettingName -like "*Enabled*"}

# Pirmary Settings, onlly major security services were compared
$SS_Dif_List_Primary_Settings = ($SS_Dif2|fl|Out-String).Trim()
# All settings excluding the obvious ones that are always going to be different, such as model and serial number.
$SS_Dif_List_All_Settings = ($SS_dif|fl|Out-String).Trim()

#############################################################################################################################################
# Checking the length of the differences returned, 0 means no setting were found outside of SOP, which means we don't need to report on it.

if (
    $SS_Dif_List_All_Settings.length -ne 0
) {

#############################################################################################################################################
# Checking to see if there is an open ticket for this Sonicwall already. If there is then we'll update that ticket instead of making a new one.
# Building the API requests to ConnectWise Manage
$CWM_Ticket_Search_URI = "$CWM_API_Base_URI" + "/service/tickets/search"

# Building the json request body to search for ticket
$CWM_Ticket_Search_Body = New-Object PSObject -Property @{
    conditions = "summary = '$SW_SerialNumber - Sonicwall Settings not to SOP' and ClosedFlag = False"
}

# Building API api call to actually search for the ticket
$CWM_Ticket_Search_Response = Invoke-RestMethod -Method Post -Uri $CWM_Ticket_Search_URI -Body (ConvertTo-Json -InputObject $CWM_Ticket_Search_Body -Depth 100) -Headers $CWM_Headers -ContentType "application/json"
$CWM_Ticket_Search_Response
#############################################################################################################################################
# Building variables to use in the ConnectWise Manage Ticket
$SW_MGMT_IP = $Current_Ext_IP + ":" + "$SW_MGMT_Port"
$Last_Mod_Date = $SWSS_Current_Client.data.attributes.traits.'last-modified-date'
$SW_Model = $SWSS_Current_Client.data.attributes.traits.'sonicwall-model'
$SW_UpTime = $SWSS_Current_Client.data.attributes.traits.'up-time'

# Running If condition to see if any tickets were returned
if (
    $CWM_Ticket_Search_Response.count -eq 0
    ) {
    # No open tickets were found, Going to make a new one.
#############################################################################################################################################
    # POST to ConnectWise Manage to Make new ticket.
    $CWM_New_Ticket_URI = "$CWM_API_Base_URI" + "/service/tickets"

    # Building New Ticket Object, will be converted to JSON
    $NewTicketData = New-Object PSObject -Property @{
        summary = "$SW_SerialNumber - Sonicwall Settings not to SOP"
        company = [ordered]@{
            identifier = "$CWM_Company_Identifier"
        }
        board = [ordered]@{
            name = "$CWM_Service_Board_Name"
        }
        priority = [ordered]@{
            id = 18
        }
        initialDescription = "
$SW_Tagged_Config_Name at the IP $Current_Ext_IP is not to SOP
Below are the settings to review and resolve:

----------------------------------------------------

$SS_Dif_List_All_Settings

----------------------------------------------------

LEGEND
SettingName - Name of the Security service setting or sub setting that is flagged as non-sop
SOPSetting - The setting that the security service SHOULD be
SonicwallSetting - The reported sonicwall setting

----------------------------------------------------

Notify NOC if reports are incorrect or if an exception needs to be made for $CompanyName
Entech's Sonicwall SOP: $ITG_SW_SOP_URL
ITGlue Asset = $Current_Flex_Uri

-------SonicWALL Info-------

Serial Number: $SW_SerialNumber
External IP: $Current_Ext_IP
SW External Access: https://$SW_MGMT_IP
Last Modified Date: $Last_Mod_Date
SonicWALL Up Time: $SW_UpTime
SonicWALL ITGlue Config: $SW_Tagged_Config_URL
"
    }
    $NewTicketData|Write-Output

    $OutPut = Invoke-RestMethod -Method Post -Uri $CWM_New_Ticket_URI -Headers $CWM_headers -ContentType 'application/json' -Body (ConvertTo-Json -InputObject $NewTicketData -Depth 100)

    $OutPut
    Remove-variable -Name NewTicketData,output,SWSS_Current_Client
} else {
$Date = Get-Date
$Date = [System.TimeZoneInfo]::ConvertTimeBySystemTimeZoneId($Date, [System.TimeZoneInfo]::Local.Id, 'Eastern Standard Time')

    "There is a ticket! Update it!"
    Foreach ($ticket in $CWM_Ticket_Search_Response) {
#############################################################################################################################################
        $CWM_Ticket_ID = $ticket.id
        # POST to ConnectWise Manage to Update open ticket/s.
        $CWM_Update_Ticket_URI = "$CWM_API_Base_URI" + "/service/tickets/$CWM_Ticket_ID/notes"

# Building ticket update objecct, will be converted to JSON
$UpdateTicketData = New-Object PSObject -Property @{
    detailDescriptionFlag = $false
	internalFlag = $true
	customerUpdatedFlag = $false
	internalAnalysisFlag = $true
	resolutionFlag = $false
    text = "
Ticket Updated:
$Date

----------------------------------------------------

$SW_Tagged_Config_Name at the IP $Current_Ext_IP is not to SOP
Below are the settings to review and resolve:

----------------------------------------------------

$SS_Dif_List_All_Settings

----------------------------------------------------

LEGEND
SettingName - Name of the Security service setting or sub setting that is flagged as non-sop
SOPSetting - The setting that the security service SHOULD be
SonicwallSetting - The reported sonicwall setting

----------------------------------------------------

Notify NOC if reports are incorrect or if an exception needs to be made for $CompanyName
Entech's Sonicwall SOP: $ITG_SW_SOP_URL
ITGlue Asset = $Current_Flex_Uri

-------SonicWALL Info-------

Serial Number: $SW_SerialNumber
External IP: $Current_Ext_IP
SW External Access: https://$SW_MGMT_IP
Last Modified Date: $Last_Mod_Date
SonicWALL Up Time: $SW_UpTime
SonicWALL ITGlue Config: $SW_Tagged_Config_URL
"
}

        $OutPut = Invoke-RestMethod -Method Post -Uri $CWM_Update_Ticket_URI -Headers $CWM_headers -ContentType 'application/json' -Body (ConvertTo-Json -InputObject $UpdateTicketData -Depth 100)

        $OutPut
        Remove-variable -Name UpdateTicketData,output,SWSS_Current_Client
    }
}
} else {
    "Sonicwall To SOP No Ticket Created" | Write-Output
}