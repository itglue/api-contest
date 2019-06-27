Import-Module ITGlueAPI -global

function connect-Office365{

	param(
		[string] $name
	)

	$passwords = @()
	$org_ids = @()
	
	$orgs = @()
	
	$page = 0
	
	while ($true){
		$data = Get-ITGluePasswords -filter_password_category_id 126358 -page_number $page
		
		$passwords += $data.data
		
		if ($data.meta.'next-page'){
			$page = $data.meta.'next-page'
		}else{
			break
		}
	}
	
	foreach ($password in $passwords){
		if ($org_ids -notcontains $password.attributes.'organization-id'){
			$org_ids += $password.attributes.'organization-id'
		}
	}
	
	foreach ($id in $org_ids){
		$data = (Get-ITGlueOrganizations -filter_id $id).Data.attributes
		
		if ($data.'organization-status-id' -ne 10022){
			continue;
		}
		
		$orgs += [pscustomobject]@{'name' = $data.name; 'sn' = $data.'short-name'; 'id' = $id}
	}
	
	$org = $orgs | Where-Object {$_.name -like ("*$name*") -or $_.sn -like ("*$name*")}

	if ($org.Length -eq 0){
		Write-host ("No client matching " + $name + " found")
		return;
	}

	$id = 0;

	while ($org.Length -gt 1){
		Write-host ("" + $org.length + " results found. Please select:")
		for ($i = 0; $i -lt $org.Length; $i++){
			Write-host ("" + ($i+1)	+ ": " + $org[$i].name + " (" + $org[$i].sn + ")")
		}
		
		$id = (Read-Host "Select") - 1
		
		if (($id -ge 0) -and ($id -lt $org.Length)){ break}
	}
	
	
	$passwords = @()
	$total = 0;
	$page = 0
	while ($true){
		$data = (Get-ITGluePasswords -organization_id $org[$id].id -filter_password_category_id 126358 -page_number $page)
		
		$total = $data.meta.'total-count'
		
		if ($total -eq 0){
			Write-host "No passwords found"
			return;
		}
		
		$passwords += $data.data
		
		
		if ($data.meta.'next-page'){
			$page = $data.meta.'next-page'
		}else{
			break
		}
	}

	$id = 0;

	while ($total -gt 1){
		Write-host ("" + $total + " results found. Please select:")
		for ($i = 0; $i -lt $total; $i++){
			Write-host ("" + ($i+1) + ": " + $passwords[$i].attributes.name + " (" + $passwords[$i].attributes.username + ")")
		}
		
		$id = (Read-Host "Select") - 1
		
		if (($id -ge 0) -and ($id -lt $passwords.Length)){ break}
	}

	$acc = (Get-ITGluePasswords -id $passwords[$id].id -show_password $true).Data

	$username = $acc.Attributes.username
	$password = ($acc.Attributes.password | ConvertTo-SecureString -asPlainText -Force)

	$UserCredential = New-Object System.Management.Automation.PSCredential($username,$password)

	$script:Session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri https://outlook.office365.com/powershell-liveid/ -Credential $UserCredential -Authentication Basic -AllowRedirection

	Connect-MsolService -Credential $UserCredential
	Import-Module (Import-PSSession $script:Session -DisableNameChecking -AllowClobber) -Global
	Connect-AzureAD -Credential $UserCredential
	
}
#Export-ModuleMember -Function DHS-connectOffice365