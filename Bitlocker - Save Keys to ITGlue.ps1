# This script reads the BitLocker information for every drive on the system and will record the key for any drive that has one (will overwrite an old key with the current one).
# It requires PowerShell 5.0 or newer.  The ITGlueAPI only requires PowerShell 3.0, but since
# many of the commands in the script are using PowerShell 5.0 functions for ease of use, 5.0 is required.


# DattoRMM device GUID
$varDattoRMMDeviceID = (Get-ItemProperty -Path Registry::HKEY_LOCAL_MACHINE\SOFTWARE\CentraStage).DeviceID


function Get-CmdletExist {
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


function Update-RequiredModules {
    # Updates the various modules and package providers needed to successfully install the ITGlueAPI module.
    Install-PackageProvider NuGet -Force
    Install-Module -Name PowerShellGet -Force -AllowClobber
    Update-Module -Name PowerShellGet
}

function Install-ITGlueAPI {
    # Installs the latest ITGlueAPI to the computer.
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
    param (
    [Parameter(Mandatory=$true)]
    [string]
    $DattoRMMDeviceID
    )
    
    #Parse through a configuration list of configs with the local computer name to find the configuration with the matching GUID from Datto RMM
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

# Check for module logging
function Test-RegistryEntry {
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
        # The second line will only run if the first line ran successfully without errors. 
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

# Checks to make sure the required variables have been configured in the Datto RMM component.

if ($null -eq $env:ITGlueAPIKey){
    write-output "================================================================"
    write-output "=                                                              ="
    write-output "= ERROR:                                                       ="
    write-output "= ITGlueAPIKey missing in component variables.                 ="
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

# Find the computer configuration in ITGlue using the new Get-ITGlueDevice function
write-host "Locating $env:COMPUTERNAME in ITGlue."
$varITGlueDevice=(Get-ITGlueDevice -DattoRMMDeviceID $varDattoRMMDeviceID)

if ($null -eq $varITGlueDevice){
    Write-Output "`nUnable to locate device $env:COMPUTERNAME in ITGlue. Exiting script."
    exit 1
}

# Identify all the Bitlocker volumes.
$BitlockerVolumes = Get-BitLockerVolume

# Get the Recovery Key for each volume and store it in IT Glue
$BitlockerVolumes |
    ForEach-Object {
        $MountPoint = $_.MountPoint 
        $RecoveryKey = [string]($_.KeyProtector).RecoveryPassword
	#This section builds the password details with the following:
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
        	name = "Bitlocker Key for $MountPoint"
        	password = $RecoveryKey
        	resource_id = $varITGlueDevice.'id'
        	resource_type = 'Configuration'
		}
	}
        if ($RecoveryKey.Length -gt 5) {
		    #This line retrieves the old password using the organization, configuration name, and password name (will not error if no password is found)
		    $OldBLPass = Get-ITGluePasswords -filter_organization_id $varITGlueDevice.attributes.'organization-id' -filter_cached_resource_name $varITGlueDevice.attributes.name -filter_name "Bitlocker Key for $MountPoint"
		    #Checks if the url for the config matches with the parent url of the embedded password - if so, the password is updated, if not then the password is created
		    If ($OldBLPass.data.attributes.'parent-url' -eq $varITGlueDevice.attributes.'resource-url') {
		        write-host "Existing Bitlocker recovery key found in ITGlue - confirming if changed..."
		            If ((Get-ITGluePasswords -id ($OldBLPass.data.id) -show_password 1).data.attributes.password -eq $RecoveryKey) {
			           write-host "The recorded BitLocker recovery key for $MountPoint is current."
		           }
		          Else {
		                write-host "The BitLocker key for $MountPoint has changed - updating record in IT Glue."
		                Set-ITGluePasswords -id $OldBLpass.data.id -data $data
		            }
		    }
		    Else {
		        write-host "The Bitlocker key for $MountPoint has not been recorded.  Saving record to ITGlue."
		        New-ITGluePasswords -data $data
		    }
        }
        else {
            write-host "Volume $mountpoint is not encrypted."
        }        
    }


