$url = 'https://secrets.xxxxxxxxxxxx.com/webservices/sswebservice.asmx';
$username = 'xxxxxxxxx'
$password = 'xxxxxxxxx'
$domain = 'xxxxxxxxxxx'   # leave blank for local users
$idlist = Get-Content -Path C:\temp\rerun.txt
$proxy = New-WebServiceProxy -uri $url -UseDefaultCredential
$result1 = $proxy.Authenticate($username, $password, '', $domain)

#set up log variable
$Savedata = @() 

#ITGlue api url
$hostitg = 'https://api.itglue.com'

#ITGlue API key
$apikeyitg = 'ITG.xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx'

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

foreach($secretId in $idlist){
$id
    $action= "NONE???"

    $result2 = $proxy.GetSecret($token, $secretId, $false, $null)
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
                $secretId
                $shortname
                $itgposturl
                $result2.Secret.Name
                $result2.Secret.Items[0].FieldName
                $result2.Secret.Items[0].Value
                $result2.Secret.Items[1].FieldName
                $result2.Secret.Items[1].Value
                $result2.Secret.Items[2].FieldName
                $result2.Secret.Items[2].Value
                $result2.Secret.Items[3].FieldName
                $result2.Secret.Items[3].Value
                $secretpass = $result2.Secret.Items[2].Value;
                if(($secretpass -eq "") -or ($secretpass -eq $null)){$secretpass = "NONE"}

                $urlforthis = $result2.Secret.Items[0].Value
                if(($urlforthis -notlike "http*") -or ($urlforthis -notlike "//") ){$urlforthis = ""}
                #if((isURI($urlforthis)) -ne $true) {$urlforthis = ""}

                if($urlforthis -ne ""){
              $postjson =  @{"data" = @{"type" = "passwords";
               "attributes" = @{
               "name"=($result2.Secret.Name.ToCharArray | select -first 140) -join "";
                "username"= $result2.Secret.Items[1].Value;
                "password" = $secretpass;
                "url" = $urlforthis;
                "notes" = $result2.Secret.Items[3].Value}}}
                }else{
                $postjson =  @{"data" = @{"type" = "passwords";
               "attributes" = @{
               "name"=($result2.Secret.Name.ToCharArray | select -first 140) -join "";
                "username"= $result2.Secret.Items[1].Value;
                "password" = $secretpass;       
                "notes" = $result2.Secret.Items[3].Value}}}
                }
            
                $postjson =  $postjson | ConvertTo-Json

                $postjson
                $postresponse = ""
                $postresponse = Invoke-RestMethod -Uri $itgposturl -Method Post -Header $headersitg -Body $postjson -TimeoutSec 500
                $postresponse.data.attributes
                $action = $postresponse.data.attributes.'resource-url'
            
                
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
    } 

}
$SaveData | export-csv -Path c:\temp\thyotic11.csv -NoTypeInformation