[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$url = 'https://secrets.xxxxxxxx.com/webservices/sswebservice.asmx';
$username = 'xxxxxxxx'
$password = 'xxxxxxxx'
$domain = 'xxxxxxxxxx'   # leave blank for local users
#$idlist = Get-Content -Path C:\temp\rerun.txt
$proxy = New-WebServiceProxy -uri $url -UseDefaultCredential
$result1 = $proxy.Authenticate($username, $password, '', $domain)

#set up log variable
$Savedata = @() 

#ITGlue api url
$hostitg = 'https://api.itglue.com'

#ITGlue API key
$apikeyitg = 'ITG.xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx'

#Set up headers for ITglue api transactions
$headersitg = New-Object "System.Collections.Generic.Dictionary[[String],[String]]" 
$headersitg.Add("x-api-key", $apikeyitg)
$headersitg.Add("Content-Type",'application/vnd.api+json')

#url for all ITglue organizations
$url5 = $hostitg + "/organizations?page[number]=1&page[size]=1000"
$url5b = $hostitg + "/organizations?page[number]=2&page[size]=1000"
$url5c = $hostitg + "/organizations?page[number]=3&page[size]=1000"

#get all organizations from ITGlue
$allitgorgs =@()
$allitgorgs += Invoke-RestMethod -Uri $url5 -Method Get -Header $headersitg -TimeoutSec 500
$allitgorgs += Invoke-RestMethod -Uri $url5b -Method Get -Header $headersitg -TimeoutSec 500
$allitgorgs += Invoke-RestMethod -Uri $url5c -Method Get -Header $headersitg -TimeoutSec 500


if ($result1.Errors.length -gt 0){
$result1.Errors[0]
exit
} 
else 
{
$token = $result1.Token
}
$count = 7566
$maxcount = 10000

$username = ""
                $secretpass = ""
                $urlforthis = ""
                $notes = ""
                $urlforthis = ""
$count
    $action= "NONE???"

    $result2 = $proxy.GetSecret($token, $count, $false, $null)
    if ($result2.Errors.length -gt 0){
        $result2.Errors[0]
    }
    else
    {
    $SaveData += New-Object PSObject 
        if($result2.Secret.Active -eq $true){
            $orgid =  ""
            $shortname = $result2.Secret.Name.Substring(0,4)
            $shortname = $shortname.Trim(" ")


            [string]$orgid = $allitgorgs.data | ? {$_.attributes.'short-name' -like $shortname} | select "id"

            if(($orgid -ne "")-and ($orgid -ne $null)){
                $itgposturl = $hostitg + "/organizations/" + $orgid.TrimStart("@{id=").TrimEnd("}") + "/relationships/passwords"
                

                

                foreach($attrib in $result2.Secret.Items){
                    if($attrib.FieldName -eq "Username"){$username = $attrib.Value}
                    if($attrib.FieldName -eq "Password"){$secretpass = $attrib.Value}
                    if($attrib.FieldName -eq "Notes"){$notes = $attrib.Value}
                    if($attrib.FieldName -like "Login URL*"){$urlforthis = $attrib.Value}

                }


                if(($secretpass -eq "") -or ($secretpass -eq $null)){$secretpass = "NONE"}

                $urlforthis = $result2.Secret.Items[0].Value
                if(($urlforthis -notlike "http*") -or ($urlforthis -notlike "*//*") ){$urlforthis = ""}
                 $body = @{
                "filter[name]" = $result2.Secret.Name
               
                }
                $itggetorgpassurl = $hostitg + "/organizations/" + $orgid.TrimStart("@{id=").TrimEnd("}") + "/relationships/passwords"
                $recordfound =  Invoke-RestMethod -Uri $itggetorgpassurl -Method Get -Header $headersitg -body $body -TimeoutSec 500
                $itgpatchurl =""
                if($recordfound.data -ne $null){
                $itgpatchurl = $hostitg + "/passwords/" + $recordfound.data[0].id
                $recordfound.data[0].id
                
                }

                if($urlforthis -ne ""){
                    $postjson =  @{"data" = @{"type" = "passwords";
                   "attributes" = @{
                   "name"=$result2.Secret.Name;
                    "username"= $username;
                    "password" = $secretpass;
                    "url" = $urlforthis;
                    "notes" = $notes}}}
                }else{
                    $postjson =  @{"data" = @{"type" = "passwords";
                   "attributes" = @{
                   "name"=$result2.Secret.Name;
                    "username"= $username;
                    "password" = $secretpass;       
                    "notes" = $notes}}}
                }

                if($urlforthis -ne ""){
                    $patchjson =  @{"data" = @{"type" = "passwords";
                    "attributes" = @{
                   "name"=$result2.Secret.Name;
                    "username"= $username;
                    "password" = $secretpass;
                    "url" = $urlforthis;
                    "notes" = $notes}}}
                }else{
                    $patchjson =  @{"data" = @{"type" = "passwords";
                    "attributes" = @{
                   "name"=$result2.Secret.Name;
                    "username"= $username;
                    "password" = $secretpass;       
                    "notes" = $notes}}}
                }
            
                $postjson =  $postjson | ConvertTo-Json
                $patchjson =  $patchjson | ConvertTo-Json
              
                $response = ""

                if($itgpatchurl -eq ""){
                $response = Invoke-RestMethod -Uri $itgposturl -Method Post -Header $headersitg -Body $postjson -TimeoutSec 500
                $action = $response.data.attributes.'resource-url'
                $postjson
                $response
                }else{
                 $response = Invoke-RestMethod -Uri $itgpatchurl -Method Patch -Header $headersitg -Body $patchjson -TimeoutSec 500
                 $action = "PATCH DATA"
                 $patchjson
                 $response
                }

                
            
                
            }else{
                $secretId
                $shortname
                $action = "ORG not Found in Glue. " + $shortname
                "Org not Found in Glue"
                #pause
            }
        }else{
            $action = "Skip"
            "Skipping - " + $secretId + " - Active Flag is : " + $result2.Secret.Active
        }
    $SaveData | Add-Member -Name secretid -MemberType NoteProperty -Value $secretId -erroraction 'silentlycontinue'
    $SaveData | Add-Member -Name active -MemberType NoteProperty -Value $result2.Secret.Active -erroraction 'silentlycontinue'
    $SaveData | Add-Member -Name Action -MemberType NoteProperty -Value $action -erroraction 'silentlycontinue'
    $SaveData | Add-Member -Name Name -MemberType NoteProperty -Value $result2.Secret.Name -erroraction 'silentlycontinue'
    $SaveData | Add-Member -Name User -MemberType NoteProperty -Value $username -erroraction 'silentlycontinue'
    $SaveData | Add-Member -Name Pass -MemberType NoteProperty -Value $secretpass -erroraction 'silentlycontinue'
    $SaveData | Add-Member -Name URL -MemberType NoteProperty -Value $urlforthis -erroraction 'silentlycontinue'
    
    } 


$SaveData | export-csv -Path c:\temp\thyoticupdate2.csv -NoTypeInformation