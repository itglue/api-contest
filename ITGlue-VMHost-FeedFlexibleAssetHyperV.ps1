#Requires -Version 3
#Requires -Modules @{ ModuleName="ITGlueAPI"; ModuleVersion="2.0.7" }


[cmdletbinding()]
param(
    [Parameter(HelpMessage='The id of the asset in IT Glue')]
    [long]$flexible_asset_id,

    [Parameter(HelpMessage='IT Glue api key')]
    [string]$api_key,

    [Parameter(HelpMessage='Where is your data stored? EU or US?')]
    [ValidateSet('US', 'EU')]
    [string]$data_center,

    [Parameter(HelpMessage='The first part of your IT Glue URL when logging in in ')]
    [string]$subdomain
)

# Import the IT Glue wrapper module
Import-Module ITGlueAPI -ErrorAction Stop

# If any parameter is missing ...
# (Cannot use mandatory because it would break setting parameters inside the script.)

if($api_key) {
    try {
        Write-Verbose "Decrypting API key."
        $api_key = [PSCredential]::new('null', ($api_key | ConvertTo-SecureString -ErrorAction Stop)).GetNetworkCredential().Password
        Write-Verbose "Decrypted and stored."
    } catch {
        Write-Verbose "API key not encrypted."
    }

    # Set API key for this sessions
    Write-Verbose "Using specified API key."
    Add-ITGlueAPIKey -api_key $api_key
} elseif(!$api_key -and $ITGlue_API_Key) {
    # Use API key imported from module settings
    Write-Verbose "Using API key from module settings already saved."
} else {
    return "No API key was found or specified, please use -api_key to specify it and run the script again. This script will not continue."
}

if($data_center) {
    # Set URL for this sessions
    Write-Verbose "Using specified data center $data_center for this session."
    Add-ITGlueBaseURI -data_center $data_center
} elseif(!$data_center -and $ITGlue_Base_URI) {
    # Use URL imported from module settings
    Write-Verbose "Using URL from module settings already saved."
} else {
    return "No data center was found or specified, please use -data_center to specify it (US or EU) and run the script again. This script will not continue."
}

if(!$flexible_asset_id) {
    return "flexible_asset_id is missing. Please specify it and run the script again. This script will not continue."
}

# Flexible asset to update
Write-Verbose "Retreving IT Glue flexible asset id: $flexible_asset_id..."
$flexibleAsset = Get-ITGlueFlexibleAssets -id $flexible_asset_id
Write-Verbose "Done."

# The asset's organization id
Write-Verbose "Retreving organization id..."
$organization_id = $flexibleAsset.data.attributes.'organization-id'
Write-Verbose "Done."

Write-Verbose "Formating URL..."
$url = (Get-ITGlueBaseURI).replace('https://api', 'https://{0}' -f $subdomain)
Write-Verbose "Done."

Write-Verbose "Retrieving configurations from IT Glue (org id: $organization_id)..."
$configurations = @{}
$page_number = 1
do{
    Write-Verbose "Calling the IT Glue api (page $page_number)..."
    $api_call = Get-ITGlueConfigurations -organization_id $organization_id -page_size 1000 -page_number ($page_number++)
    foreach($_ in $api_call.data) {
        $configurations[$_.attributes.name] = $_
    }
} while($api_call.links.next)
Write-Verbose "Done."

# All VMs on the host (with some data)
Write-Verbose "Creating hashtable with HTML name and rest of data..."
$VMs = @{}
foreach($vm in Get-VM) {
    $htmlname = $vm.name

    if($configurations[$vm.Name]) {
        $htmlname = '<a href="{0}/{1}/configurations/{2}">{3}</a>' -f $url,  $configurations[$vm.Name].attributes.'organization-id',  $configurations[$vm.Name].id, $vm.name 
    } else {
        $configurations.GetEnumerator() | Where {$_.Name -like "*$($vm.name)*"} | ForEach-Object {
            $htmlname = '<a href="{0}/{1}/configurations/{2}">{3}</a>' -f $url,  $_.value.attributes.'organization-id',  $_.value.id, $vm.name
        }
    }
    

    $VMs[$vm.name] = [PSCustomObject]@{
        name = $vm.name
        vm = $vm
        htmlname = $htmlname
    }
}
Write-Verbose "Done."

# Hyper-V host's disk information / "Disk information"
Write-Verbose "Getting host's disk data..."
$diskDataHTML = '<div>
    <table>
        <tbody>
            <tr>
                <td>Disk name</td>
                <td>Total(GB)</td>
                <td>Used(GB)</td>
                <td>Free(GB)</td>
            </tr>
            {0}
        </tbody>
    </table>
</div>' -f ((Get-PSDrive -PSProvider FileSystem).foreach{
    '<tr>
        <td>{0}</td>
        <td>{1}</td>
        <td>{2}</td>
        <td>{3}</td>
    </tr>' -f $_.Root, [math]::round(($_.free+$_.used)/1GB), [math]::round($_.used/1GB), [math]::round($_.free/1GB)} | Out-String)
Write-Verbose "Host's disk data done. [1/7]"

# Virtual swtiches / "Virtual switches"
Write-Verbose "Getting virtual swtiches..."
$virtualSwitchsHTML = '<div>
    <table>
        <tbody>
            <tr>
                <td>Name</td>
                <td>Switch type</td>
                <td>Interface description</td>
            </tr>
            {0}
        </tbody>
    </table>
</div>' -f ((Get-VMSwitch).foreach{
    '<tr>
        <td>{0}</td>
        <td>{1}</td>
        <td>{2}</td>
    </tr>' -f $_.Name, $_.SwitchType, $_.NetAdapterInterfaceDescription} | Out-String)
Write-Verbose "Virtual swtiches done. [2/7]"

# General information about virtual machines / "VM guest names and information"
Write-Verbose "Getting general guest information..."
$guestInformationHTML = '<div>
    <table>
        <tbody>
            <tr>
                <td>VM guest name</td>
                <td>Start action</td>
                <td>RAM (GB)</td>
                <td>vCPU</td>
                <td>Size (GB)</td>
            </tr>
            {0}
        </tbody>
    </table>
</div>' -f ($VMs.GetEnumerator().foreach{
    $diskSize = 0
    ($_.value.vm.HardDrives | Get-VHD).FileSize.foreach{$diskSize += $_}
    $diskSize = [Math]::Round($diskSize/1GB)
    '<tr>
        <td>{0}</td>
        <td>{1}</td>
        <td>{2}</td>
        <td>{3}</td>
        <td>{4}</td>
    </tr>' -f $_.value.htmlname, $_.value.vm.AutomaticStartAction, [Math]::Round($_.value.vm.MemoryStartup/1GB), $_.value.vm.ProcessorCount, $diskSize} | Out-String)
Write-Verbose "General guest information done. [3/7]"

# Virutal machines' disk file locations / "VM guest virtual disk paths"
Write-Verbose "Getting VM machine paths..."
$virtualMachinePathsHTML = '<div>
    <table>
        <tbody>
            <tr>
                <td>VM guest name</td>
                <td>Path</td>
            </tr>
            {0}
        </tbody>
    </table>
</div>' -f ($VMs.GetEnumerator().foreach{
    '<tr>
        <td>{0}</td>
        <td>{1}</td>
    </tr>' -f $_.value.htmlname, ((Get-VHD -id $_.value.vm.id).path | Out-String).Replace([Environment]::NewLine, '<br>').TrimEnd('<br>')} | Out-String)
Write-Verbose "VM machine paths done. [4/7]"

# Snapshot data / "VM guests snapshot information"
Write-Verbose "Getting snapshot data..."
$vmSnapshotHTML = '<div>
    <table>
        <tbody>
            <tr>
                <td>VMName</td>
                <td>Name</td>
                <td>Snapshot type</td>
                <td>Creation time</td>
                <td>Parent snapshot name</td>
            </tr>
            {0}
        </tbody>
    </table>
</div>' -f ((Get-VMSnapshot -VMName * | Sort VMName, CreationTime).foreach{
    '<tr>
        <td>{0}</td>
        <td>{1}</td>
        <td>{2}</td>
        <td>{3}</td>
        <td>{4}</td>
    </tr>' -f $VMs[$_.VMName].htmlname, $_.Name, $_.SnapshotType, $_.CreationTime, $_.ParentSnapshotName} | Out-String)
Write-Verbose "Snapshot data done. [5/7]"

# Virutal machines' bios settings / "VM guests BIOS settings"
Write-Verbose "Getting VM BIOS settings..."
# Generation 1
$vmBiosSettingsTableData = (Get-VMBios * -ErrorAction SilentlyContinue).foreach{
    '<tr>
        <td>{0}</td>
        <td>{1}</td>
        <td>{2}</td>
        <td>{3}</td>
        <td>Gen 1</td>
    </tr>' -f $VMs[$_.VMName].htmlname, ($_.StartupOrder | Out-String).Replace([Environment]::NewLine, ', ').TrimEnd(', '), 'N/A', 'N/A'}
Write-Verbose "Generation 1 done..."

# Generation 2
$vmBiosSettingsTableData += (Get-VMFirmware * -ErrorAction SilentlyContinue).foreach{
    '<tr>
        <td>{0}</td>
        <td>{1}</td>
        <td>{2}</td>
        <td>{3}</td>
        <td>Gen 2</td>
    </tr>' -f $VMs[$_.VMName].htmlname, ($_.BootOrder.BootType | Out-String).Replace([Environment]::NewLine, ', ').TrimEnd(', '), $_.PauseAfterBootFailure, $_.SecureBoot}
Write-Verbose "Generation 2 done..."

$vmBIOSSettingsHTML = '<div>
    <table>
        <tbody>
            <tr>
                <td>VM guest name</td>
                <td>Startup order</td>
                <td>Pause After Boot Failure</td>
                <td>Secure Boot</td>
                <td>Generation</td>
            </tr>
            {0}
        </tbody>
    </table>
</div>' -f ($vmBiosSettingsTableData | Out-String)
Write-Verbose "VM BIOS settings done. [6/7]"

# Guest NICs and IPs
Write-Verbose "Getting VM NICs..."
$guestNICsIPsHTML = '<div>
    <table>
        <tbody>
            <tr>
                <td>VM guest name</td>
                <td>Swtich name</td>
                <td>IPv4</td>
                <td>IPv6</td>
            </tr>
            {0}
        </tbody>
    </table>
</div>' -f ((Get-VMNetworkAdapter * | Sort 'VMName').foreach{
    '<tr>
        <td>{0}</td>
        <td>{1}</td>
        <td>{2}</td>
        <td>{3}</td>
    </tr>' -f $VMs[$_.VMName].htmlname, $_.switchname, $_.ipaddresses[0], $_.ipaddresses[1]} | Out-String)
Write-Verbose "VM NICs done. [7/7]"


$data = @{
    type = 'flexible-assets'
    attributes = @{
        traits = @{
            # Manual sync
            'force-manual-sync-now' = 'No'
            # Host platform
            'virtualization-platform' = 'Hyper-V'
            # Host CPU data
            'cpu' = Get-VMHost | Select -ExpandProperty LogicalProcessorCount
            # Host RAM data
            'ram-gb' = ((Get-CimInstance CIM_PhysicalMemory).capacity | Measure -Sum).Sum/1GB
            # Host disk data
            'disk-information' = $diskDataHTML
            # Virutal network cards (vNIC)
            'virtual-switches' = $virtualSwitchsHTML
            # Number of VMs on host
            'current-number-of-vm-guests-on-this-vm-host' = ($VMs.GetEnumerator() | measure).Count
            # General VM data (start type, cpu, ram...)
            'vm-guest-names-and-information' = $guestInformationHTML
            # VMs' name and VHD paths
            'vm-guest-virtual-disk-paths' = $virtualMachinePathsHTML
            # Snapshop data
            'vm-guests-snapshot-information' = $vmSnapshotHTML
            # VMs' bios settings
            'vm-guests-bios-settings' = $vmBIOSSettingsHTML
            # NIC and IP assigned to each VM
            'assigned-virtual-switches-and-ip-information' = $guestNICsIPsHTML
        }
    }
}
Write-Verbose "Finished build hash table."


Write-Verbose "Comparing data.."

$update = $false

if($flexibleAsset.data.attributes.traits.'force-manual-sync-now' -eq 'Yes') {
    $update = $true
} elseif($data.attributes.traits.cpu -ne $flexibleAsset.data.attributes.traits.cpu) {
    Write-Verbose "Change detected. Will update asset."
    $update = $true
} elseif($data.attributes.traits.'ram-gb' -ne $flexibleAsset.data.attributes.traits.'ram-gb') {
    Write-Verbose "Change detected. Will update asset."
    $update = $true
} elseif(($data.attributes.traits.'disk-information'.replace("`n","").replace("`r","")) -ne ($flexibleAsset.data.attributes.traits.'disk-information'.replace("`n","").replace("`r",""))) {
    Write-Verbose "Change detected. Will update asset."
    $update = $true
} elseif(($data.attributes.traits.'virtual-switches'.replace("`n","").replace("`r","")) -ne ($flexibleAsset.data.attributes.traits.'virtual-switches'.replace("`n","").replace("`r",""))) {
    Write-Verbose "Change detected. Will update asset."
    $update = $true
} elseif($data.attributes.traits.'current-number-of-vm-guests-on-this-vm-host' -ne $flexibleAsset.data.attributes.traits.'current-number-of-vm-guests-on-this-vm-host') {
    Write-Verbose "Change detected. Will update asset."
    $update = $true
} elseif(($data.attributes.traits.'vm-guest-names-and-information'.replace("`n","").replace("`r","")) -ne ($flexibleAsset.data.attributes.traits.'vm-guest-names-and-information'.replace("`n","").replace("`r",""))) {
    Write-Verbose "Change detected. Will update asset."
    $update = $true
} elseif(($data.attributes.traits.'vm-guest-virtual-disk-paths'.replace("`n","").replace("`r","")) -ne ($flexibleAsset.data.attributes.traits.'vm-guest-virtual-disk-paths'.replace("`n","").replace("`r",""))) {
    Write-Verbose "Change detected. Will update asset."
    $update = $true
} elseif(($data.attributes.traits.'vm-guests-snapshot-information'.replace("`n","").replace("`r","")) -ne ($flexibleAsset.data.attributes.traits.'vm-guests-snapshot-information'.replace("`n","").replace("`r",""))) {
    Write-Verbose "Change detected. Will update asset."
    $update = $true
} elseif(($data.attributes.traits.'vm-guests-bios-settings'.replace("`n","").replace("`r","")) -ne ($flexibleAsset.data.attributes.traits.'vm-guests-bios-settings'.replace("`n","").replace("`r",""))) {
    Write-Verbose "Change detected. Will update asset."
    $update = $true
} elseif(($data.attributes.traits.'assigned-virtual-switches-and-ip-information'.replace("`n","").replace("`r","")) -ne ($flexibleAsset.data.attributes.traits.'assigned-virtual-switches-and-ip-information'.replace("`n","").replace("`r",""))) {
    Write-Verbose "Change detected. Will update asset."
    $update = $true
}

if($update) {
    Write-Verbose "Begin updating asset.."

    $data["attributes"]["id"] = $flexible_asset_id
    Write-Verbose "Added id to hash table."
    # Visible name
    $data["attributes"]["traits"]["vm-host-name"] = $flexibleAsset.data.attributes.traits.'vm-host-name'
    Write-Verbose "Added VM host name to hash table."
    # Tagged asset (i.e the host)
    $data["attributes"]["traits"]["vm-host-related-it-glue-configuration"] = $flexibleAsset.data.attributes.traits.'vm-host-related-it-glue-configuration'.Values.id
    Write-Verbose "Added VM host related IT Glue configuration to hash table."

    Write-Verbose "Uploading data for id $flexible_asset_id."
    $resp =  Set-ITGlueFlexibleAssets -data $data
    Write-Verbose "Uploading data: done."
    return $resp
} else {
    Write-Verbose "No change detected. Not updating."
}