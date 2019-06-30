Param(
    [string]$IP,
    [int32]$ITGClientID,
    [string]$encodedCredentials,
    [string]$Client_Name,
    [string]$Client_Location_Name
    )
# Declaring fucntion we will use to calculate the network suffix
function Convert-IpAddressToMaskLength([string] $dottedIpAddressString)
{
   $result = 0;
   # ensure we have a valid IP address
   [IPAddress] $ip = $dottedIpAddressString;
   $octets = $ip.IPAddressToString.Split('.');
   foreach($octet in $octets)
   {
     while(0 -ne $octet)
     {
       $octet = ($octet -shl 1) -band [byte]::MaxValue
       $result++;
     }
   }
   return $result;
}
#############################################################################################################################################
# Allow Untrusted Certificates in this script session most sonicwalls are using self signed certs.
add-type @"
    using System.Net;
    using System.Security.Cryptography.X509Certificates;
    public class TrustAllCertsPolicy : ICertificatePolicy {
        public bool CheckValidationResult(
            ServicePoint srvPoint, X509Certificate certificate,
            WebRequest request, int certificateProblem) {
            return true;
        }
    }
"@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

#############################################################################################################################################
# Setting Client ID Variable From Input Parameter
$ITG_Client_ID = "$ITGClientID"
$ITG_FLEX_TYPE_ID_SS = "112233"
$ITG_FLEX_TYPE_ID_AO = "112244"
$ITG_FLEX_TYPE_ID_AG = "112255"
$ITG_FLEX_TYPE_ID_SO = "112266"
$ITG_FLEX_TYPE_ID_SG = "112277"
$ITG_FLEX_TYPE_ID_AR = "112288"
#############################################################################################################################################
$SW_MGMT_Port = "1234"
$SW_IP = "$IP" + ":" + "$SW_MGMT_Port"
$API_Auth_URI = "https://$SW_IP/api/sonicos/auth"
$API_Base_URI = "https://$SW_IP/api/sonicos/"
# Adding Client's Encoded Creds to the Header
$headers = @{ Authorization = "Basic $encodedCredentials" }
# Connecting to Sonicwall using Basic Auth
$ConnectStatus = Invoke-RestMethod -Uri "$API_Auth_URI" -Method Post -Headers $headers -UseBasicParsing
$ConnectStatus = $connectstatus.status.success

#############################################################################################################################################
# Importing CSV with country list of allowed and blocked countries GEO-IP Filtering according to your SOP

 $GEO_BaseLine_CSV = Import-Csv 'C:\Safe\GeoIPCountries.csv'

#############################################################################################################################################
# Checks to see if connecting to the sonicwall was successful
If ($ConnectStatus -eq $true) {
Remove-Variable encodedCredentials

#############################################################################################################################################

# The the commands we are going to run on the sonicwall, this will be in the body of the API request.
$API_GW_CLI = 'show gateway-antivirus'
$API_IPS_CLI = 'show intrusion-prevention'
$API_GEO_CLI = 'show geo-ip'
$API_APP_CLI = 'show app-control'
$API_RBL_CLI = 'show rbl'
$API_BNET_CLI = 'show botnet'
$API_INFO_CLI = "show status"

# URI with the IP added, specifially for the accessing the CLI 'console'
$API_URI = "https://$SW_IP/api/sonicos/direct/cli"

# Special Header to return Text Output and not json object from request, specifically for Geo-IP at the moment due to bug in reporting from Json.
$TextHeader = @{ Accept = "text/plain" }


# Performs the API request and stores output, Sonicwall general info, for model, serial number and other items.
$SW_Info_Repsonse = Invoke-RestMethod -Method POST -Uri $API_URI -Body "$API_INFO_CLI" -ContentType "Text/Plain"

#############################################################################################################################################
# Performs the API Request and stores output, Gateway AV
$API_GW_Response = Invoke-RestMethod -Uri $API_URI -Body "$API_GW_CLI" -Method Post -ContentType "Text/plain"


# Performs the API Request and stores output, IPS
$API_IPS_Response = Invoke-RestMethod -Uri $API_URI -Body "$API_IPS_CLI" -Method Post -ContentType "Text/plain"


# Performs the API Request and stores output, Geo IP Filter
$API_GEO_Response = Invoke-RestMethod -Uri $API_URI -Body "$API_GEO_CLI" -Method Post -ContentType "Text/plain" -Headers $TextHeader


# Performs the API Request and stores output, App Control
$API_APP_Response = Invoke-RestMethod -Uri $API_URI -Body "$API_APP_CLI" -Method Post -ContentType "Text/plain"


# Performs the API Request and stores output, Real Time Black List
$API_RBL_Response = Invoke-RestMethod -Uri $API_URI -Body "$API_RBL_CLI" -Method Post -ContentType "Text/plain"


# Performs the API Request and stores output, Bot Net
$API_BNET_Response = Invoke-RestMethod -Uri $API_URI -Body "$API_BNET_CLI" -Method Post -ContentType "Text/plain"


#############################################################################################################################################
# First parsing API response for the genral info, creating variables for each setting we care about.
# Since the return is text, we need to convert the text to an powershell object to parse through it more easliy, basically making each line it's own property "`n" denotes new line.
$Obj_SW_Info = ConvertFrom-String -InputObject $SW_Info_Repsonse -Delimiter "`n"
    # Filing each variable for the setting we care about for now, have to drill down the PSObject to filtering for the values we care about, remove the Real propery name and trim the extra space to only have the value.
    $SW_Model = $SW_Info_Repsonse.model
    $SW_SerialNumber = $SW_Info_Repsonse.serial_number
    $SW_UpTime = $SW_Info_Repsonse.up_time
    $SW_ProdCode = $SW_Info_Repsonse.product_code
    $SW_RegCode = $SW_Info_Repsonse.registration_code
    $SW_FW_Ver = $SW_Info_Repsonse.firmware_version
    $SW_Mod_Date = $SW_Info_Repsonse.last_modified_by

#############################################################################################################################################

# Checking each setting in the SOP to check if it is enabled
# First, checking Gateway AV is enabled
    $GW_Enabled = $API_GW_Response.gateway_antivirus.enable

# Checking that gateway av is enabled for http, ftp, etc.
# InBound Settings
    $GW_IB_HTTP_Enabled = $API_GW_Response.gateway_antivirus.inbound_inspection.http

    $GW_IB_FTP_Enabled = $API_GW_Response.gateway_antivirus.inbound_inspection.ftp

    $GW_IB_IMAP_Enabled = $API_GW_Response.gateway_antivirus.inbound_inspection.imap

    $GW_IB_SMTP_Enabled = $API_GW_Response.gateway_antivirus.inbound_inspection.smtp

    $GW_IB_POP3_Enabled = $API_GW_Response.gateway_antivirus.inbound_inspection.pop3

    $GW_IB_CIFS_Enabled = $API_GW_Response.gateway_antivirus.inbound_inspection.cifs_netbios

    $GW_IB_TCP_Enabled = $API_GW_Response.gateway_antivirus.inbound_inspection.tcp_stream

# Checking that gateway av is enabled for http, ftp, etc.
# OutBound Settings

    $GW_OB_HTTP_Enabled = $API_GW_Response.gateway_antivirus.outbound_inspection.http

    $GW_OB_FTP_Enabled = $API_GW_Response.gateway_antivirus.outbound_inspection.ftp

    $GW_OB_SMTP_Enabled = $API_GW_Response.gateway_antivirus.outbound_inspection.smtp

    $GW_OB_TCP_Enabled = $API_GW_Response.gateway_antivirus.outbound_inspection.tcp_stream

# Checking each sub setting for each protocal
# HTTP Sub Settings

    $GW_HTTP_PWZIP_Enabled = $API_GW_Response.gateway_antivirus.restrict.password_protected_zip.http

    $GW_HTTP_PKEXE_Enabled = $API_GW_Response.gateway_antivirus.restrict.packed_executables.http

    $GW_HTTP_Macros_Enabled = $API_GW_Response.gateway_antivirus.restrict.ms_office_macros.http


# Checking each sub setting for each protocal
# FTP Sub Settings

    $GW_FTP_PWZIP_Enabled = $API_GW_Response.gateway_antivirus.restrict.password_protected_zip.ftp

    $GW_FTP_PKEXE_Enabled = $API_GW_Response.gateway_antivirus.restrict.packed_executables.ftp

    $GW_FTP_Macros_Enabled = $API_GW_Response.gateway_antivirus.restrict.ms_office_macros.ftp

# Checking each sub setting for each protocal
# IMAP Sub Settings

    $GW_IMAP_PWZIP_Enabled = $API_GW_Response.gateway_antivirus.restrict.password_protected_zip.imap

    $GW_IMAP_PKEXE_Enabled = $API_GW_Response.gateway_antivirus.restrict.packed_executables.imap

    $GW_IMAP_Macros_Enabled = $API_GW_Response.gateway_antivirus.restrict.ms_office_macros.imap

# Checking each sub setting for each protocal
# SMTP Sub Settings

    $GW_SMTP_PWZIP_Enabled = $API_GW_Response.gateway_antivirus.restrict.password_protected_zip.smtp

    $GW_SMTP_PKEXE_Enabled = $API_GW_Response.gateway_antivirus.restrict.packed_executables.smtp

    $GW_SMTP_Macros_Enabled = $API_GW_Response.gateway_antivirus.restrict.ms_office_macros.smtp

# Checking each sub setting for each protocal
# POP3 Sub Settings

    $GW_POP3_PWZIP_Enabled = $API_GW_Response.gateway_antivirus.restrict.password_protected_zip.pop3

    $GW_POP3_PKEXE_Enabled = $API_GW_Response.gateway_antivirus.restrict.packed_executables.pop3

    $GW_POP3_Macros_Enabled = $API_GW_Response.gateway_antivirus.restrict.ms_office_macros.pop3

# Checking each sub setting for each protocal
# CIFS-NetBios Sub Settings

    $GW_CIFS_PWZIP_Enabled = $API_GW_Response.gateway_antivirus.restrict.password_protected_zip.cifs_netbios

    $GW_CIFS_PKEXE_Enabled = $API_GW_Response.gateway_antivirus.restrict.packed_executables.cifs_netbios

    $GW_CIFS_Macros_Enabled = $API_GW_Response.gateway_antivirus.restrict.ms_office_macros.cifs_netbios

#############################################################################################################################################

# IPS Section

# Checking if IPS is enabled

    $IPS_Enabled = $API_IPS_Response.intrusion_prevention.enable

# High Priority Attacks

    $IPS_High_Prevent = $API_IPS_Response.intrusion_prevention.signature_group.high_priority.prevent_all

    $IPS_High_Detect = $API_IPS_Response.intrusion_prevention.signature_group.high_priority.detect_all

IF ($API_IPS_Response.intrusion_prevention.signature_group.high_priority.log_redundancy -eq 0) {
    $IPS_High_Log = $false
    }else {
    $IPS_High_Log = $true
    }


# Medium Priority Attacks

$IPS_Medium_Prevent = $API_IPS_Response.intrusion_prevention.signature_group.medium_priority.prevent_all

$IPS_Medium_Detect = $API_IPS_Response.intrusion_prevention.signature_group.medium_priority.detect_all

IF ($API_IPS_Response.intrusion_prevention.signature_group.medium_priority.log_redundancy -eq 0) {
$IPS_Medium_Log = $false
}else {
$IPS_Medium_Log = $true
}


# Low Priority Attacks

$IPS_Low_Prevent = $API_IPS_Response.intrusion_prevention.signature_group.Low_priority.prevent_all

$IPS_Low_Detect = $API_IPS_Response.intrusion_prevention.signature_group.Low_priority.detect_all

IF ($API_IPS_Response.intrusion_prevention.signature_group.Low_priority.log_redundancy -eq 0) {
$IPS_Low_Log = $false
}else {
$IPS_Low_Log = $true
}

#############################################################################################################################################
# App Control Section

# API Request Specifically for App Control Signatures
# Encyped Key Exchange, Sig 7
$API_APP_EKE_URI = "$API_Base_URI" + "app-control/applications/id/2900"
$API_APP_EKE_SIG7_URI = "$API_Base_URI" + "app-control/signatures/id/7"
$API_APP_EKE_SIG5_URI = "$API_Base_URI" + "app-control/signatures/id/5"
# Tor
$API_APP_TOR_CLI = 'show app-control category id 27 application id 467'

################################

# Making request for above APP Control Signatures
$API_APP_EKE_Response = Invoke-RestMethod -Uri $API_APP_EKE_URI -Method Get

# Checking to see if Encrypted Key Exchange is set to anything other than default, which would be what Proxy Access is set to.
# Depending on the sonicwall version, finding out if EKE is using the category setting will return one of two results, -or operator is added to if statement to account for that.
if ($API_APP_EKE_Response.app_control.application.block.category -eq $true -or $API_APP_EKE_Response.status.info.message -eq "App Control not found.") {
    # Using Category Settings which is not blocked Now need to Check if Signature 7 and 5 are the same.
    # Setting Results for Encrypted Key Exchange
    $APP_EKE_Enabled = $false
    # Checking Settings for Signature 7 and 5 
    $API_APP_EKE_SIG7_Response = Invoke-RestMethod -Uri $API_APP_EKE_SIG7_URI -Method Get
    $API_APP_EKE_SIG5_Response = Invoke-RestMethod -Uri $API_APP_EKE_SIG5_URI -Method Get

    # Checking Signature 7
    if ($API_APP_EKE_SIG7_Response.status.info.message -eq "App Control not found.") {
        $APP_EKE_Sig7 = $false
    } else {
        if ($API_APP_EKE_SIG7_Response.app_control.signature.block.enable -eq $true) {
            $APP_EKE_Sig7 = $true
        } else {
            $APP_EKE_Sig7 = $false
        }
    }
    
    # Checking Signature 5
    if ($API_APP_EKE_SIG5_Response.status.info.message -eq "App Control not found.") {
        $APP_EKE_Sig5 = $false
    } else {
        if ($API_APP_EKE_SIG5_Response.app_control.signature.block.enable -eq $true) {
            $APP_EKE_Sig5 = $true
        } else {
            $APP_EKE_Sig5 = $false
        }
    }
} else {
    if ($API_APP_EKE_Response.app_control.application.block.enable -eq $true) {
        $APP_EKE_Enabled = $true
        $API_APP_EKE_SIG7_Response = Invoke-RestMethod -Uri $API_APP_EKE_SIG7_URI -Method Get
        $API_APP_EKE_SIG5_Response = Invoke-RestMethod -Uri $API_APP_EKE_SIG5_URI -Method Get

        # Checking Signature 7
        if ($API_APP_EKE_SIG7_Response.status.info.message -eq "App Control not found.") {
            $APP_EKE_Sig7 = $true
        } else {
            if ($API_APP_EKE_SIG7_Response.app_control.signature.block.enable -eq $true) {
                $APP_EKE_Sig7 = $true
            } else {
                $APP_EKE_Sig7 = $false
            }
        }
        
        # Checking Signature 5
        if ($API_APP_EKE_SIG5_Response.status.info.message -eq "App Control not found.") {
            $APP_EKE_Sig5 = $true
        } else {
            if ($API_APP_EKE_SIG5_Response.app_control.signature.block.enable -eq $true) {
                $APP_EKE_Sig5 = $true
            } else {
                $APP_EKE_Sig5 = $false
            }
        }
    }
}


################################

# Making request for above APP Control Signatures
$API_APP_TOR_Response = Invoke-RestMethod -Uri $API_URI -Body "$API_APP_TOR_CLI" -Method Post -ContentType "Text/plain"
# $API_APP_TOR_Response = $API_APP_TOR_Response.content

# Checking if Tor is set to blocked
if ($API_APP_TOR_Response -like "*no block*") {
    $APP_TOR = $false
} else {
    $APP_TOR = $true
}

################################
# Check if App Control is Enabled
    $APP_Enabled = $API_APP_Response.app_control.enable


#############################################################################################################################################
# Checking Real Time Black List
    $RBL_Enabled = $API_RBL_Response.rbl.enable

#############################################################################################################################################
# Checking BotNet Filter
if ($API_BNET_Response.botnet.block.connections.all -eq $true) {
    $BNET_Enabled = $true
} else {
    $BNET_Enabled = $false
}

#############################################################################################################################################
# Checking Geo IP settings

$GEO_Allowed_Countries = @()
$GEO_Blocked_Countries = @()

($GEO_BaseLine_CSV).CountryName|ForEach-Object {
    if ($API_GEO_Response -like "*$_*") {
        $GEO_Blocked_Countries += "$_"
    } else {
        $GEO_Allowed_Countries += "$_"
    }
}


if ($API_GEO_Response -like "*no block connections*") {
    $GEO_Enabled = $false
} else {
    $GEO_Enabled = $true
}

################################

$ITG_GEO_Allowed_Countries = $GEO_Allowed_Countries -replace ","
$ITG_GEO_Blocked_Countries = $GEO_Blocked_Countries -replace ","




#############################################################################################################################################
# Anti-SpyWare Section
# Building Commands and URIs
$API_SPY_URI = "$API_Base_URI" + "anti-spyware/global"

$API_SPY_Response = Invoke-RestMethod -Uri $API_SPY_URI -Method Get

$SPY_Enabled = $API_SPY_Response.anti_spyware.enable

$SPY_High_Prevent = $API_SPY_Response.anti_spyware.signature_group.high_danger.prevent_all

$SPY_High_Detect = $API_SPY_Response.anti_spyware.signature_group.high_danger.detect_all

IF ($API_SPY_Response.anti_spyware.signature_group.high_danger.log_redundancy -eq 0) {
    $SPY_High_Log = $false
    }else {
    $SPY_High_Log = $true
    }


$SPY_medium_Prevent = $API_SPY_Response.anti_spyware.signature_group.medium_danger.prevent_all

$SPY_medium_Detect = $API_SPY_Response.anti_spyware.signature_group.medium_danger.detect_all

IF ($API_SPY_Response.anti_spyware.signature_group.medium_danger.log_redundancy -eq 0) {
    $SPY_medium_Log = $false
    }else {
    $SPY_medium_Log = $true
    }


$SPY_low_Prevent = $API_SPY_Response.anti_spyware.signature_group.low_danger.prevent_all

$SPY_low_Detect = $API_SPY_Response.anti_spyware.signature_group.low_danger.detect_all

IF ($API_SPY_Response.anti_spyware.signature_group.low_danger.log_redundancy -eq 0) {
    $SPY_low_Log = $false
    }else {
    $SPY_low_Log = $true
    }

#############################################################################################################################################
# Building Json Object to send to ITGlue in the format it accepts. 
$SecurityServiceData = New-Object PSObject -Property @{
    data = [ordered]@{
        type = "flexible-assets"
        attributes = [ordered]@{
            "organization-id" = $ITG_Client_ID
            "flexible-asset-type-id" = $ITG_FLEX_TYPE_ID_SS
            traits = [ordered]@{
                "sonicwall" = $ITG_SW_CONFIG_ID
                "sonicwall-model" = $SW_Model
                "sonicwall-serial-number" = $SW_SerialNumber
                "sonicwall-firmware-version" = $SW_FW_Ver
                "up-time" = $SW_UpTime
                "last-modified-date" = $SW_Mod_Date
                "external-ip" = $IP
                "gateway-anti-virus-enabled" = $GW_Enabled
                "gateway-av-http-inbound-inspection" = $GW_IB_HTTP_Enabled
                "gateway-av-http-outbound-inspection" = $GW_OB_HTTP_Enabled
                "gateway-av-http-password-zip-files-inspection" = $GW_HTTP_PWZIP_Enabled
                "gateway-av-http-packed-exe-files-inspection" = $GW_HTTP_PKEXE_Enabled
                "gateway-av-http-marco-files-inspection" = $GW_HTTP_Macros_Enabled
                "gateway-av-ftp-inbound-inspection" = $GW_IB_FTP_Enabled
                "gateway-av-ftp-outbound-inspection" = $GW_OB_FTP_Enabled
                "gateway-av-ftp-password-zip-file-inspection" = $GW_FTP_PWZIP_Enabled
                "gateway-av-ftp-packed-exe-file-inspection" = $GW_FTP_PKEXE_Enabled
                "gateway-av-ftp-marco-file-inspection" = $GW_FTP_Macros_Enabled
                "gateway-av-imap-inbound-inspection" = $GW_IB_IMAP_Enabled
                "gateway-av-imap-password-zip-file-inspection" = $GW_IMAP_PWZIP_Enabled
                "gateway-av-imap-packed-exe-file-inspection" = $GW_IMAP_PKEXE_Enabled
                "gateway-av-imap-marco-file-inspecition" = $GW_IMAP_Macros_Enabled
                "gateway-av-smtp-inbound-inspection" = $GW_IB_SMTP_Enabled
                "gateway-av-smtp-outbound-inspection" = $GW_OB_SMTP_Enabled
                "gateway-av-smtp-password-zip-file-inspection" = $GW_SMTP_PWZIP_Enabled
                "gateway-av-smtp-packed-exe-file-inspection" = $GW_SMTP_PKEXE_Enabled
                "gateway-av-smtp-marco-file-inspection" = $GW_SMTP_Macros_Enabled
                "gateway-av-pop3-inbound-inspection" = $GW_IB_POP3_Enabled
                "gateway-av-pop3-password-zip-file-inspection" = $GW_POP3_PWZIP_Enabled
                "gateway-av-pop3-packed-exe-file-inspection" = $GW_POP3_PKEXE_Enabled
                "gateway-av-pop3-macro-file-inspection" = $GW_POP3_Macros_Enabled
                "gateway-av-cifs-inbound-inspection" = $GW_IB_CIFS_Enabled
                "gateway-av-cifs-password-zip-file-inspection" = $GW_CIFS_PWZIP_Enabled
                "gateway-av-cifs-packed-exe-file-inspection" = $GW_CIFS_PKEXE_Enabled
                "gateway-av-cifs-macro-file-inspection" = $GW_CIFS_Macros_Enabled
                "gateway-av-tcp-stream-inbound-inspection" = $GW_IB_TCP_Enabled
                "gateway-av-tcp-stream-outbound-inspection" = $GW_OB_TCP_Enabled
                "intrusion-prevention-system-enabled" = $IPS_Enabled
                "prevent-high-priority-attacks" = $IPS_High_Prevent
                "detect-high-priority-attacks" = $IPS_High_Detect
                "log-high-priority-attacks" = $IPS_High_Log
                "prevent-medium-priority-attacks" = $IPS_Medium_Prevent
                "detect-medium-priority-attacks" = $IPS_Medium_Detect
                "log-medium-priority-attacks" = $IPS_Medium_Log
                "prevent-low-priority-attacks" = $IPS_Low_Prevent
                "detect-low-priority-attacks" = $IPS_Low_Detect
                "log-low-priority-attacks" = $IPS_Low_Log
                "app-control-enabled" = $APP_Enabled
                "encrypted-key-exchange-blocked" = $APP_EKE_Enabled
                "tor-blocked" = $APP_TOR
                "encrypted-key-exchange-signature-7-blocked" = $APP_EKE_Sig7
                "encrypted-key-exchange-signature-5-blocked" = $APP_EKE_Sig5
                "realTime-black-list-enabled" = $RBL_Enabled
                "anti-spyware-enabled" = $SPY_Enabled
                "prevent-high-danger-spyware" = $SPY_High_Prevent
                "detect-high-danger-spyware" = $SPY_High_Detect
                "log-high-danger-spyware" = $SPY_High_Log
                "prevent-medium-danger-spyware" = $SPY_medium_Prevent
                "detect-medium-danger-spyware" = $SPY_medium_Detect
                "log-medium-danger-spyware" = $SPY_medium_Log
                "prevent-low-danger-spyware" = $SPY_low_Prevent
                "detect-low-danger-spyware" = $SPY_low_Detect
                "log-low-danger-spyware" = $SPY_low_Log
                "botNet-filter-enabled" = $BNET_Enabled
                "geo-ip-filtering-enabled" = $GEO_Enabled
                "allowed-countries" = "<div>" + ((($ITG_GEO_Allowed_Countries) -replace '"') -join '<br></div>') + "</div>"
                "blocked-countries" = "<div>" + ((($ITG_GEO_Blocked_Countries) -replace '"') -join '<br></div>') + "</div>"
            }
        }

    }
}
#############################################################################################################################################
# Gathering Address Objects
# Pull all Address Objects from Sonicwall
# IPv4 Address Objects URL
$SW_IPv4_AddObj_URI = $API_Base_URI + "address-objects/ipv4"
$API_SW_AO_Results = Invoke-RestMethod -Method Get -Uri "$SW_IPv4_AddObj_URI"

# Pull all Address Objects from Sonicwall
# FQDN Address Objects URL
$SW_FQDN_AddObj_URI = $API_Base_URI + "address-objects/fqdn"
$API_SW_AO_Results_FQDN = Invoke-RestMethod -Method Get -Uri "$SW_FQDN_AddObj_URI"

# Pull all Address Objects from Sonicwall
# MAC Address Objects URL
$SW_MAC_AddObj_URI = $API_Base_URI + "address-objects/mac"
$API_SW_AO_Results_MAC = Invoke-RestMethod -Method Get -Uri "$SW_MAC_AddObj_URI"


# Break out the output into separate variables, hosts, networks (subnets) and Ranges
$AllHosts = $API_SW_AO_Results.address_objects.ipv4|Where-Object -Property host -ne -value $null
$AllNetworks = $API_SW_AO_Results.address_objects.ipv4|Where-Object -Property network -ne -value $null
$AllRanges = $API_SW_AO_Results.address_objects.ipv4|Where-Object -Property range -ne -value $null

# FQDN
$AllFQDN = $API_SW_AO_Results_FQDN.address_objects.fqdn

# MAC
$AllMAC = $API_SW_AO_Results_MAC.address_objects.mac

# Clean up results to remove any objects without a zone assigned
$AllHosts = $AllHosts|Where-Object -Property zone -ne -value $null
$AllNetworks = $AllNetworks|Where-Object -Property zone -ne -value $null
$AllRanges = $AllRanges|Where-Object -Property zone -ne -value $null
$AllFQDN = $AllFQDN|Where-Object -Property zone -ne -value $null
$AllMAC = $AllMAC|Where-Object -Property zone -ne -value $null

# Creating empty arrays to use to segment in the AddressObjects array.
$arrAddressObjects = @()
$arrAOHosts = @()
$arrAONetworks = @()
$arrAORanges = @()
$arrAOFQDN = @()
$arrAOMAC = @()


# Create Json Object for each Host in a format that ITGlue will accept
ForEach ($object in $AllHosts) {
    
    
    $AddressObjectData = New-Object PSObject -Property @{
        data = [ordered]@{
            type = "flexible-assets"
            attributes = [ordered]@{
                "organization-id" = $ITG_Client_ID
                "flexible-asset-type-id" = $ITG_FLEX_TYPE_ID_AO
                traits = [ordered]@{
                    "sonicwall" = $ITG_SW_CONFIG_ID
                    "address-object-name" = $object.Name
                    "uuid" = $object.uuid
                    "zone" = $object.zone
                    "object-type" = "Host"
                    "object-value" = $object.host.ip
                }
            }
        }
    }
$arrAOHosts += $AddressObjectData
Remove-Variable AddressObjectData
}


# Create Json Object for each Network in a format that ITGlue will accept
ForEach ($object in $AllNetworks) {
    # Calculate the network suffix to add to the subnet
    $objMask = $object.network.mask
    ($IPLength = Convert-IpAddressToMaskLength $objMask) *>$null
    $IPValue = $object.network.subnet + " / " + $IPLength + " / " + $objMask
    
    $AddressObjectData = New-Object PSObject -Property @{
        data = [ordered]@{
            type = "flexible-assets"
            attributes = [ordered]@{
                "organization-id" = $ITG_Client_ID
                "flexible-asset-type-id" = $ITG_FLEX_TYPE_ID_AO
                traits = [ordered]@{
                    "sonicwall" = $ITG_SW_CONFIG_ID
                    "address-object-name" = $object.Name
                    "uuid" = $object.uuid
                    "zone" = $object.zone
                    "object-type" = "Network"
                    "object-value" = $IPValue

                }
            }
        }
    }

$arrAONetworks += $AddressObjectData
Remove-Variable AddressObjectData,objMask,IPLength,IPValue
}


# Create Json Object for each Range in a format that ITGlue will accept
ForEach ($object in $AllRanges) {
    # Bring the start and end IPs together
    $StartIP = $object.range.begin
    $EndIP = $object.range.end
    $IPRange = $StartIP + " - " + $EndIP
    
    $AddressObjectData = New-Object PSObject -Property @{
        data = [ordered]@{
            type = "flexible-assets"
            attributes = [ordered]@{
                "organization-id" = $ITG_Client_ID
                "flexible-asset-type-id" = $ITG_FLEX_TYPE_ID_AO
                traits = [ordered]@{
                    "sonicwall" = $ITG_SW_CONFIG_ID
                    "address-object-name" = $object.Name
                    "uuid" = $object.uuid
                    "zone" = $object.zone
                    "object-type" = "Range"
                    "object-value" = $IPRange

                }
            }
        }
    }

$arrAORanges += $AddressObjectData
Remove-Variable AddressObjectData,StartIP,EndIP,IPRange
}

# Create Json Object for each FQDN in a format that ITGlue will accept
ForEach ($object in $AllFQDN) {
    
    
    $AddressObjectData = New-Object PSObject -Property @{
        data = [ordered]@{
            type = "flexible-assets"
            attributes = [ordered]@{
                "organization-id" = $ITG_Client_ID
                "flexible-asset-type-id" = $ITG_FLEX_TYPE_ID_AO
                traits = [ordered]@{
                    "sonicwall" = $ITG_SW_CONFIG_ID
                    "address-object-name" = $object.Name
                    "uuid" = $object.uuid
                    "zone" = $object.zone
                    "object-type" = "FQDN"
                    "object-value" = $object.domain
                }
            }
        }
    }
$arrAOFQDN += $AddressObjectData
Remove-Variable AddressObjectData
}

# Create Json Object for each MAC in a format that ITGlue will accept
ForEach ($object in $AllMAC) {
    
    
    $AddressObjectData = New-Object PSObject -Property @{
        data = [ordered]@{
            type = "flexible-assets"
            attributes = [ordered]@{
                "organization-id" = $ITG_Client_ID
                "flexible-asset-type-id" = $ITG_FLEX_TYPE_ID_AO
                traits = [ordered]@{
                    "sonicwall" = $ITG_SW_CONFIG_ID
                    "address-object-name" = $object.Name
                    "uuid" = $object.uuid
                    "zone" = $object.zone
                    "object-type" = "MAC"
                    "object-value" = $object.address
                }
            }
        }
    }
$arrAOMAC += $AddressObjectData
Remove-Variable AddressObjectData
}

# Combing all objects found into a parent array.
# Still need to do MAC and FQDN, will worry about those later.
$arrAddressObjects += $arrAOHosts
$arrAddressObjects += $arrAONetworks
$arrAddressObjects += $arrAORanges
$arrAddressObjects += $arrAOFQDN
$arrAddressObjects += $arrAOMAC

#############################################################################################################################################
# Combining Security Services and Address Object Data
$UpdateData = @()
$UpdateData += $SecurityServiceData
$UpdateData += $arrAddressObjects

ConvertTo-Json -InputObject $UpdateData -Depth 100 | Write-OutPut

} else {
    Write-OutPut "Failed to Connect to Sonicwall"
}