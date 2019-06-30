# Building the accepted Paramaters
# Parameter help description
Param(
    [string]$IP,
    [int32]$ITGClientID,
    [string]$Client_Name,
    [string]$Client_Location_Name
    )
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
$Az_ITG_PW_API_KEY_Name = "Api-Key-Name-Password-Access"
$ITG_API_KEY = (Get-AzureKeyVaultSecret -VaultName EntechInternalKeyVault -Name "$Az_ITG_PW_API_KEY_Name").SecretValueText
#############################################################################################################################################
# Building ITGlue Headers
$ITGlue_Headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"   
$ITGlue_Headers.Add("Content-Type", 'application/vnd.api+json')
$ITGlue_Headers.Add('x-api-key', $ITG_API_Key)

#############################################################################################################################################
# Setting Azure Runbook Variables
$Az_SW_Data_Collection_Runbook = "Collect_Sonicwall_Data" # Running "Security Services - CompareSettings.ps1"
$Az_Resource_Group = "Azure_Resource_Group"
$Az_Automation_Account = "Azure_Automation_Account_Name"
$Az_Hybrid_Worker = "On_Prem_Group"

#############################################################################################################################################
# Setting Static IDs for the Sonicwall Password and Flexible asset type IDs for Security Services and others.
$ITG_PW_ID = "112211"
$ITG_FLEX_TYPE_ID_SS = "112233"
$ITG_FLEX_TYPE_ID_AO = "112244"
$ITG_FLEX_TYPE_ID_AG = "112255"
$ITG_FLEX_TYPE_ID_SO = "112266"
$ITG_FLEX_TYPE_ID_SG = "112277"
$ITG_FLEX_TYPE_ID_AR = "112288"
$ITG_Flex_URI = "https://api.itglue.com/flexible_assets/"

#############################################################################################################################################
# Pulling Password for this sonicwall/client from ITGlue
# First step is to list all the Passwords that match the sonicwall admin portal
$ITG_Client_ID = "$ITGClientID"

# Need to change to Invoke-RestMethod instead of ITGlue API Command
$ITG_API_Request_PWs = "https://api.itglue.com/passwords?organization_id=$ITG_Client_ID&filter[password_category_id]=$ITG_PW_ID"
$ITG_Client_PWs = Invoke-RestMethod -Method GET -Uri $ITG_API_Request_PWs -Headers $ITGlue_Headers
Start-sleep -Seconds 2
$ITG_Client_SW_PWid = ([System.Uri]($ITG_Client_PWs.data.attributes|Select-Object -First 1)."resource-url").segments|Select-Object -Last 1

# Now we'll query the password directly to get the username and password
$ITG_API_Request_SW_PW = "https://api.itglue.com/organizations/$ITG_Client_ID/relationships/passwords/$ITG_Client_SW_PWid"

$ITG_SW_Creds = Invoke-RestMethod -Method GET -Uri $ITG_API_Request_SW_PW -Headers $ITGlue_Headers
Start-Sleep -Seconds 2
$Username = $ITG_SW_Creds.data.attributes.username
$Password = $ITG_SW_Creds.data.attributes.password

# Generating Basic Auth Format
$credPair = "$($username):$($password)"
$encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))

#############################################################################################################################################
# Checking to see if username and password exists, if empty will report that.
if ($Username -eq $null) {
    Write-Error "No Sonicwall Credentials Found for Client"
    } else {

#############################################################################################################################################
# Starting 2nd Runbook to Collect Data, connects to on prem, Hybrid Worker Server since sonicwalls are only allowed to talk to our IP Addresses.
# Parameters passed to the Runbook,IP ITGLue Client,the encoded Sonicwall Credentials, Client Name and Location Name.
$SW_DATA_Collect_Param = @{"IP"="$IP";"ITGClientID"="$ITGClientID";"encodedCredentials"="$encodedCredentials";"Client_Name"="$Client_Name";"Client_Location_Name"="$Client_Location_Name"}

$SW_DATA = Start-AzureRmAutomationRunbook -Wait -Parameters $SW_DATA_Collect_Param -Name "$Az_SW_Data_Collection_Runbook" -ResourceGroupName "$Az_Resource_Group" -RunOn "$Az_Hybrid_Worker" -MaxWaitSeconds 1000 -AutomationAccountName "$Az_Automation_Account"

#############################################################################################################################################
# If the Runbook returns Failed to Connect to Sonicwall, we need to report on that.
if ($SW_DATA -eq "Failed to Connect to Sonicwall") {
    Write-Error -Message 'Failed to Connect to Sonicwall, Please check the following:
    SonicWall API is enabled and Basic Auth is allowed
    Sonicwall Password is correct for client, ensure the password in ITGlue is the same for all Sonicwall they have
    Sonicwall is on version 6.5.3 or higher.'
    
} else {

########################################################################################################################################
# First separate each flexible asset into its own section to be checked
# This is building out for future versions also, currently Address Objects and Security Services are syncing with ITGlue only.

# Address Objects use Flexible Asset ID 124964
$SW_Address_Objects = $SW_DATA|Where-Object {$_.data.attributes.'flexible-asset-type-id' -eq $ITG_FLEX_TYPE_ID_AO}

# Address Groups use Flexible Asset ID 124966
$SW_Address_Groups = $SW_DATA|Where-Object {$_.data.attributes.'flexible-asset-type-id' -eq $ITG_FLEX_TYPE_ID_AG}

# Service Objects use Flexible Asset ID 124967
$SW_Service_Objects = $SW_DATA|Where-Object {$_.data.attributes.'flexible-asset-type-id' -eq $ITG_FLEX_TYPE_ID_SO}

# Service Groups use Flexible Asset ID 124968
$SW_Service_Groups = $SW_DATA|Where-Object {$_.data.attributes.'flexible-asset-type-id' -eq $ITG_FLEX_TYPE_ID_SG}

# Access Rules use Flexible Asset ID 124962
$SW_Access_Rules = $SW_DATA|Where-Object {$_.data.attributes.'flexible-asset-type-id' -eq $ITG_FLEX_TYPE_ID_AR}

# Security Services use Flexible Asset ID 117956
$SW_Security_Services = $SW_DATA|Where-Object {$_.data.attributes.'flexible-asset-type-id' -eq $ITG_FLEX_TYPE_ID_SS}

#############################################################################################################################################

# Next step is to find the flexible asset we need to update or create for this sonicwall
# Finding all the flexible assets for specific client, filtering using the flex type id

$ITG_API_Client_Flex = "https://api.itglue.com/flexible_assets/?filter[organization_id]=$ITG_Client_ID&filter[flexible_asset_type_id]=$ITG_FLEX_TYPE_ID_SS"

$ITG_Client_SWSS_Assets = Invoke-RestMethod -Method Get -Uri $ITG_API_Client_Flex -Headers $ITGlue_Headers
# Parsing the output and finding the one that matches the firewall that we just queried
Start-Sleep -Seconds 2
$SW_SerialNumber = $SW_Security_Services.data.attributes.traits."sonicwall-serial-number"
[string]$SW_SerialNumber = $SW_SerialNumber.trim()

# Search ITGlue configs for the sonicwall
# Setting search URI for sonicwall config, based on the client ITG ID Sonicwall
# Setting URI First
$ITG_Config_Search_URI = "https://api.itglue.com/configurations/?filter[organization_id]=$ITG_Client_ID&page[size]=1&filter[serial_number]=$SW_SerialNumber&filter[configuration_status_name]=Active&include=related_items,adapters_resources"

# Putting the Results inside of a variable
$ITG_Config_Search_Results = Invoke-RestMethod -Method Get -Uri $ITG_Config_Search_URI -Headers $ITGlue_Headers
Start-Sleep -Seconds 2
$ITG_ID_of_Sonicwall_Config = $ITG_Config_Search_Results.data.id
# Check to see if Sonicwall Found Matches the Serial Number searched with.
$ITG_Found_SW_Serial_Number = $ITG_Config_Search_Results.data.attributes.'serial-number'

if ($ITG_Found_SW_Serial_Number -eq $SW_SerialNumber) {

$ITG_Client_SWSS_Assets.data.attributes|Select-Object resource-url -ExpandProperty traits|ForEach-Object {
    $Temp_ITG_FLEX_SW_SN = $_."sonicwall-serial-number"
    [string]$Temp_ITG_FLEX_SW_SN = $Temp_ITG_FLEX_SW_SN.trim()
    $Temp_ITG_FLEX_ID = (([System.Uri]($_)."resource-url").segments|Select-Object -Last 1)
    if ($Temp_ITG_FLEX_SW_SN -eq $SW_SerialNumber) {
        $ITG_Flex_ID = $Temp_ITG_FLEX_ID
    }
    # Temp Text Outputs for troubleshooting
    "Found SS Flex ID $ITG_Flex_ID"
    "Temp ITG Flex Sonicwall Serial Number $Temp_ITG_FLEX_SW_SN"
    "Temp ITG Flex Id Found $Temp_ITG_FLEX_ID"
}
# Update returned Sonicwall Security Services Data with the sonicwall config found in ITGlue to tag.
$SW_Security_Services.data.attributes.traits.sonicwall = $ITG_ID_of_Sonicwall_Config

if ($ITG_Flex_ID -eq $null) {
    # The if statement found that flexible asset was null so couldn't find an existing flexible asset with this info for this company
    # This means we will need to create the flexible Asset as this is probably the initial config.
    $jsondata = $SW_Security_Services|ConvertTo-Json -Depth 100 | ForEach-Object { [System.Text.RegularExpressions.Regex]::Unescape($_) }
  
    # Performing the actual update, Later add a try statement and error handling so we can report on issues updating the information.
    $ITG_Flex_Update_Results = Invoke-RestMethod -Method Post -Uri $ITG_Flex_URI -Headers $ITGlue_Headers -Body $jsondata -ContentType "application/vnd.api+json; charset=utf-8"
    Start-Sleep -Seconds 2
} else {
    # We Found a Flexible Asset that matches the sonicwall we just queried. So now we will update the information in ITGlue.
    
    # Converting the $Data variable to json format to put in the body of the Flexible Asset
    $jsondata = $SW_Security_Services|ConvertTo-Json -Depth 100 | ForEach-Object { [System.Text.RegularExpressions.Regex]::Unescape($_) }

    $ITG_Flex_SS_URI = ("$ITG_Flex_URI" + "$ITG_Flex_ID")
    
    # Performing the actual update, Later add a try statement and error handling so we can report on issues updating the information.
    $ITG_Flex_Update_Results = Invoke-RestMethod -Method Patch -Uri $ITG_Flex_SS_URI -Headers $ITGlue_Headers -Body $jsondata -ContentType "application/vnd.api+json; charset=utf-8"
    Start-Sleep -Seconds 2
}
Remove-Variable ITG_Client_SWSS_Assets
$ITG_Flex_Update_Results
#############################################################################################################################################
# Running If statement to see if we returned a sonicwall.
if ($ITG_Config_Search_Results.data.attributes -eq $null) {
    # No sonicwall Found
    "No Sonicwall Found to tag"
} else {
    # Found an active sonicwall that matches the Serial Number
#############################################################################################################################################
# Going to Start with Address Objects, Create/Update those.
# Setting Variables to Search with
$ITG_AO_Flex_Name = "SonicWALL Address Objects"
# URI to search for all Sonicwall Address Objects for specific client, will use this info to compare the UUID and match Flexible assets up.
$ITG_All_AO_Flex_URI = "https://api.itglue.com/flexible_assets/?filter[organization-id]=$ITG_Client_ID&filter[flexible-asset-type-id]=$ITG_FLEX_TYPE_ID_AO&page[size]=1000"

# Performing the Address Object search for specific client
$ITG_All_AO_Flex_Search_Results = Invoke-RestMethod -Method Get -Headers $ITGlue_Headers -Uri $ITG_All_AO_Flex_URI
Start-Sleep -Seconds 1
# Starting Loop to process the returned Address Objects
    foreach ($AddressObject in $SW_Address_Objects) {
    # First need to add the ID of the found Sonicwall to update the tag info for each Object
    $AddressObject.data.attributes.traits.sonicwall = $ITG_ID_of_Sonicwall_Config

    # Put UUID of Address Object into Variable to search based off of.
    [string]$Cur_AO_UUID = ($AddressObject.data.attributes.traits.uuid).trim()

    # Searching to see if there is an address object already, based on the UUID and attached to the sonicwall found
    $Cur_AO_Search = $ITG_All_AO_Flex_Search_Results.data | Where-Object {$_.attributes.traits.uuid -eq "$Cur_AO_UUID" -and $_.attributes.traits.sonicwall.values.id -eq $ITG_ID_of_Sonicwall_Config}

    # Searching to see if there is an address object already, based on Name and attached to sonicwall
    $Cur_AO_Name = $AddressObject.data.attributes.traits.'address-object-name'
    

    If ($Cur_AO_Search -eq $null) {
        # Create New Config for Address Object
        "Creating New Config for $Cur_AO_Name with UUID of $Cur_AO_UUID"
        Invoke-RestMethod -Method Post -Uri $ITG_Flex_URI -Headers $ITGlue_Headers -ContentType "application/vnd.api+json; charset=utf-8" -Body ($AddressObject|ConvertTo-Json -Depth 100 | ForEach-Object { [System.Text.RegularExpressions.Regex]::Unescape($_) })
        Start-Sleep -Seconds 1

    } else {
        # Update Existing
        "Cur_AO_Search:"
        $Cur_AO_Search | ConvertTo-Json -Depth 100
        [int32]$Cur_AO_ITG_ID = ($Cur_AO_Search.id).trim()
        "Cur_AO_ITG_ID:"
        $Cur_AO_ITG_ID
        "ITG_Flex_URI:"
        $ITG_Flex_URI
        "Combined URI:"
        ($ITG_Flex_URI + $Cur_AO_ITG_ID)
        "Updating Existing Config for $Cur_AO_Name with UUID of $Cur_AO_UUID and ITGlue ID of $Cur_AO_ITG_ID"
        Invoke-RestMethod -Method Patch -Uri ($ITG_Flex_URI + $Cur_AO_ITG_ID) -headers $ITGlue_Headers -ContentType "application/vnd.api+json; charset=utf-8" -Body ($AddressObject|ConvertTo-Json -Depth 100 | ForEach-Object { [System.Text.RegularExpressions.Regex]::Unescape($_) })
        Start-Sleep -Seconds 1
        Remove-Variable Cur_AO_ITG_ID
    }
    Remove-Variable Cur_AO_Name,Cur_AO_Search,Cur_AO_UUID
    
    }

############################################################################################################################################
# This section will be for address groups

}
} else {
    Write-Error "Reported Serial Number ($SW_SerialNumber) doesn't match the found sonicwall ($ITG_Found_SW_Serial_Number). Will not update or create Flexible Assets."
}
}
}