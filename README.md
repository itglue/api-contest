# api-contest
# LAPS for All
#
# Short description:
# LAPS for All creates a unique password for the local admin account on a Windows workstation and saves the password to ITGlue.
# 
# Long Description:
# LAPS for All integrates DattoRMM endpoints with their corresponding ITGlue configurations and sets a unique local admin password for each machine.  The password for each system 
# is saved within the ITGlue platform as an embedded password attached to the configuration. This script is designed specifically for the functionaility available inside the DattoRMM and 
# ITGlue platforms and may not be able to be ported to other RMM platforms.
#
# 
# LAPSforALL.ps1 - The main powershell script
# LAPS for ALL Export.cpt - Component for DattoRMM.  This component is normally what would be used. This component would imported into the DattoRMM platform, and then ran from DattoRMM.
#
#
# Items of note:
#   1) This will work for all endpoints, including those not on domains.
#   2) Passwords are unique for each device and stored inside of the device's ITGlue configuration.
#   3) All required prequisites are automatically installed as needed. (Installation of .Net Framework and PowerShell 5.0 is handled outside the scope of the script.)
#   4) Required components are automatically updated to the latest available version.
#   5) Passwords are dynamically created utilizing the web security functions from .Net framework.
#   7) Local admin account name can be customized.  (This is used for both the local account on the machine and the name of the embedded password entry in ITGlue.)
#   8) Customizable max age for local admin password.  (Only passwords older than the max age will be reset/updated.)
#   9) Option to disable other local accounts on the endpoint. (This will only function on domain joined PCs.)
#  10) Safety checks in place to make sure that this script will not execute on servers.
#  11) If the ITGlue configuration cannot be found, no changes password or account changes will be made.
#  12) If PowerShell module logging is enabled, the script will automatically exit to prevent sensitive information from being recorded in the Windows Event logs.
#  13) The script logs changes and status to std-out.
#
#
#
#
#
# *There is no number 6 - ref: https://tvtropes.org/pmwiki/pmwiki.php/Main/ThereIsNoRuleSix