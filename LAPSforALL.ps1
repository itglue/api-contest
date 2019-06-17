# This script will set a local account to a random password and update this password in ITGlue.
# It requires PowerShell 5.0 or newer.  The ITGlueAPI only requires PowerShell 3.0, but since
# many of the commands in the script are using PowerShell 5.0 functions for ease of use, 5.0 is required.
#
# Sets various environmental variables needed for the script
#

#####################################################################################################################
#                                                                                                                   #
# NOTE: Variables that use the format of $env:<variable name> are pushed as part of the environment from the        #
# DattoRMM platform. These will be outlined here with the relevant description.  For ease of testing, the script    #
# was made with hard-coded variables which were later changed to be set by the DattoRMM component.  Removing the    #
# DattoRMM variables and replacing them with the respective value will allow the script to run as a stand-alone     #
# process.                                                                                                          #
#                                                                                                                   #
# $env:LocalAdminAccount - This is the account that will be made local admin on the device. If it doesn't exist,    #
# it will be created.                                                                                               #
#                                                                                                                   #
# $env:AccountDescription - This is the description for the local admin account to be shown in computer management. #
#                                                                                                                   #
# $env:MaxPasswordAge - This is the maximum password age in days.  If the current password is older than X days,    #
# it will be updated.                                                                                               #
#                                                                                                                   #
# $env:ITGlueAPIKey - This is the ITGlue API key to use.                                                            #
#                                                                                                                   #
# $env:DisableOtherLocalAccounts - True/False.  Sets weather to disable other local accounts.  Domain only.         #
#                                                                                                                   #
#####################################################################################################################


# The local account on the computer that will be checked.  If the account does not exist, it will be created. 
# It will also be added to the local administrators group if it isn't already.
$varLocalAccount = $env:LocalAdminAccount
$varLocalAccountDescription = $env:AccountDescription

# Set the maximum password age
$maxPWAge = $env:MaxPasswordAge

# DattoRMM device GUID
# This is used to confirm that the correct device in ITGlue is being updated.  This is the unique device ID used in DattoRMM.
$varDattoRMMDeviceID = (Get-ItemProperty -Path Registry::HKEY_LOCAL_MACHINE\SOFTWARE\CentraStage).DeviceID

# If set to true, will disable any other local accounts if the computer is part of a domain.
$varDisableOtherLocalAccounts = $env:DisableOtherLocalAccounts


function Get-CmdletExist {
    # Part of the update process requires certain powershell cmdlets to be installed on the device.
    # This function checks for the cmdlet's existance.
    param (
        [parameter(Mandatory=$true)]
        [string]
        $cmdname
    )
    if (Get-Command $cmdname -errorAction SilentlyContinue) {
        return $true
    }
    else{
        return $false
    }
}

function Get-LocalPasswordAge {
    # Returns the account's password age in days for the specified account.
    param (
        [parameter(Mandatory=$true)]
        [string]
        $localaccount
    )
    $now = Get-Date
    $account = get-localuser $localaccount
    $pwLastSet = $account.PasswordLastSet
    $PWAge = ($now - $pwLastSet).days
    return $PWAge
}

function Update-RequiredModules {
    # Updates the various modules and package providers needed to successfully install the ITGlueAPI module.
    # NuGet must be updated to the latest version. If this is the first time the script has been ran, it is likely outdated.
    # PowerShellGet must be installed and the latest version.  The commands force install the module, and updates the module to latest version if it is already installed.
    # The latest versions of NuGet and PowerShellGet are required in order to check the version number of modules from the PowerShell Gallery repository.
    Install-PackageProvider NuGet -Force
    Install-Module -Name PowerShellGet -Force -AllowClobber
    Update-Module -Name PowerShellGet
}

function Install-ITGlueAPI {
    # Installs the latest ITGlueAPI to the computer.
    # This performs a forced install of the module if it is missing, and updates it to the latest version if it is already installed.
    Install-Module -Name ITGlueAPI -Force -AllowClobber
    Update-Module -Name ITGlueAPI
}

function Get-ModuleVersion {
    # Returns the version of the installed module provided.
    param (
    [Parameter(Mandatory=$true)]
    [string]
    $Module
    )
    $tmp = (get-module -ListAvailable -name $Module | select-object -Property Version | sort-object | Select-Object -Last 1).version
    return $tmp
}

function Get-PSGalleryModuleVersion {
    # Returns the latest version of the module provided as available on PSGallery.
    param (
    [Parameter(Mandatory=$true)]
    [string]
    $Module
    )
    $tmp = (Find-Module -name $Module | select-object -Property Version | sort-object | Select-Object -Last 1).version
    return $tmp

}

function Get-ITGlueDevice {
    # This function tries to find the matching device in ITGlue for the current machine.
    param (
    [Parameter(Mandatory=$true)]
    [string]
    $DattoRMMDeviceID
    )
    
    # Parse through a configuration list of configs with the local computer name to find the configuration with the matching GUID from Datto RMM.
    # In case there are multiple matching computer names, this will find the specific ITGlue object which contains the corresponding device ID from DattoRMM.
    Foreach ($Comp in (Get-ITGlueConfigurations -filter_name $env:COMPUTERNAME).data) {
        IF ($Comp.attributes.'asset-tag' -match $DattoRMMDeviceID) {
            $Config = $Comp
        } 
        Else {
            $Config = $null
        }
    }
    
    return $config
}


function Test-RegistryEntry {
    # Check for registry key and object.
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        $Path,
        [parameter(mandatory=$true)]
        [ValidateNotNullorEmpty()]
        $key,
        [parameter(mandatory=$true)]
        [string]
        $value
    )
    try {
        # The first line causes the try section to exit out if the key doesn't exist.  The out-null prevents errors from showing up in the stderr.
        # The second line and after will only run if the first line ran successfully without errors. 
        $vartmp = (Get-ItemProperty -Path $path | select-object -ExpandProperty $key -ErrorAction Stop | out-null)
        $vartmp = (Get-ItemProperty -Path $path | select-object -ExpandProperty $key)
        if (($vartmp) -eq "1"){
            return $true
        }
        else {
            return $false
        }
    }
    catch {
        return $false
    }

}

write-host "Running environment checks: `n"

# Checks to make sure the script is only being ran on workstations.  If it is ran on 
# a server, the script will simply exit with a success.
    # $osInfor.ProductType returns back the type of system the script is running on (1, 2 or 3).
    # 1 - Workstation
    # 2 - Domain Controller
    # 3 - Server
$osInfo = Get-WmiObject -Class Win32_OperatingSystem

if ($osInfo.ProductType -gt 1) {
    write-output "================================================================"
    write-output "=                                                              ="
    write-output "= INFO:                                                        ="
    write-output "= This script will only run on workstations.                   ="
    write-output "=                                                              ="
    write-output "================================================================"
    exit 0
}

# Checks to make sure the required variables have been configured in the Datto RMM component.
if ($null -eq $varLocalAccount){
    write-output "================================================================"
    write-output "=                                                              ="
    write-output "= ERROR:                                                       ="
    write-output "= LocalAdminAccount missing in component variables.            ="
    write-output "=                                                              ="
    write-output "================================================================"
    exit 1
}
if ($null -eq $varLocalAccountDescription){
    write-output "================================================================"
    write-output "=                                                              ="
    write-output "= ERROR:                                                       ="
    write-output "= AccountDescription missing in component variables.           ="
    write-output "=                                                              ="
    write-output "================================================================"
    exit 1
}
if ($null -eq $env:ITGlueAPIKey){
    write-output "================================================================"
    write-output "=                                                              ="
    write-output "= ERROR:                                                       ="
    write-output "= ITGlueAPIKey missing in component variables.                 ="
    write-output "=                                                              ="
    write-output "================================================================"
    exit 1
}
if ($null -eq $maxPWAge){
    write-output "================================================================"
    write-output "=                                                              ="
    write-output "= ERROR:                                                       ="
    write-output "= MaxPasswordAge missing in component variables.               ="
    write-output "=                                                              ="
    write-output "================================================================"
    exit 1
}

# Checking that PowerShell is at least version 5.0
if ($PSVersionTable.psversion.Major -lt 5) {
    write-output "================================================================"
    write-output "=                                                              ="
    write-output "= ERROR:                                                       ="
    write-output "= PowerShell 5.0 or later is required.                         ="
    write-output "=                                                              ="
    write-output "================================================================"
    exit 1
}
else {
    write-output "PowerShell version $($psversiontable.psversion.major).$($psversiontable.psversion.minor) installed."
}



# Tests to see if Powershell module logging is enabled.  This will allow the local account passwords
# and API keys to be discovereable in the Powershell event logs. Unless your environment has no
# untrusted administrative accounts, this is an EXTREME security risk.

if (((Test-registryentry -path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ModuleLogging' -key 'EnableModuleLogging' -value '1') -eq $true) -or ((Test-registryentry -path 'HKLM:\SOFTWARE\Wow6432Node\Policies\Microsoft\Windows\PowerShell\ModuleLogging' -key 'EnableModuleLogging' -value '1') -eq $true)) {
    write-output "================================================================"
    write-output "=                                                              ="
    write-output "= WARNING:                                                     ="
    write-output "= PowerShell Module Logging is enabled.  This will allow       ="
    write-output "= highly sensitive information to be discovered in the logs.   ="
    write-output "= This script will now exit.                                   ="
    write-output "=                                                              ="
    write-output "================================================================"
    exit 1
}
else {
    write-output "Powershell module logging is not enabled."
}

# Makes sure that the execution policy is properly configured.  The script itself is ran with the -bypass command,
# but the imported modules will not work without using RemoteSigned.

Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -force | Out-Null

# Checks to make sure the install-module command is available. All other functions require this environmental condition.
# This section updates the powershell environment if necessary.
if (Get-CmdletExist -cmdname "Install-Module"){
    write-host "`nChecking required module versions..."
    # PowerShell 5.1 ships with an old version of PowerShellGet.  If this has not been updated on the system, install the new version.
    # Nuget is required for this script to work.  Install nuget if it is missing.

    # Since NuGet is required for the PSGalleryModuleVersion check to work, install it if it is missing.
        if(Get-PackageProvider | where-object {"NuGet" -contains $_.name}){
        write-host "Nuget package provider already installed."
    }
    else{
        write-host "Installing NuGet package provider."
        Install-PackageProvider NuGet -Force
    }
    $varCurrentPSGet = Get-PSGalleryModuleVersion -Module "PowerShellGet"
    if ([version](get-moduleversion -Module "PowerShellGet") -lt [version]$varCurrentPSGet){
        write-host "The installed version of PowerShellGet is older than the current release of $varCurrentPSGet."
        write-host "Updating NuGet and PowerShellGet to latest versions.`n"
        Update-RequiredModules
    }
    else {
        write-host "The installed version of PowerShellGet is greater than or equal to the current release of $varCurrentPSGet."
    }

    # Checks the currently installed version of ITGlueAPI.  If the version is out of date, update to the latest version.
    $varCurrentITGlueAPI = Get-PSGalleryModuleVersion -Module "ITGlueAPI"
    if ([version](get-moduleversion -Module "ITGlueAPI") -lt [version]$varCurrentITGlueAPI){
        write-host "The installed version of ITGlueAPI is older than the current release of $varCurrentITGlueAPI."
        write-host "Updating ITGlueAPI to latest versions.`n"
        Install-ITGlueAPI
    }
    else {
        write-host "The installed version of ITGlueAPI is greater than or equal to the current release of $varCurrentITGlueAPI."
    }
}
else {
    # There are a handful of machines which have broken PowerShell environments.
    # If the earlier test for install-module failed, throw an error so the system can be fixed.
    write-output "================================================================"
    write-output "=                                                              ="
    write-output "= ERROR:                                                       ="
    write-output "= Install-Module cmdlet does not exist.                        ="
    write-output "= ITGlue integration requies the Install-Module functionality. ="
    write-output "= Please update the PowerShell environment on this system.     ="
    write-output "=                                                              ="
    write-output "================================================================"
    exit 1
}




# Activate the ITGlueAPI module 
write-host "`nActivating ITGlueAPI..."
Import-Module ITGlueAPI
Add-ITGlueAPIKey -api_key $env:ITGlueAPIKey

# Find the computer configuration in ITGlue.
# If the DattoRMM device ID cannot be found in ITGlue, there is likely a sync issue of some sort.
# The script throws an error here so the issue can be investigated and corrected.
write-host "Locating $env:COMPUTERNAME in ITGlue."
$varITGlueDevice=(Get-ITGlueDevice -DattoRMMDeviceID $varDattoRMMDeviceID)

if ($null -eq $varITGlueDevice){
    Write-Output "`nUnable to locate device $env:COMPUTERNAME in ITGlue. Exiting script."
    exit 1
}

# This section generates a random password (length, #of symbols) and convert it to a secure string for Windows.
# The ITGlue API is not able to parse a secure string for our purpose, so an unencrypted string must be used.
write-host "`nGenerating secure password..."
Add-Type -AssemblyName System.Web
$PW = [System.Web.Security.Membership]::GeneratePassword(16,4)
$SecurePW = ($PW | ConvertTo-SecureString -AsPlainText -Force)

# Check the specified account and see if it exists.  If not, create it. 
# Set the password to the new secure password and enabled the account. (Just in case it was disabled.)
# Since the script might later disable other local accounts, it needs to make sure this account is enabled.
Write-Host "`nChecking local account $varLocalAccount..."
If ((Get-LocalUser $varLocalAccount).name -eq $varLocalAccount) {
    write-host "Local account $varLocalAccount already exists."
    write-host "`nChecking password age..."
    $currentPWAge = Get-LocalPasswordAge -localaccount $varlocalaccount
    if ($maxPWAge -le $currentPWage) {
        write-host "Password is older than $maxPWAge day(s). Updating password."
        Set-LocalUser -Name $varLocalAccount -Password $SecurePW
        Enable-LocalUser -Name $varLocalAccount
    }
    else {
        $toosoon = 1
        write-host "Password has been changed in the last $maxPWAge day(s). No update necessary."
        Enable-LocalUser -Name $varLocalAccount
    }
}
else {
    write-host "Local account $varLocalAccount does not exist. Creating account. Setting password."
    New-LocalUser -Name $varLocalAccount -Password $SecurePW -Description $varLocalAccountDescription
}

# Checks to make sure the account is part of the local administrators group and adds it if not.
if (get-localgroupmember -group "Administrators" -member $varLocalAccount -ErrorAction SilentlyContinue) {
    Write-Host "`nLocal account $varLocalAccount is already part of the local Administrators group."
}
else {
    Add-LocalGroupMember -Group Administrators -Member $varLocalAccount
    Write-Host "`nLocal account $varLocalAccount has been added to the local Administrators group."
}

if ($toosoon -eq 1) {

}
else {
# Now that the device has been located in ITGlue and the local password has been set, it is time to
# save the new password in ITGlue.

# This section builds the password record to save to ITGlue with the following:
# type - must be set to passwords
# organization-id - single tick quote because of the hyphen, this is required for locating the configuration
# name - the name of the password in quotes as text
# username - the username in quotes as text
# password - using the randomly generated password above
# resource_id - required for locating the resource
# resource_type = 'Configuration'
$data = @{
	type = "passwords"
	attributes = @{
        'organization-id' = $varITGlueDevice.attributes.'organization-id'
        name = "Local $varLocalAccount Admin"
        username = "$varLocalAccount"
        password = $PW
        resource_id = $varITGlueDevice.'id'
        resource_type = 'Configuration'
	}
}


#This line retrieves the old password using the organization, configuration name, and password name (will not error if no password is found)
$OldPass = Get-ITGluePasswords -filter_organization_id $varITGlueDevice.attributes.'organization-id' -filter_cached_resource_name $varITGlueDevice.attributes.name -filter_name "Local $varLocalAccount Admin"


#Checks if the url for the config matches with the parent url of the embedded password - if so, the password is updated, if not then the password is created
If ($OldPass.data.attributes.'parent-url' -eq $varITGlueDevice.attributes.'resource-url') {
    write-host "Updating existing password in ITGlue."
    Set-ITGluePasswords -id $Oldpass.data.id -data $data
}
Else {
    write-host "Creating new embedded password."
    New-ITGluePasswords -data $data
}




}
# If set to do so, disable other local accounts on the system.
# If the script does not disable any local accounts, it performs an audit of the existing accounts
# and their enabled/disabled status for reference.
if ($varDisableOtherLocalAccounts -eq $true){
    # If the computer is part of a domain, disable the other local accounts.
    # This is a sanity check so this won't actually do anything if the computer is not on a domain.
    if ((Get-WmiObject -class win32_ComputerSystem).PartOfDomain) {
        write-output "`nDisabling other local accounts..."
        foreach ($user in get-localuser) {
            switch ($user.name) {
                # This leaves the account that was updated alone along with other local accounts which should be left as-is.
                # If other local accounts need to be left alone, they can be added to this switch statement.
                $varLocalAccount {write-host "No action taken for $($user.name)."}
                "WDAGUtilityAccount" {write-host "No action taken for $($user.name)."}

                Default {
                    if ($user.enabled -eq $true){
                        write-host "Disabling local user $($user.name)."
                        disable-localuser $user.name
                    }
                    else {
                        write-host "User $($user.name) is already disabled."
                    }
                    
                }
            }
        }
    }
    else {
        write-output "`nListing status of local accounts..."
        foreach ($user in get-localuser) {
            if ($user.enabled -eq $true){
                write-host "User $($user.name) is currently enabled."
            }
            else {
                write-host "User $($user.name) is already disabled."
            }
    
        }
    }
}
else {
    write-output "`nListing status of local accounts..."
    foreach ($user in get-localuser) {
        if ($user.enabled -eq $true){
            write-host "User $($user.name) is currently enabled."
        }
        else {
            write-host "User $($user.name) is already disabled."
        }

    }
}

# Everything is done.  Log an 'all finished' line and exit.
write-host "`nLocal admin account policy update has completed."