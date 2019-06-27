function searchClients{
	Param ([string]$name)
	
	$result = @()
	$page = 0;
	
	while ($true){
		$temp = Get-ITGlueOrganizations -page_number $page
		
		$result += $temp.data
		
		if ($temp.meta.'next-page'){
			$page = $temp.meta.'next-page'
		}else{
			break
		}
	}
	
	if ($name){
		$result =  ($result | Where ({$_.attributes.name -like ('*'+$name+'*') -or $_.attributes.'short-name' -like ('*'+$name+'*')}))
	}
	
	
	return ($result | Where ({($_.attributes.'organization-status-id' -eq 10022) -and ((Get-ITGlueFlexibleAssets -filter_flexible_asset_type_id 34494 -filter_organization_id $_.id).meta.'total-count' -ne 0)}))
}

function getConnections{
	param(
		[System.Array] $nodes
	)
	
	if ($nodes.Type -eq "Connection"){
		return $nodes
	}else{
		$result = @();
		foreach ($node in $nodes.node){
			$result += getConnections $node
		}
		return $result
	}
}

function import-MRemoteList{
	param(
		[System.Array] $path
	)
	if ($path){
		[xml]$xml = Get-Content -Path $path
	}else{
		[xml]$xml = Get-Content -Path .\confCons.xml
	}
	
	$list = @{}
	
	#read in customers
	foreach ($subnode in $xml.connections.node){
		foreach ($client in $subnode.node){
			$shortname = ([regex]::match($client.name, '^(\w+)\s')).groups[1].value
			
			if ($list.keys -notcontains $shortname){
				$list[$shortname] = @{};
			}
			
			$servers = (getConnections $client.node).where({$_.Hostname -match '^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$' -and $_.Name -match '^\S*$' -and $_.protocol -eq 'RDP'})
			
			Foreach ($server in $servers){
				if ($list[$shortname].keys -notcontains $server.name){
					$list[$shortname][$server.name] = [pscustomobject]@{'Name' = $server.name; 'Local' = ''; 'NAT' = ''}
				}
				
				if ($server.hostname -match '^10\.70\.'){
					if ($list[$shortname][$server.name].NAT){
						#Write-Host ("Two NAT entries for server " + $server.name) -foregroundcolor red
					}else{
						$list[$shortname][$server.name].NAT = $server.hostname
					}
				}else{
					if ($list[$shortname][$server.name].Local){
						#Write-Host ("Two local entries for server " + $server.name) -foregroundcolor red
					}else{
						$list[$shortname][$server.name].Local = $server.hostname
					}
				}
			}
		}
	}
	
	return $list
}

function get-DClist {
	Param ([string] $client_input)
	
	$list = import-MRemoteList

	$ADDetails = (Get-ITGlueFlexibleAssets -filter_flexible_asset_type_id 34494).Data

	$clients = (DHS-searchClients $client_input).attributes.'short-name'

	$DCresult = @{}

	Foreach ($ad in $ADDetails) { 
		$client = (Get-ITGlueOrganizations -filter_id $ad.attributes.'organization-id')
		
		if ($clients -notcontains $client.data[0].attributes.'short-name'){
			continue;
		}
		
		if ($client.meta.'total-count' -eq 0){
			Write-Host ("Client " + $ad.attributes.'organization-name' + " not found") -foregroundcolor red
			continue;
		}
		
		if ($client.data[0].attributes.'organization-status-id' -ne 10022){
			continue;
		}
		
		$client = $client.data[0].attributes
		
		if (!$client.'short-name'){
			continue;
		}
		
		if ($list.keys -notcontains $client.'short-name'){
			$list[$client.'short-name'] = @{}
		}
		
		$servers = $ad.attributes.traits.'ad-servers'.values
		
		foreach ($server in $servers){
			#Write-Host ("Server: " + $server.name + " (" + $server.'organization-name' + " " + $client.'short-name' + ")")
			if ($list[$client.'short-name'].keys -notcontains $server.name){
				#Write-Host ("Server not found: " + $server.name + " at " + $client.'name') -foregroundcolor red
				continue
			}
			
			if ($DCresult.keys -notcontains $client.'short-name'){
				$DCresult[$client.'short-name'] = @()
			}
			
			$DCresult[$client.'short-name'] += $list[$client.'short-name'][$server.name]
		}
		
		#Write-Host 
	}
	
	return $DCResult
}


function get-ADPasswords{
	param(
		[string] $company
	)
	
	$clients = DHS-searchClients $company
	
	$result = @{}
	
	foreach ($client in $clients){
		#Write-Host $client
		if (!$client.attributes.'short-name'){
			continue
		}
		
		$passglue = (Get-ITGluePasswords -filter_password_category_id 77992 -organization_id $client.id)
		
		if ($client.attributes.'organization-status-name' -ne 'Active'){
			continue;
		}
		
		if ($passglue.meta.'total-count' -eq 0){
			Write-host ("`tNo passwords found for client " + $client.attributes.name) -ForegroundColor Red
			continue;
		}
		
		$creds = @();

		foreach ($password in $passglue.data){
			$password = (Get-ITGluePasswords -id $password.id -show_password $true).data
			
			if (!($password.attributes.username) -or !($password.attributes.password)){
				continue;
			}
			
			$username = $password.attributes.username
			$ss_pass = ConvertTo-SecureString $password.attributes.password -AsPlainText -Force
			
			$credential = New-Object System.Management.Automation.PSCredential ($username, $ss_pass)
			
			$creds += @{"user" = $username; "cred" = $credential}
		}
		
		$result[$client.attributes.'short-name'] = $creds
	}
	
	return $result
}

function connect-AD{

	param(
		[string] $company
	)

	while (!$company){
		$company = Read-Host "Please input a company name"
	}
	
	$companies = searchClients $company | Where ({$_.attributes.'short-name' -ne $null})
	
	if (!$companies){
		Write-Host ("No match found for " + $company)
		return
	}
	
	
	if ($companies -is [system.array]){
		$id = 0;

		while ($companies.Length -gt 1){
			Write-host ("" + $companies.length + " results found. Please select:")
			for ($i = 0; $i -lt $companies.Length; $i++){
				Write-host ("" + $i + ": " + $companies[$i].attributes.name)
			}
			
			$id = Read-Host "Select"
			
			if (($id -ge 0) -and ($id -lt $companies.Length)){ break}
		}
		
		$comp = $companies[$id].attributes
	}else{
		$comp = $companies.attributes
	}
	
	$passwords = (get-ADPasswords $comp.name)[$comp.'short-name']
	
	$servers = (get-DClist $comp.name)[$comp.'short-name']
	
	foreach ($server in $servers){
		foreach ($password in $passwords){
			try {
				if ($server.NAT){
					$user = Get-ADUser $password.user -server $server.NAT -credential $password.cred
					return [pscustomobject] @{'Server' = $server.NAT; 'User' = $password.user; 'Credential' = $password.cred}
				}else{
					$user = Get-ADUser $password.user -server $server.Local -credential $password.cred
					return [pscustomobject] @{'Server' = $server.Local; 'User' = $password.user; 'Credential' = $password.cred}
				}
			} catch {
			
			}
		}
	}
		
	Write-host ("Error: not able to get a connection to " + $comp.name) -foregroundcolor red
	return
}