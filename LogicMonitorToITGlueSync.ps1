#Logic monitor accessID
$accessId ='XXXXXXXXXXXXXXXXXXXXX'

#Logicmonitor accesskey
$accessKey = 'XXXXXXXXXXXXXXXXXXXXXXXXXX'

#company name on logicmonitor
$company = 'ciosolutions'

#Logicmonitor function for header
$httpVerb = 'GET'

#path on logicmonitor to run function on
$resourcePath =  '/device/devices'

#set up log variable
$Savedata = @()

#ITGlue api url
$hostitg = 'https://api.itglue.com'

#ITGlue API key
$apikeyitg = 'ITG.XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXxxx'

#Set up headers for ITglue api transactions
$headersitg = New-Object "System.Collections.Generic.Dictionary[[String],[String]]" 
$headersitg.Add("x-api-key", $apikeyitg)
$headersitg.Add("Content-Type",'application/vnd.api+json')

#Logic monitor limits to 300 per transaction, Our logicmonitor has 600+ so we run through 3 times
$url = 'https://' + $company + '.logicmonitor.com/santaba/rest' + $resourcePath + '?size=300&filter=id<424'
$url2 = 'https://' + $company + '.logicmonitor.com/santaba/rest' + $resourcePath + '?size=300&filter=id>424'
$url3 = 'https://' + $company + '.logicmonitor.com/santaba/rest' + $resourcePath + '?size=300&filter=id>794'

#compile headers and authentication for getting logicmonitor configuration list
$epoch = [Math]::Round((New-TimeSpan -start (Get-Date -Date "1/1/1970") -end (Get-Date).ToUniversalTime()).TotalMilliseconds)
$requestVars = $httpVerb + $epoch + $resourcePath
$hmac = New-Object System.Security.Cryptography.HMACSHA256
$hmac.Key = [Text.Encoding]::UTF8.GetBytes($accessKey)
$signatureBytes = $hmac.ComputeHash([Text.Encoding]::UTF8.GetBytes($requestVars))
$signatureHex = [System.BitConverter]::ToString($signatureBytes) -replace '-'
$signature = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($signatureHex.ToLower()))
$auth = 'LMv1 ' + $accessId + ':' + $signature + ':' + $epoch
$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("Authorization",$auth)
$headers.Add("Content-Type",'application/json')

#Get up to 300 device from logicmonitor api per request
$response = Invoke-RestMethod -Uri $url -Method Get -Header $headers -TimeoutSec 500
$response2 = Invoke-RestMethod -Uri $url2 -Method Get -Header $headers -TimeoutSec 500
$response3 = Invoke-RestMethod -Uri $url3 -Method Get -Header $headers -TimeoutSec 500 

#Put all the logic monitor data into 1 large array
$body = $response.data.items
$body +=  $response2.data.items
$body +=  $response3.data.items

#url for all ITglue organizations
$url5 = $hostitg + "/organizations?page[number]=1&page[size]=1000"
$url5b = $hostitg + "/organizations?page[number]=2&page[size]=1000"
$url5c = $hostitg + "/organizations?page[number]=3&page[size]=1000"

#get all organizations from ITGlue
$response5 =@()
$response5 += Invoke-RestMethod -Uri $url5 -Method Get -Header $headersitg -TimeoutSec 500
$response5 += Invoke-RestMethod -Uri $url5b -Method Get -Header $headersitg -TimeoutSec 500
$response5 += Invoke-RestMethod -Uri $url5c -Method Get -Header $headersitg -TimeoutSec 500

#Loop through each logicmonitor device
foreach($item in $body){
    
    #Check if device is a windows server
    if($item.manualDiscoveryFlags.winprocess -eq "True"){

        #we are not looking for windows servers, so add to log and do nothing else
        $SaveData += New-Object PSObject 
        $SaveData | Add-Member -Name Name -MemberType NoteProperty -Value $item.displayName -erroraction 'silentlycontinue'  
        $SaveData | Add-Member -Name Action -MemberType NoteProperty -Value "None" -erroraction 'silentlycontinue'  
        $SaveData | Add-Member -Name Status -MemberType NoteProperty -Value "windows server not processed" -erroraction 'silentlycontinue'
          
    }else{ #not windows server, proceed

        #url to device's properties in logicmonitor
        $resourcePath2 = '/device/devices' + '/' + $item.id + '/properties'

        #compile headers and authentication for getting full list of single device properties
        $requestVars2 = $httpVerb + $epoch + $resourcePath2
        $signatureBytes2 = $hmac.ComputeHash([Text.Encoding]::UTF8.GetBytes($requestVars2))
        $signatureHex2 = [System.BitConverter]::ToString($signatureBytes2) -replace '-'
        $signature2 = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($signatureHex2.ToLower()))
        $auth2 = 'LMv1 ' + $accessId + ':' + $signature2 + ':' + $epoch
        $headers2 = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
        $headers2.Add("Authorization",$auth2)
        $headers2.Add("Content-Type",'application/json')

        #full url to device's properties in logicmonitor
        $url4 = 'https://' + $company + '.logicmonitor.com/santaba/rest' + $resourcePath2

        #Get full list of properties for current device iteration
        $response4 = Invoke-RestMethod -Uri $url4 -Method Get -Header $headers2 -TimeoutSec 500 

        #Device Serial number from logic monitor
        [string]$lmserial = $response4.data.items | ? {$_.name -eq "auto.serialnumber"} |Select "value"
        
        #Trim serial of json characters
        $lmserial = $lmserial.TrimStart('@{value=').TrimEnd('}')

        #is there a serial number?
        if($lmserial -eq ""){

            #no serial from logicmonitor do nothing but log
            $SaveData += New-Object PSObject
            $SaveData | Add-Member -Name Name -MemberType NoteProperty -Value $item.displayName -erroraction 'silentlycontinue' 
            $SaveData | Add-Member -Name Action -MemberType NoteProperty -Value "None" -erroraction 'silentlycontinue'  
            $SaveData | Add-Member -Name Status -MemberType NoteProperty -Value "No Serial Number in Logicmonitor" -erroraction 'silentlycontinue' 

        }else{#serial found, proceed
            
            #reset org variables
            $organization = ""
            $orgid = ""

            #Get organization name from logicmonitor data
            [string]$organization = $response4.data.items | ? {$_.name -eq "connectwise.companyid"} |Select "value"

            #trim json characters
            $organization = $organization.TrimStart('@{value=').TrimEnd('}')
           
            #match organization name to itglue, and get coresponding org id
            [string]$orgid = $response5.data | ? {$_.attributes.'short-name' -like $organization} | select "id"
            
            #trim json characters 
            $orgid = $orgid.TrimStart('@{id=').TrimEnd('}')    

            #url to the selected organization's itglue configuration list
            $url6 = $hostitg + "/organizations/" + $orgid + "/relationships/configurations?page[number]=1&page[size]=1000"
            $url6b = $hostitg + "/organizations/" + $orgid + "/relationships/configurations?page[number]=2&page[size]=1000"
            $url6c = $hostitg + "/organizations/" + $orgid + "/relationships/configurations?page[number]=3&page[size]=1000"

            #Get all configs for selected org from itglue
            $response6 = @()
            $response6 +=  Invoke-RestMethod -Uri $url6 -Method Get -Header $headersitg -TimeoutSec 500
            $response6 +=  Invoke-RestMethod -Uri $url6b -Method Get -Header $headersitg -TimeoutSec 500
            $response6 +=  Invoke-RestMethod -Uri $url6c -Method Get -Header $headersitg -TimeoutSec 500
                
            #get name from logicmonitor data
            [string]$name = $response4.data.items | ? {$_.name -eq "system.displayname"} |Select "value" 

            #trim json characters
            $name = $name.TrimStart('@{value=').TrimEnd('}')
           
            #get hostname from logicmonitor data
            [string]$hostname = $response4.data.items | ? {$_.name -eq "system.hostname"} |Select "value" 

            #trim json characters
            $hostname = $hostname.TrimStart('@{value=').TrimEnd('}')
            
            #Get ITGlue type id from logicmonitor
            [string]$configtypeid = $response4.data.items | ? {$_.name -eq "itglue.type"} |Select "value" 

            #trim json characters
            $configtypeid = $configtypeid.TrimStart('@{value=').TrimEnd('}')
          
            #set config status to active
            $configstatus = 'Active'
     
            #get ip address from logic monitor data            
            [string]$primaryip = $response4.data.items | ? {$_.name -eq "system.ips"} |Select "value" 

            #trim json characters
            $primaryip = $primaryip.TrimStart('@{value=').TrimEnd('}')
       
            #Get Model information from logicmonitor data
            [string]$model = $response4.data.items | ? {$_.name -eq "auto.model"} |Select "value"
            
            #trim json characters 
            $model = $model.TrimStart('@{value=').TrimEnd('}')
          
            #get firmware from logicmonitor data
            [string]$os = $response4.data.items | ? {$_.name -eq "auto.firmware"} |Select "value"
              
            #trim json characters
            $os = $os.TrimStart('@{value=').TrimEnd('}')
     
            #get sysinfo from logicmonitor
            [string]$osnotes = $response4.data.items | ? {$_.name -eq "system.sysinfo"} |Select "value"
            
            #trim json characters 
            $osnotes = $osnotes.TrimStart('@{value=').TrimEnd('}')
     
            #reset itgluevendorid
            $itgluevendorid = ""

            #try to get manufacturer info from logic monitor
            [string]$manufacturer = $response4.data.items | ? {$_.name -eq "auto.manufacturer"} |Select "value"

            #check if auto.manufacturer got data
            if($manufacturer -eq ""){
                #try to get manufacturer info from system.vendor inlogicmonitor instead
                $manufacturer = $response4.data.items | ? {$_.name -eq "system.vendor"} |Select "value"
            }#if($manufacturer -eq ""

            #trim json characters
            $manufacturer = $manufacturer.TrimStart('@{value=').TrimEnd('}')

            #check if vendor is dell, if so, set appropriate id
            if($manufacturer.StartsWith("Dell")){
                $manufacturer = "Dell"
                $itgluevendorid = 15898
            }#if($manufacturer.StartsWith("Dell")

            #check if vendor is HP, if so, set appropriate id
            if($manufacturer.StartsWith("HP")){
                $manufacturer = "Hewlett Packard"
                $itgluevendorid = 394468
            }

            #check if vendor is LENOVO, if so, set appropriate id
            if($manufacturer.StartsWith("LENOVO")){
                $manufacturer = "Lenovo"
                $itgluevendorid = 15907
            }#if($manufacturer.StartsWith("LENOVO")

            #check if vendor is Cisco, if so set appropriate id
            if($manufacturer.StartsWith("Cisco")){
                $manufacturer = "Cisco"
                $itgluevendorid = 15897
            }#if($manufacturer.StartsWith("Cisco")

            #check if vendor is Intel, if so set appropriate id
            if($manufacturer.StartsWith("Intel")){
                $manufacturer = "Intel"
                $itgluevendorid = 15904
            }#if($manufacturer.StartsWith("Intel")

           #check if vendor is Synology, if so set appropriate id
            if($manufacturer.StartsWith("synology")){
                $manufacturer = "Synology"
                $itgluevendorid = 548418
            }#if($manufacturer.StartsWith("synology")       

            #get sysname from logicmonitor data
            [string]$sysname = $response4.data.items | ? {$_.name -eq "system.sysname"} |Select "value" 

            #trim json characters
            $sysname = $sysname.TrimStart('@{value=').TrimEnd('}')
              
            #get manufacture date from logicmonitor data
            [string]$purchasedat = $response4.data.items | ? {$_.name -eq "auto.ManufactureDate"} |Select "value"
            
            #trim json characters
            $purchasedat  = $purchasedat.TrimStart('@{value=').TrimEnd('}')
            
            #get config interfaces ips from logicmonitor data
            [string]$configint = $response4.data.items | ? {$_.name -eq "system.ips"} |Select "value" 

            #trim json characters
            $configint  = $configint.TrimStart('@{value=').TrimEnd('}')
            
            #get macaddresses from logicmonitor data
            [string]$macaddress = $response4.data.items | ? {$_.name -eq "auto.macaddress"} |Select "value"
            
            #trim json characters 
            $macaddress  = $macaddress.TrimStart('@{value=').TrimEnd('}')

            #remove extra data from mac address when logicmonitor adds the octets to the begining
            if($macaddress.StartsWith("80")){
                $macaddress = $macaddress.Split(":")[5..10] -join "-"

            }#if($macaddress.StartsWith("80")

            #Get os version data from logicmonitor data
            [string]$sysversion = $response4.data.items | ? {$_.name -eq "system.version"} |Select "value" 

            #trim json characters 
            $sysversion  = $sysversion.TrimStart('@{value=').TrimEnd('}')

            #take os version data only before second "."
            $sysversion = $sysversion.split(".")[0..1]
                
            #reset os variables
            $itglueosid = ""
            $itglueosname = ""

            #if os is vmware, set appropriate code for version
            switch($sysversion){
                "VMware ESXi 4 0"{$itglueosid = 86;$itglueosname = "VMware ESXi 4.0"}
                "VMware ESXi 4 1"{$itglueosid = 87;$itglueosname = "VMware ESXi 4.1"}
                "VMware ESXi 5 0"{$itglueosid = 88;$itglueosname = "VMware ESXi 5.0"}
                "VMware ESXi 5 1"{$itglueosid = 89;$itglueosname = "VMware ESXi 5.1"}
                "VMware ESXi 5 5"{$itglueosid = 90;$itglueosname = "VMware ESXi 5.5"}
                "VMware ESXi 6 0"{$itglueosid = 91;$itglueosname = "VMware ESXi 6.0"}
            }#switch

            #preset to POST, will only change if a record is found
            $patchpost = "POST"

            #loop through each serial number in itglue organization's configuration list
            foreach($itgserial in $response6.data.attributes.'serial-number'){ 

                #try to match serial number
                if($itgserial -like $lmserial){

                    #serial number found, patch that record
                    $patchpost = "PATCH"
                                     
                    #set config id to matching itglue record
                    $itgconfigid = $response6.data | ?{$_.attributes.'serial-number' -eq $lmserial} |select "id"
                    
                    #since record was found, no need to look anymore    
                    break

                 }#if($itgserial -like $lmserial)

            }#foreach($itgserial in $response6.data.attributes.'serial-number')

            #loop through each hostname in itglue organization's configuration list
            foreach($itghostname in $response6.data.attributes.hostname){
                
                #check for hostname match
                if($itghostname -like $hostname){
                    
                    #hostname matched, patch that record
                    $patchpost = "PATCH"
                    
                    #set config id to matching itglue record
                    $itgconfigid = $response6.data | ?{$_.attributes.hostname -eq $hostname} |select "id"

                    #since record was found, no need to look anymore  
                    break

                 }#if($itghostname -like $hostname)
                        
            }#foreach($itghostname in $response6.data.attributes.hostname)
                
            #set POST url     
            $url7 = $hostitg + "/organizations/" + $orgid + "/relationships/configurations"

            #set PATCH url
            $url8 = $hostitg + "/configurations/" + $itgconfigid.id

            #PATCHING
            if($patchpost -eq "PATCH"){

                #create json compatible data array
                $body2 = @{"data" = @{"type" = "configurations";
                    "id" = $itgconfigid.id; #config id to patch
                    "attributes" = @{
                    "name" = $name;
                    "hostname" = $sysname;
                    "configuration_type_id" = $configtypeid;
                    "primary_ip" = $hostname;
                    "configuration-status-id" = 859;
                    "configuration-status-name" = "Active";
                    "serial_number" =$lmserial;
                    "model_name" = $model;
                    "operating_system_notes" = "Firmware: " + $os;
                    "notes" =  $notes;
                    "purchased_at" = $purchasedat;
                    "operating-system-id" = $itglueosid;
                    "operating-system-name" = $itglueosname;
                    "manufacturer-id" = $itgluevendorid;
                    "manufacturer-name" = $manufacturer;
                    "mac-address" = $macaddress;
                    "configuration_interfaces" = $configint}}}

                #convert array to json data
                $body2 = $body2 | ConvertTo-Json
                
                #Send json Patch data to ITGlue, any errors will be stored in $RestError   
                $response8 = Invoke-RestMethod -Uri $url8 -Method Patch -Header $headersitg -Body $body2 -TimeoutSec 500 -ErrorVariable RestError 
                
                #setup log array member for device (new row)
                $SaveData += New-Object PSObject

                #Add name to name column in log
                $SaveData | Add-Member -Name Name -MemberType NoteProperty -Value $name -erroraction 'silentlycontinue'
                
                #Add PATCH to Action column in log    
                $SaveData | Add-Member -Name Action -MemberType NoteProperty -Value $patchpost -erroraction 'silentlycontinue' 
                
                #Check for error     
                if($RestError){

                    #Add error to status column in log
                    $SaveData | Add-Member -Name Status -MemberType NoteProperty -Value $RestError[0..10]  -erroraction 'silentlycontinue' 
                    $name
                  
                }else{ #no error

                    #Add "Success" to status column in log
                    $SaveData | Add-Member -Name Status -MemberType NoteProperty -Value "Success" -erroraction 'silentlycontinue'
                     
                }#if($RestError)

            }#if($patchpost -eq "PATCH"

            #POSTING
            if($patchpost -eq "POST"){
                
                #create json compatible data array   
                $body3 = @{"data" = @{"type" = "configurations";
                    "attributes" = @{
                    "name" = $name;
                    "organization-id" = $orgid;
                    "organization-name" = $organization;
                    "hostname" = $sysname;
                    "configuration_type_id" = $configtypeid;
                    "primary_ip" = $hostname;
                    "configuration-status-id" = 859;
                    "configuration-status-name" = "Active";
                    "serial_number" =$lmserial;
                    "model_name" = $model;
                    "operating_system_notes" = "Firmware: " + $os ;
                    "notes" =  $notes;
                    "purchased_at" = $purchasedat;
                    "operating-system-id" = $itglueosid;
                    "operating-system-name" = $itglueosname;
                    "manufacturer-id" = $itgluevendorid;
                    "manufacturer-name" = $manufacturer;
                    "mac-address" = $macaddress;  
                    "configuration_interfaces" = $configint}}}

                #convert array to json data
                $body3 = $body3 | ConvertTo-Json
               
                #Send json POST data to ITGlue, any errors will be stored in $RestError     
                $response7 = Invoke-RestMethod -Uri $url7 -Method Post -Header $headersitg -Body $body3 -TimeoutSec 500 -ErrorVariable RestError 

                #setup log array member for device (new row)
                $SaveData += New-Object PSObject 

                #Add name to name column in log
                $SaveData | Add-Member -Name Name -MemberType NoteProperty -Value $name -erroraction 'silentlycontinue'
                
                #Add POST to Action column in log       
                $SaveData | Add-Member -Name Action -MemberType NoteProperty -Value $patchpost -erroraction 'silentlycontinue'
                
                #Check for error  
                if($RestError){
                    #Add error to status column in log
                    $SaveData | Add-Member -Name Status -MemberType NoteProperty -Value $RestError[0..10]  -erroraction 'silentlycontinue' 
                    $name
                    
                }else{#no error

                    #Add "Success" to status column in log
                    $SaveData | Add-Member -Name Status -MemberType NoteProperty -Value "Success" -erroraction 'silentlycontinue' 

                }#if($RestError)

            }#if($patchpost -eq "POST")

        }#if($lmserial -eq "")
        
    }#if($item.manualDiscoveryFlags.winprocess -eq "True")

}#foreach($item in $body)

#Write log data to csv file
$SaveData | export-csv -Path c:\temp\log1.csv -NoTypeInformation

