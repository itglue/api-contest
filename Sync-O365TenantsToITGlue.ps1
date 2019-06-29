<# 
.SYNOPSIS
Sync Office 365 tenants to IT Glue

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
        - TenantDisplayName
        - TenantID
        - TenantInitialDomain
        - VerifiedDomains
        - DirSyncEnabled
        - LastDirSyncTime
        - DirSyncServiceAccount
        - DirSyncClientMachineName
        - DirSyncClientVersion
        - SharePointUrl
        - UnifiedAuditLogEnabled
        - UnifiedAuditLogFirstEnabled
        - OWATimeoutEnabled
        - OWATimeoutInterval
        - ModernAuthenticationEnabled
        - SfBModernAuthentication
        - TechnicalNotificationEmails
        - TenantLicenses
#>

[cmdletbinding()]
Param()

Write-Warning "This script assumes the below pre-requisites:
    - IT Glue PowerShell Wrapper is already installed
    - IT Glue API Key has already been created
    - IT Glue organisations that you want to sync to Office 365 tenant information to, have their Azure AD Tenant ID already listed within 
        the IT Glue Organisation DESCRIPTION field in the format of: AADTenantID:<Azure AD Tenant ID>, for example for the contoso.com tenant:
        AADTenantID:6babcaad-604b-40ac-a9d7-9fd97c0b779f
    - A CSV export of Office 365 tenant data for ALL CSP customers has already been generated and available to be queried, and should contain the following headers:
        - TenantDisplayName
        - TenantID
        - TenantInitialDomain
        - VerifiedDomains
        - DirSyncEnabled
        - LastDirSyncTime
        - DirSyncServiceAccount
        - DirSyncClientMachineName
        - DirSyncClientVersion
        - SharePointUrl
        - UnifiedAuditLogEnabled
        - UnifiedAuditLogFirstEnabled
        - OWATimeoutEnabled
        - OWATimeoutInterval
        - ModernAuthenticationEnabled
        - SfBModernAuthentication
        - TechnicalNotificationEmails
        - TenantLicenses"

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

$ReportFile = Read-Host "Enter path to CSV file containing export of Office 365 tenant details"
$O365Tenants = Import-Csv $ReportFile
$FatID = Read-Host "Enter your IT Glue FAT (Flexible Asset ID) for the custom Office 365 Tenant object type"
$ITGlueOrgs = Get-ITGlueOrganizations -page_size 1000 -sort name | Select-Object -ExpandProperty data


$i = 1
$TenantsCreatedCount = 0
$TenantsUpdatedCount = 0
$TenantsDeletedCount = 0

foreach($ITGlueOrg in $ITGlueOrgs)
{
    Write-Output "[$(Get-Date)]: Processing customer $i of $($ITGlueOrgs.Count): $($ITGlueOrg.attributes.name)"
    # Filter Orgs where AAD Tenant ID has been pre-set for hard matching
    if($ITGlueOrg.attributes.description -match "AADTenantID:")
    {
        # Grab O365 details for specific customer from CSV report
        $O365Tenant = $O365Tenants | Where-Object {$_.TenantID -like $ITGlueOrg.attributes.description.Split(":")[1]}
        # Get existing FAT from IT Glue
        $FATO365Tenant = Get-ITGlueFlexibleAssets -filter_flexible_asset_type_id $FatID -filter_organization_id $ITGlueOrg.id
        
        # If the O365 tenant isn't listed on the CSV export, we assume tenant is no longer a customer, so delete FAT from IT Glue
        if($O365Tenant -eq $null)
        {
            if($FATO365Tenant.data)
            {
                Write-Warning "[$(Get-Date)]: Deleting existing FATs as unable to detect customer on the O365 CSP export"
                $FATO365Tenant.data.id | foreach{
                    Remove-ITGlueFlexibleAssets -id $_ -Confirm:$false
                }

                $TenantsDeletedCount++
            }
                else
                {
                    Write-Warning "[$(Get-Date)]: Skipping customer as unable to match IT Glue Organization to O365 CSP export"
                }

            $i++
            continue
        }

        # Build hashtable object to pass to the ITG API
        $data = @{
            type =  "flexible-assets"
            attributes = @{
                "organization-id" = $ITGlueOrg.id
                "flexible-asset-type-id" = $FatID
                "flexible-asset-type-name" = "Office 365 Tenant"
                "traits" = @{
                    "tenant-name" = $O365Tenant.TenantDisplayName
                    "tenant-id" = $O365Tenant.TenantID
                    "initial-domain" = $O365Tenant.TenantInitialDomain
                    "verified-domains" = $O365Tenant.VerifiedDomains
                    "dirsync-status" = [System.Convert]::ToBoolean($O365Tenant.DirSyncEnabled)
                    "last-dirsync-time" = $O365Tenant.LastDirSyncTime
                    "dirsync-service-account" = $O365Tenant.DirSyncServiceAccount
                    "dirsync-server" = $O365Tenant.DirSyncClientMachineName
                    "dirsync-client-version" = $O365Tenant.DirSyncClientVersion
                    "sharepoint-online-url" = $O365Tenant.SharePointUrl
                    "audit-log-enabled" = [System.Convert]::ToBoolean($O365Tenant.UnifiedAuditLogEnabled)
                    "audit-log-enabled-time" = $O365Tenant.UnifiedAuditLogFirstEnabled
                    "owa-timeout-enabled" = [System.Convert]::ToBoolean($O365Tenant.OWATimeoutEnabled)
                    "owa-timeout-interval-hours" = $O365Tenant.OWATimeoutInterval
                    "exchange-modern-authentication-enabled" = [System.Convert]::ToBoolean($O365Tenant.ModernAuthenticationEnabled)
                    "skype-for-business-modern-authentication-enabled" = $O365Tenant.SfBModernAuthentication
                    "technical-email-contact" = $O365Tenant.TechnicalNotificationEmails
                    "licenses" = $O365Tenant.TenantLicenses
                    # "licensed-users" = $O365Tenant.UserLicenses
                    "last-it-glue-sync-time" = (Get-Date).ToString()
                }
            }
        }

        if($FATO365Tenant.data)
        {
            # Update existing FAT
            Write-Output "[$(Get-Date)]: Updating existing FAT"
            Set-ITGlueFlexibleAssets -data $data -id $FATO365Tenant.data.id
            $TenantsUpdatedCount++
        }
            else
            {
                # Create new FAT
                Write-Output "[$(Get-Date)]: Creating new FAT"
                New-ITGlueFlexibleAssets -data $data
                $TenantsCreatedCount++
            }
    }
        else
        {
            Write-Warning "[$(Get-Date)]: Skipping customer due to missing Azure AD tenant ID in description field"
        }
    $i++
}

Write-Output "[$(Get-Date)]: Number of new IT Glue O365 Tenant FATs created: $TenantsCreatedCount"
Write-Output "[$(Get-Date)]: Number of existing IT Glue O365 Tenant FATs updated: $TenantsUpdatedCount"
Write-Output "[$(Get-Date)]: Number of existing IT Glue O365 Tenant FATs deleted: $TenantsDeletedCount"

