# Script name: ITGlue-VMHost-CreateFlexibleAsset.ps1
# Script type: Powershell
# Script description: Creates a custom Flexible Asset called "VMHost". Use "ITGlue-VMHost-CreateFlexibleAsset.ps1" to update.
# Dependencies: Powershell 3.0
# Script maintainer: powerpack@upstream.se
# https://en.upstream.se/powerpack/
# --------------------------------------------------------------------------------------------------------------------------------

$data = @{
    type = "flexible_asset_types"
    Attributes = @{
        icon = "cubes"
        description = "This Flexible Asset is to be used to automate VM host documentation."
        Name = "VM Host"
        enabled = $true
    }
    relationships = @{
        flexible_asset_fields = @{
            data = @(
                @{
                    type = "flexible_asset_fields"
                    Attributes = @{
                        order = 1
                        Name = "VM host name"
                        kind = "Text"
                        hint = "This is the unique name and identifier of this Flexible Asset. It has to match the actual name of the VM Host to be docuemented with the associated Powershell script."
                        required = $true
                        use_for_title = $true
                        expiration = $false
                        show_in_list = $true
                    }
                },
                @{
                    type = "flexible_asset_fields"
                    Attributes = @{
                        order = 2
                        Name = "VM host configuration"
                        kind = "Header"
                        required = $false
                        use_for_title = $false
                        expiration = $false
                        show_in_list = $true
                    }
                },
                @{
                    type = "flexible_asset_fields"
                    Attributes = @{
                        order = 3
                        Name = "VM host related IT Glue configuration"
                        kind = "Tag"
                        tag_type = "Configurations"
                        required = $true
                        use_for_title = $false
                        expiration = $false
                        show_in_list = $true
                    }
                },
                @{
                    type = "flexible_asset_fields"
                    Attributes = @{
                        order = 4
                        Name = "Virtualization platform"
                        kind = "Select"
                        required = $false
                        use_for_title = $false
                        expiration = $false
                        show_in_list = $true
                        default_value = "Hyper-V
VMware"
                    }
                },
                @{
                    type = "flexible_asset_fields"
                    Attributes = @{
                        order = 5
                        Name = "CPU"
                        kind = "Number"
                        required = $false
                        use_for_title = $false
                        expiration = $false
                        show_in_list = $false
                        default_value = ""
                    }
                },
                @{
                    type = "flexible_asset_fields"
                    Attributes = @{
                        order = 6
                        Name = "RAM (GB)"
                        kind = "Number"
                        required = $false
                        use_for_title = $false
                        expiration = $false
                        show_in_list = $false
                        default_value = ""
                    }
                },
                @{
                    type = "flexible_asset_fields"
                    Attributes = @{
                        order = 7
                        Name = "Disk information"
                        kind = "Textbox"
                        required = $false
                        use_for_title = $false
                        expiration = $false
                        show_in_list = $false
                        default_value = ""
                    }
                },
                @{
                    type = "flexible_asset_fields"
                    Attributes = @{
                        order = 8
                        Name = "Virtual switches"
                        kind = "Textbox"
                        required = $false
                        use_for_title = $false
                        expiration = $false
                        show_in_list = $false
                        default_value = ""
                    }
                },
                @{
                    type = "flexible_asset_fields"
                    Attributes = @{
                        order = 9
                        Name = "VM guests configuration"
                        kind = "Header"
                        required = $false
                        use_for_title = $false
                        expiration = $false
                        show_in_list = $true
                    }
                },
                @{
                    type = "flexible_asset_fields"
                    Attributes = @{
                        order = 10
                        Name = "Current number of VM guests on this VM host"
                        kind = "Number"
                        hint = "Number of guests detected on this VM host based on latest execution of the ducumentation atutomation script."
                        required = $false
                        use_for_title = $false
                        expiration = $false
                        show_in_list = $true
                        default_value = ""
                    }
                },
                @{
                    type = "flexible_asset_fields"
                    Attributes = @{
                        order = 11
                        Name = "VM guest names and information"
                        kind = "Textbox"
                        hint = "VM guest names vCPUs RAM and other infromation."
                        required = $false
                        use_for_title = $false
                        expiration = $false
                        show_in_list = $false
                        default_value = ""
                    }
                },
                @{
                    type = "flexible_asset_fields"
                    Attributes = @{
                        order = 12
                        Name = "VM guest virtual disk paths"
                        kind = "Textbox"
                        hint = "VM guests and virtual disk paths discovered on this VM host."
                        required = $false
                        use_for_title = $false
                        expiration = $false
                        show_in_list = $false
                        default_value = ""
                    }
                },
                @{
                    type = "flexible_asset_fields"
                    Attributes = @{
                        order = 13
                        Name = "VM guests snapshot information"
                        kind = "Textbox"
                        hint = "All snapshots found on the host"
                        required = $false
                        use_for_title = $false
                        expiration = $false
                        show_in_list = $false
                        default_value = ""
                    }
                },
                @{
                    type = "flexible_asset_fields"
                    Attributes = @{
                        order = 14
                        Name = "VM guests BIOS settings"
                        kind = "Textbox"
                        hint = "Specifies the BIOS boot settings in each each discovered guest on this VM host."
                        required = $false
                        use_for_title = $false
                        expiration = $false
                        show_in_list = $false
                        default_value = ""
                    }
                },
                @{
                    type = "flexible_asset_fields"
                    Attributes = @{
                        order = 15
                        Name = "Assigned virtual switches and IP information"
                        kind = "Textbox"
                        required = $false
                        use_for_title = $false
                        expiration = $false
                        show_in_list = $false
                        default_value = ""
                    }
                },
                @{
                    type = "flexible_asset_fields"
                    Attributes = @{
                        order = 16
                        Name = "Force manual sync now?"
                        kind = "Select"
                        required = $false
                        use_for_title = $false
                        expiration = $false
                        show_in_list = $false
                        default_value = "Yes
No"
                    }
                },
                @{
                    type = "flexible_asset_fields"
                    Attributes = @{
                        order = 17
                        Name = "This automated documentation is powered by Upstream Power Pack"
                        kind = "Header"
                        required = $false
                        use_for_title = $false
                        expiration = $false
                        show_in_list = $true
                    }
                }
            )
        }
    }
}


New-ITGlueFlexibleAssetTypes -data $data