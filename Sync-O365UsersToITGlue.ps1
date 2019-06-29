<# 
.SYNOPSIS
Sync Office 365 users to IT Glue

.LINK
https://github.com/itglue/powershellwrapper

.NOTES
ITGlueAPI module should be download from above Github link into: C:\Program Files\WindowsPowerShell\Modules

This script assumes the below pre-requisites:
    - IT Glue PowerShell Wrapper is already installed
    - IT Glue API Key has already been created
    - IT Glue organisations that you want to sync to Office 365 tenant information to, have their Azure AD Tenant ID already listed within 
        the IT Glue Organisation DESCRIPTION field in the format of: AADTenantID:<Azure AD Tenant ID>, for example for the contoso.com tenant:
        AADTenantID:6babcaad-604b-40ac-a9d7-9fd97c0b779f
    - A CSV export of Office 365 tenant data for ALL CSP customers has already been generated and available to be queried, and should contain the following headers:
        DisplayName
        Title
        UserPrincipalName
        FirstName
        LastName
        BlockCredential
        approver
        IsAdmin)
        AdminRoles
        IsLicensed)
        LastDirSyncTime
        LastPasswordChangeTimestamp
        Licenses
        ProxyAddresses
        MFAEnabled
        AzureMFA)
        TotalItemSize
        ItemCount
        ArchiveStatus
        LitigationHoldEnabled)
        LitigationHoldDuration
        RetainDeletedItemsFor
        AuditEnabled)
        AuditLogAgeLimit
        ForwardingAddress
        ForwardingSmtpAddress
        O365ActiveUserReportRefreshDate
        LastActivityDate

#>

[cmdletbinding()]
Param()

function Remove-StringDiacritic
{
<#
.SYNOPSIS
	This function will remove the diacritics (accents) characters from a string.
	
.DESCRIPTION
	This function will remove the diacritics (accents) characters from a string.

.PARAMETER String
	Specifies the String(s) on which the diacritics need to be removed

.PARAMETER NormalizationForm
	Specifies the normalization form to use
	https://msdn.microsoft.com/en-us/library/system.text.normalizationform(v=vs.110).aspx

.EXAMPLE
	PS C:\> Remove-StringDiacritic "L'été de Raphaël"
	
	L'ete de Raphael

.NOTES
	Francois-Xavier Cat
	@lazywinadm
	www.lazywinadmin.com
    github.com/lazywinadmin
    
.LINK
https://github.com/lazywinadmin/PowerShell/blob/master/TOOL-Remove-StringDiacritic/Remove-StringDiacritic.ps1
https://lazywinadmin.com/2015/05/powershell-remove-diacritics-accents.html

#>
	[CMdletBinding()]
	PARAM
	(
		[ValidateNotNullOrEmpty()]
		[Alias('Text')]
		[System.String[]]$String,
		[System.Text.NormalizationForm]$NormalizationForm = "FormD"
	)
	
	FOREACH ($StringValue in $String)
	{
		Write-Verbose -Message "$StringValue"
		try
		{	
			# Normalize the String
			$Normalized = $StringValue.Normalize($NormalizationForm)
			$NewString = New-Object -TypeName System.Text.StringBuilder
			
			# Convert the String to CharArray
			$normalized.ToCharArray() |
			ForEach-Object -Process {
				if ([Globalization.CharUnicodeInfo]::GetUnicodeCategory($psitem) -ne [Globalization.UnicodeCategory]::NonSpacingMark)
				{
					[void]$NewString.Append($psitem)
				}
			}

			#Combine the new string chars
			Write-Output $($NewString -as [string])
		}
		Catch
		{
			Write-Error -Message $Error[0].Exception.Message
		}
	}
}

# List of Office 365 subscription SKUs
$LicenseSkuDefinitions = @(
    "AAD_BASIC|Azure Active Directory Basic"
    "AAD_PREMIUM|Azure Active Directory Premium P1"
    "AAD_PREMIUM_P2|Azure Active Directory Premium P2"
    "ATA|Advanced Threat Analytics"
    "ATP_ENTERPRISE|Exchange Online Advanced Threat Protection"
    "BI_AZURE_P1|Power BI Reporting and Analytics"
    "CRMIUR|CMRIUR"
    "CRMPLAN2|Microsoft Dynamics CRM Online Basic"
    "CRMSTANDARD|Microsoft Dynamics CRM Online Professional"
    "CRMSTORAGE|Microsoft Dynamics CRM Online Additional Storage"
    "CRMTESTINSTANCE|Microsoft Dynamics CRM Online Additional Non-Production Instance"
    "DESKLESSPACK_GOV|OFFICE 365 F1 for Government"
    "DESKLESSPACK|OFFICE 365 F1"
    "DESKLESSWOFFPACK|Office 365 (Plan K2)"
    "DEVELOPERPACK|Office 365 Enterprise E3 Developer"
    "DYN365_ENTERPRISE_P1_IW|Dynamics 365 P1 Trial for Information Workers"
    "DYN365_ENTERPRISE_PLAN1|Dynamics 365 Customer Engagement Plan Enterprise Edition"
    "DYN365_ENTERPRISE_SALES|Dynamics Office 365 Enterprise Sales"
    "DYN365_ENTERPRISE_TEAM_MEMBERS|Dynamics 365 For Team Members Enterprise Edition"
    "DYN365_FINANCIALS_BUSINESS_SKU|Dynamics 365 for Financials Business Edition"
    "DYN365_FINANCIALS_TEAM_MEMBERS_SKU|Dynamics 365 for Team Members Business Edition"
    "Dynamics_365_Hiring_SKU|Dynamics 365 for Talent: Attract"
    "ECAL_SERVICES|ECAL"
    "EMS|Enterprise Mobility + Security E3"
    "EMSPREMIUM|Enterprise Mobility + Security E5"
    "ENTERPRISEPACK_B_PILOT|Office 365 (Enterprise Preview)"
    "ENTERPRISEPACK_FACULTY|Office 365 Plan A3 for Faculty"
    "ENTERPRISEPACK_GOV|Microsoft Office 365 Plan G3 for Government"
    "ENTERPRISEPACK_STUDENT|Office 365 Plan A3 for Students"
    "ENTERPRISEPACK|Enterprise E3"
    "ENTERPRISEPACKLRG|Enterprise E3"
    "ENTERPRISEPREMIUM_NOPSTNCONF|Enterprise E5 (without Audio Conferencing)"
    "ENTERPRISEPREMIUM|Enterprise E5"
    "ENTERPRISEWITHSCAL_FACULTY|Office 365 Plan A4 for Faculty"
    "ENTERPRISEWITHSCAL_GOV|Microsoft Office 365 Plan G4 for Government"
    "ENTERPRISEWITHSCAL_STUDENT|Office 365 Plan A4 for Students"
    "ENTERPRISEWITHSCAL|Enterprise Plan E4"
    "EOP_ENTERPRISE_FACULTY|Exchange Online Protection for Faculty"
    "EQUIVIO_ANALYTICS|Office 365 Advanced eDiscovery"
    "ESKLESSWOFFPACK_GOV|Microsoft Office 365 Plan K2 for Government"
    "EXCHANGE_L_STANDARD|Exchange Online Plan 1"
    "EXCHANGE_S_ARCHIVE_ADDON_GOV|Exchange Online Archiving"
    "EXCHANGE_S_DESKLESS_GOV|Exchange Kiosk"
    "EXCHANGE_S_DESKLESS|Exchange Online Kiosk"
    "EXCHANGE_S_ENTERPRISE_GOV|Exchange Plan 2G"
    "EXCHANGE_S_ESSENTIALS|Exchange Online Essentials"
    "EXCHANGE_S_STANDARD_MIDMARKET|Exchange Online Plan 1"
    "EXCHANGEARCHIVE_ADDON|Exchange Online Archiving For Exchange Online"
    "EXCHANGEARCHIVE|Exchange Online Archiving For Exchange Server"
    "EXCHANGEDESKLESS|Exchange Online Kiosk"
    "EXCHANGEENTERPRISE_GOV|Microsoft Office 365 Exchange Online Plan 2 only for Government"
    "EXCHANGEENTERPRISE|Exchange Online Plan 2"
    "EXCHANGEESSENTIALS|Exchange Online Essentials"
    "EXCHANGESTANDARD_GOV|Microsoft Office 365 Exchange Online Plan 1 only for Government"
    "EXCHANGESTANDARD_STUDENT|Exchange Online Plan 1 for Students"
    "EXCHANGESTANDARD|Exchange Online Plan 1"
    "FLOW_FREE|Microsoft Flow Free"
    "FLOW_P1|Microsoft Flow Plan 1"
    "FLOW_P2|Microsoft Flow Plan 2"
    "INTUNE_A|Windows Intune Plan A"
    "IT_ACADEMY_AD|Ms Imagine Academy"
    "LITEPACK_P2|Office 365 Small Business Premium"
    "LITEPACK|Office 365 (Plan P1)"
    "MCOEV|Microsoft Phone System"
    "MCOIMP|Skype For Business Online Plan 1"
    "MCOLITE|Lync Online Plan 1"
    "MCOMEETADV|PSTN conferencing"
    "MCOPSTN1|Skype For Business Pstn Domestic Calling"
    "MCOPSTN2|Domestic and International Calling Plan"
    "MCOSTANDARD_GOV|Lync Plan 2G"
    "MCOSTANDARD_MIDMARKET|Lync Online Plan 1"
    "MCOSTANDARD|Skype for Business Online Standalone Plan 2"
    "MFA_PREMIUM|Azure Multi-Factor Authentication"
    "MFA_STANDALONE|Microsoft Azure Multi-Factor Authentication Premium Standalone"
    "MIDSIZEPACK|Office 365 Midsize Business"
    "O365_BUSINESS_ESSENTIALS|Office 365 Business Essentials"
    "O365_BUSINESS_PREMIUM|Office 365 Business Premium"
    "O365_BUSINESS|Office 365 Business"
    "OFFICE_PRO_PLUS_SUBSCRIPTION_SMBIZ|Office ProPlus"
    "OFFICESUBSCRIPTION_FACULTY|Office 365 ProPlus for faculty"
    "OFFICESUBSCRIPTION_GOV|Office ProPlus"
    "OFFICESUBSCRIPTION_STUDENT|Office ProPlus Student Benefit"
    "OFFICESUBSCRIPTION|Office ProPlus"
    "PLANNERSTANDALONE|Planner Standalone"
    "POWER_BI_ADDON|Office 365 Power BI Addon"
    "POWER_BI_INDIVIDUAL_USE|Power BI Individual User"
    "POWER_BI_PRO|Power BI Pro"
    "POWER_BI_STANDALONE_FACULTY|Power BI for Office 365 for faculty"
    "POWER_BI_STANDALONE|Power BI Stand Alone"
    "POWER_BI_STANDARD|Power-BI Standard"
    "POWERAPPS_VIRAL|Microsoft Power Apps & Flow"
    "POWERFLOW_P1|Microsoft PowerApps Plan 1"
    "POWERFLOW_P2|Microsoft PowerApps Plan 2"
    "PROJECT_MADEIRA_PREVIEW_IW_SKU|Dynamics 365 for Financials for IWs"
    "PROJECTCLIENT|Project Professional"
    "PROJECTESSENTIALS|Project Lite"
    "PROJECTONLINE_PLAN_1|Project Online"
    "PROJECTONLINE_PLAN_2|Project Online and PRO"
    "ProjectPremium|Project Online Premium"
    "PROJECTPROFESSIONAL|Project Professional"
    "PROJECTWORKMANAGEMENT|Office 365 Planner Preview"
    "RIGHTSMANAGEMENT_ADHOC|Windows Azure Rights Management"
    "RIGHTSMANAGEMENT|Rights Management"
    "RMS_S_ENTERPRISE_GOV|Windows Azure Active Directory Rights Management"
    "RMS_S_ENTERPRISE|Azure Active Directory Rights Management"
    "SHAREPOINTDESKLESS_GOV|SharePoint Online Kiosk"
    "SHAREPOINTDESKLESS|SharePoint Online Kiosk"
    "SHAREPOINTENTERPRISE_GOV|SharePoint Plan 2G"
    "SHAREPOINTENTERPRISE_MIDMARKET|SharePoint Online Plan 1"
    "SHAREPOINTENTERPRISE|Sharepoint Online Plan 2"
    "SHAREPOINTLITE|SharePoint Online Plan 1"
    "SHAREPOINTSTANDARD|Sharepoint Online Plan 1"
    "SHAREPOINTSTORAGE_FACULTY|Office 365 Extra File Storage for faculty"
    "SHAREPOINTSTORAGE|SharePoint storage"
    "SHAREPOINTWAC_GOV|Office Online for Government"
    "SHAREPOINTWAC|Office Online"
    "SMB_BUSINESS_ESSENTIALS|Office 365 Business Essentials"
    "SMB_BUSINESS_PREMIUM|Office 365 Business Premium"
    "SMB_BUSINESS|Office 365 Business"
    "SPE_E3|Microsoft 365 E3"
    "SPE_E5|Microsoft 365 E5"
    "SPE_F1|Microsoft 365 F1"
    "SPZA_IW|App Connect"
    "STANDARD_B_PILOT|Office 365 (Small Business Preview)"
    "STANDARDPACK_FACULTY|Office 365 Plan A1 for Faculty"
    "STANDARDPACK_GOV|Microsoft Office 365 Plan G1 for Government"
    "STANDARDPACK_STUDENT|Office 365 Plan A1 for Students"
    "STANDARDPACK|Enterprise E1"
    "STANDARDWOFFPACK_FACULTY|Office 365 Education E1 for Faculty"
    "STANDARDWOFFPACK_GOV|Microsoft Office 365 Plan G2 for Government"
    "STANDARDWOFFPACK_IW_FACULTY|Office 365 Education for Faculty"
    "STANDARDWOFFPACK_IW_STUDENT|Office 365 Education for Students"
    "STANDARDWOFFPACK_STUDENT|Microsoft Office 365 Plan A2 for Students"
    "STANDARDWOFFPACK|Office 365 Plan E2"
    "STANDARDWOFFPACKPACK_FACULTY|Office 365 Plan A2 for Faculty"
    "STANDARDWOFFPACKPACK_STUDENT|Office 365 Plan A2 for Students"
    "STREAM|Microsoft Stream"
    "VIDEO_INTEROP|Polycom Skype Meeting Video Interop for Skype for Business"
    "VISIOCLIENT|Visio Pro Online"
    "VISIOONLINE_PLAN1|Visio Online Plan 1"
    "WACONEDRIVEENTERPRISE|Onedrive For Business Plan 2"
    "WACONEDRIVESTANDARD|Onedrive For Business Plan 1"
    "Win10_E3_Local|Windows 10 Enterprise E3 (local only)"
    "WIN10_PRO_ENT_SUB|Windows 10 Enterprise E3"
    "WINDOWS_STORE|Windows Store for Business"
    "YAMMER_ENTERPRISE|Yammer for the Starship Enterprise"
    "YAMMER_MIDSIZE|Yammer"
    )

Write-Warning "This script assumes the below pre-requisites:
    - IT Glue PowerShell Wrapper is already installed
    - IT Glue API Key has already been created
    - IT Glue organisations that you want to sync to Office 365 tenant information to, have their Azure AD Tenant ID already listed within 
        the IT Glue Organisation DESCRIPTION field in the format of: AADTenantID:<Azure AD Tenant ID>, for example for the contoso.com tenant:
        AADTenantID:6babcaad-604b-40ac-a9d7-9fd97c0b779f
    - A CSV export of Office 365 tenant data for ALL CSP customers has already been generated and available to be queried, and should contain the following headers:
        DisplayName
        Title
        UserPrincipalName
        FirstName
        LastName
        BlockCredential
        approver
        IsAdmin)
        AdminRoles
        IsLicensed)
        LastDirSyncTime
        LastPasswordChangeTimestamp
        Licenses
        ProxyAddresses
        MFAEnabled
        AzureMFA)
        TotalItemSize
        ItemCount
        ArchiveStatus
        LitigationHoldEnabled)
        LitigationHoldDuration
        RetainDeletedItemsFor
        AuditEnabled)
        AuditLogAgeLimit
        ForwardingAddress
        ForwardingSmtpAddress
        O365ActiveUserReportRefreshDate
        LastActivityDate"

pause

$ITGlueAPIKey = Read-Host "Enter your IT Glue API Key"
Add-ITGlueAPIKey -Api_Key $ITGlueAPIKey

#region IT Glue module pre-prequsites
Write-Output "[$(Get-Date)]: Checking for IT Glue PowerShell module"
if((Get-Module | Where-Object {$_.Name -like "ITGlueAPI"}) -eq $null)
{
    Write-Output "[$(Get-Date)]: Importing ITGlueAPI module into current session"
    Import-Module ITGlueAPI
}

if((Get-ITGlueBaseURI) -notlike "https://api.eu.itglue.com")
{
    Write-Output "[$(Get-Date)]: Setting API endpoint to EU region"
    Add-ITGlueBaseURI -base_uri "https://api.eu.itglue.com" # EU Partners
}
    else
    {
        Write-Output "[$(Get-Date)]: IT Glue API Base URL already set to EU region"
    }

#endregion

$ReportFile = Read-Host "Enter path to CSV file containing export of Office 365 User details"
$O365Users = Import-Csv $ReportFile -Encoding UTF8
$FatID = Read-Host "Enter your IT Glue FAT (Flexible Asset ID) for the custom Office 365 User object type"
$ITGlueOrgs = Get-ITGlueOrganizations -page_size 1000 -sort name | Select-Object -ExpandProperty data


# Filter and sort imports
$ITGlueOrgs = $ITGlueOrgs | Where-Object{$_.attributes.description -match "AADTenantID:"}
$O365Users  = $O365Users  | Where-Object{$_.RecipientTypeDetails -like 'UserMailbox' -and $_.IsLicensed -eq $true} # Identify "active" users
$O365Users = $O365Users | Sort-Object displayname

Write-Output "[$(Get-Date)]: Number of Office 365 CSP tenant users that will be processed: $($O365Users.Count)"
# Create header object to pass to the IT Glue API directly, for when the PowerShell Wrapper is NOT being used
$header = @{
    "Content-Type" = "application/vnd.api+json"
    "x-api-key" =  $APIKey
}

# Query the IT Glue API for list of all Office 365 Users (FAT)
$response = Get-ITGlueFlexibleAssets -filter_flexible_asset_type_id $FatID -page_size 1000
# Maximum records that the API returns is 1000, any more and they're paginated, so loop through each page and accumulate
if($response.links.next)
{
    Write-Output "[$(Get-Date)]: Paginated results returned by the API"
    $response_paginated = @{
        links = $response.links
        meta = $response.meta
    }

    Write-Output "[$(Get-Date)]: Processing Paged result $($response_paginated.meta.'current-page') of $($response_paginated.meta.'total-pages')"

    do
    {        
        $response_paginated = Invoke-RestMethod -Method Get -Uri $response_paginated.links.next -Headers $header
        $response.data += $response_paginated.data

        Write-Output "[$(Get-Date)]: Processing Paged result $($response_paginated.meta.'current-page') of $($response_paginated.meta.'total-pages')"
    }
    while($response_paginated.links.next)
}

#region Cleanup non-active Office 365 users from IT Glue
# Remove users on ITG that are not listed in the O365 export

$PendingDeletionCount = 0
$PendingDeletionUser = @()
foreach($ExistingFATO365User in $response.data)
{
    if($O365Users.UserPrincipalName -notcontains $ExistingFATO365User.attributes.traits.upn -eq $true)
    {
        $PendingDeletionUser += $ExistingFATO365User
        $PendingDeletionCount++
    }
}

if($PendingDeletionUser)
{
    Write-Host "[$(Get-Date)]: No. of FAT O365 users that will be deleted: $PendingDeletionCount" -ForegroundColor Yellow
    $PendingDeletionUser | ForEach-Object{
        Write-Output "[$(Get-Date)]: Deleting FAT Office 365 User: $($_.attributes.traits.upn) | ITG ID: $($_.id)"
        Remove-ITGlueFlexibleAssets -id $_.id -Confirm:$false
    }
}
#endregion

$UsersCreatedCount = 0
$UsersUpdatedCount = 0
$u = 1
foreach($O365User in $O365Users)
{
    Write-Output "[$(Get-Date)]: -------Processing O365 user $u of $($O365Users.Count): $($O365User.DisplayName) - $($O365User.UserPrincipalName)"
    $ITGlueAADTenantID = "AADTenantID:$($O365User.TenantID)" # AAD Tenant ID that user belongs to
    $APIResponse = $null

    # Check if user's tenant ID exists in IT Glue
    If($ITGlueOrgs.attributes.description -match $ITGlueAADTenantID)
    {
        Write-Output "[$(Get-Date)]: Matched user to IT Glue Organization: $(($ITGlueOrgs | Where-Object {$_.attributes.description -match $ITGlueAADTenantID}).attributes.name)"
        
        $OrganizationID = $null
        
        foreach($ITGlueOrg in $ITGlueOrgs)
        {
            If($ITGlueOrg.attributes.description -match $ITGlueAADTenantID)
            {
                $OrganizationID = $ITGlueOrg.id
                break
            }
        }

        # Format accented (French) letters so we can pass this as a search query filter on the IT Glue API
        $O365User.DisplayName = Remove-StringDiacritic -String $O365User.DisplayName

        # Search the (IT Glue FAT) array for the current O365 user record in context
        foreach($record in $response.data)
        {
            if($record.attributes.traits.upn -like $O365User.UserPrincipalName)
            {
                $FatO365User = $record
                break
            }
        }

        $FatO365UserID = $FatO365User.id

        $data = @{
            type =  "flexible-assets"
            attributes = @{
                "organization-id" = $OrganizationID
                "flexible-asset-type-id" = $FatID
                "traits" = @{
                    "display-name" = $O365User.DisplayName
                    "title" = $O365User.Title
                    "upn" = $O365User.UserPrincipalName
                    "firstname" = $O365User.FirstName
                    "surname" = $O365User.LastName
                    "account-enabled" = [System.Convert]::ToBoolean($O365User.BlockCredential)
                    "approver" = $FatO365User.attributes.traits.approver # Keep existing value currently in IT Glue
                    "o365-administrator" = [System.Convert]::ToBoolean($O365User.IsAdmin)
                    "o365-administrator-roles" = $O365User.AdminRoles
                    "is-licensed" = [System.Convert]::ToBoolean($O365User.IsLicensed)
                    "last-dirsync-time" = $O365User.LastDirSyncTime
                    "password-last-changed" = $O365User.LastPasswordChangeTimestamp
                    "licenses" = ($O365User.Licenses.Split(",") | Where-Object {$_}) -join "<br/>"
                    "email-addresses" = $O365User.ProxyAddresses
                    "mfa-status" = $O365User.MFAEnabled
                    "azure-mfa" = [System.Convert]::ToBoolean($O365User.AzureMFA)
                    "mailbox-size" = $O365User.TotalItemSize
                    "mailbox-item-count" = $O365User.ItemCount
                    "in-place-archive-status" = $O365User.ArchiveStatus
                    "litigation-hold-enabled" = [System.Convert]::ToBoolean($O365User.LitigationHoldEnabled)
                    "litigation-hold-duration" = $O365User.LitigationHoldDuration
                    "deleted-items-retention-days" = $O365User.RetainDeletedItemsFor
                    "mailbox-audit-enabled" = [System.Convert]::ToBoolean($O365User.AuditEnabled)
                    "mailbox-audit-retention-days" = $O365User.AuditLogAgeLimit
                    "forwarding-internal" = $O365User.ForwardingAddress
                    "forwarding-external" = $O365User.ForwardingSmtpAddress
                    "last-o365-activity-date" = "Activity Report Date: $($O365User.O365ActiveUserReportRefreshDate)<br/>Last Activity Date: $($O365User.LastActivityDate)"
                    "last-it-glue-sync-time" = (Get-Date).ToString()
                }
            }
        }

        #region Additional processing on attributes

        # Correctly set inverse value of Account Enabled status
        if($O365User.BlockCredential -eq $true)
        {
            $data.attributes.traits.'account-enabled' = $false
        }
            else
            {
                $data.attributes.traits.'account-enabled' = $true
            }

        # Truncate litigation hold duration string value to days
        if($O365User.LitigationHoldDuration -notlike "Unlimited" -and $O365User.LitigationHoldDuration -notlike $null)
        {
            $data.attributes.traits.'litigation-hold-duration' = $O365User.LitigationHoldDuration.Split(".")[0]
        }

        # Truncate deleted items retention string value to days
        if($O365User.RetainDeletedItemsFor -ne $null)
        {
            $data.attributes.traits.'deleted-items-retention-days' = $O365User.RetainDeletedItemsFor.Split(":")[0].Split(".")[0]
        }

        # Truncate mailbox audit retention string value to days
        if($O365User.AuditLogAgeLimit -ne $null)
        {
            $data.attributes.traits.'mailbox-audit-retention-days' = $O365User.AuditLogAgeLimit.Split(".")[0]
        }

        # Format list of assigned licenses
        $AssignedSKUs = $null
        $LicenseDisplayName = $null
        $AssignedSKUs = $O365User.Licenses.Split(",") | Where-Object{$_}
        
        # If multiple licenses are assigned
        if((($AssignedSKUs | Measure-Object).Count -gt 1))
        {
            $i = 0
            foreach($AssignedSKU in $AssignedSKUs)
            {
                try
                {
                    $LicenseDisplayName = (($LicenseSkuDefinitions -match $AssignedSKU) | Where-Object {$_ -like "$AssignedSKU|*"}).Split("|")[1]
                }
                    catch
                    {
                        # If SKU doesn't exist in the $LicenseSkuDefinitions array, skip
                        Write-Warning "Unable to find display name for Office 365 license SKU: $AssignedSKU"
                        $i++
                        continue
                    }
                if($LicenseDisplayName)
                {
                    $AssignedSKUs[$i] = $LicenseDisplayName
                }
                $i++
            }

            $data.attributes.traits.licenses = $AssignedSKUs -join "<br/>"
        }
            # Otherwise if only a single license is assigned
            else
            {
                $data.attributes.traits.licenses = (($LicenseSkuDefinitions -match $AssignedSKUs) | Where-Object {$_ -like "$AssignedSKUs|*"}).Split("|")[1]
            }

        # Format list of proxy addresses
        $data.attributes.traits.'email-addresses' = ($data.attributes.traits.'email-addresses'.Split(",") | Where-Object {$_}) -join "<br/>"

        # Format accented (French) letters
        if($data.attributes.traits.'display-name')
        {
            $data.attributes.traits.'display-name' = Remove-StringDiacritic -String $data.attributes.traits.'display-name'
        }
        
        if($data.attributes.traits.firstname)
        {
            $data.attributes.traits.firstname = Remove-StringDiacritic -String $data.attributes.traits.firstname
        }
        
        if($data.attributes.traits.surname)
        {
            $data.attributes.traits.surname = Remove-StringDiacritic -String $data.attributes.traits.surname
        }

        # Format SMTP forwarding details
        if(!$O365User.ForwardingAddress)
        {
            $data.attributes.traits.'forwarding-internal' = "N/A"
        }

        if(!($O365User.ForwardingSmtpAddress))
        {
            $data.attributes.traits.'forwarding-external' = "N/A"
        }       
        
        #endregion
        
        # Check if user already exists in IT Glue
        if($FatO365User)
        {
            Write-Output "[$(Get-Date)]: Found existing user in IT Glue with ID: $FatO365UserID"
            Write-Output "[$(Get-Date)]: Updating existing IT Glue user"
            $APIResponse = Set-ITGlueFlexibleAssets -data $data -id $FatO365UserID
            $UsersUpdatedCount++
        }
            # Create new IT Glue User object
            else
            {
                Write-Output "[$(Get-Date)]: Creating new user object in IT Glue:"
                $APIResponse = New-ITGlueFlexibleAssets -data $data
                $UsersCreatedCount++
            }
    }
        else
        {
            Write-Warning "[$(Get-Date)]: Unable to match the user's AAD Tenant ID to an existing IT Glue Organization using: $ITGlueAADTenantID"
            $u++
            continue
        }    
    $u++ 
}

Write-Output "[$(Get-Date)]: Number of new IT Glue users created: $UsersCreatedCount"
Write-Output "[$(Get-Date)]: Number of existing IT Glue users updated: $UsersUpdatedCount"
