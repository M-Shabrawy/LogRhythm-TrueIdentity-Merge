Function Get-LRIdentities
{
	param(
		[string] [Parameter(Mandatory=$true)] $ApiUrl,
		[string] [Parameter(Mandatory=$true)] $ApiKey,
		[string] $Filter,
		[long] $EntityId,
		[int] $Count = 25,
		[int] $Page = 1,
		[bool] $ShowRetired
	)
	
	$Offset = ($Page - 1) * $Count
	$Url = $ApiUrl + "identities?count=" + $Count + "&offset=" + $Offset
	if ($ShowRetired) { $Url += "&showRetired=true&recordStatus=Retired" }
	if ($Filter) { $Url += "&$Filter" }
	
	$Headers = @{
		"Authorization" = ("Bearer " + $ApiKey); 
	}

	try 
	{
		# API Call to add the collaborator
		$Response = Invoke-RestMethod -method GET -uri $Url -headers $Headers
	}
	catch 
	{
		try {
			$reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
			$reader.BaseStream.Position = 0
			$reader.DiscardBufferedData()
			$responseBody = $reader.ReadToEnd()
		
			$ApiError = " (URL: $Url, status code " + $_.Exception.Response.StatusCode.value__ + ', description: ' + $_.Exception.Response.StatusDescription + ', body: ' + $responseBody + ')'
		} catch {
			$ApiError = " (URL: $Url, error unknown)"
		}
		$Message = "ERROR: Failed to call API to get Identities." + $ApiError
		write-host $Message
		return $false
	}
	
	if ($Response.Count -eq $Count)
	{
		# Need to get next page results
		$NextPage = $Page + 1
		return $Response + (Get-LRIdentities -ApiUrl $ApiUrl -ApiKey $ApiKey -Page $NextPage -Count $Count -ShowRetired $ShowRetired)
	}
	# Will return $null if no Identities are found matching the filter
	return $Response
}

Function Get-LRIdentityById
{
	param(
		[string] [Parameter(Mandatory=$true)] $ApiUrl,
		[string] [Parameter(Mandatory=$true)] $ApiKey,
		[long] [Parameter(Mandatory=$true)] $IdentityId
	)
	
	$Url = $ApiUrl + "identities/" + $IdentityId
	
	$Headers = @{
		"Authorization" = ("Bearer " + $ApiKey); 
	}

	try 
	{
		# API Call to add the collaborator
		$Response = Invoke-RestMethod -method GET -uri $Url -headers $Headers
	}
	catch 
	{
		try {
			$reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
			$reader.BaseStream.Position = 0
			$reader.DiscardBufferedData()
			$responseBody = $reader.ReadToEnd()
		
			$ApiError = " (URL: $Url, status code " + $_.Exception.Response.StatusCode.value__ + ', description: ' + $_.Exception.Response.StatusDescription + ', body: ' + $responseBody + ')'
		} catch {
			$ApiError = " (URL: $Url, error unknown)"
		}
		$Message = "ERROR: Failed to call API to get Identities." + $ApiError
		write-host $Message
		return $false
	}
	
	return $Response
}


Function Retire-LRIdentity
{
	param(
		[string] $ApiUrl,
		[string] $ApiKey,
		[long] $IdentityId,
		[string] $RecordStatus = "Retired"
	)
	
	$Url = $ApiUrl + "identities/" + $IdentityId + "/status"
	
	$Headers = @{
		"Authorization" = ("Bearer " + $ApiKey); 
	}
	
	$Body = '{"recordStatus": "' + $RecordStatus + '"}'
	
	try 
	{
		# API Call to add the collaborator
		$Response = Invoke-RestMethod -method PUT -uri $Url -headers $Headers -Body $Body
		return $true
	}
	catch 
	{
		try {
			$reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
			$reader.BaseStream.Position = 0
			$reader.DiscardBufferedData()
			$responseBody = $reader.ReadToEnd()
		
			$ApiError = " (URL: $Url, status code " + $_.Exception.Response.StatusCode.value__ + ', description: ' + $_.Exception.Response.StatusDescription + ', body: ' + $responseBody + ')'
		} catch {
			$ApiError = " (URL: $Url, error unknown)"
		}
		$Message = "`t`tERROR: Failed to call API to Retire Identity Id $IdentityId" + $ApiError
		write-host $Message
		return $false
	}
}


# Params
# 	Attributes : Object	
# 		Required Keys: nameFirst, nameLast, displayIdentifier, vendorUniqueKey
#	Identifiers : Array of Objects
#		{ identifierType="Login or Email", value="" }
# 		E.G. $Identifiers = $( @{ "identifierType"="Login"; "value"="bruce.deakyne" }, @{"identifierType"="Email"; "value"="bruce.deakyne@logrhythm.com" } )

function Add-LRIdentity
{
	param(
		[string] $ApiUrl,
		[string] $ApiKey,
		[string] $EntityId,
		[string] $SyncName,
		$Attributes,
		$Identifiers,
		[bool] $WhatIf
	)
	
	$Url = $ApiUrl + "identities/bulk?entityID=" + $EntityId
		
	$Headers = @{
		"Authorization" = ("Bearer " + $ApiKey); 
	}
	
	# For error messages
	$IdentityDisplay = "'$($Attributes.nameFirst) $($Attributes.nameLast) ($($Attributes.displayIdentifier))'"
	
	# Ensure there is at least one Identifier
	if ($Identifiers.Count -lt 1)
	{
		write-host "ERROR: Could not create Identity $IdentityDisplay. No Identifiers were defined"
		return $null
	} 
	
	$Body = @{}
	$Body.friendlyName = $SyncName
	
	$RequiredAttributes = $("nameFirst", "nameLast", "displayIdentifier", "vendorUniqueKey")
	# List of the Attributes we're going to send in the API Request
	$AttributesToSync = $("nameFirst", "nameMiddle", "nameLast", "displayIdentifier", "vendorUniqueKey", "title", "company", "department", "manager", "accountType", "thumbnailPhoto")
	$Account = @{}
	foreach ($Attribute in $AttributesToSync)
	{
		if ($RequiredAttributes -contains $Attribute -and $Attributes.$Attribute.Length -eq 0)
		{
			write-host "Identity $IdentityDisplay was missing required attribute '$Attribute' and not synced"
			return $null
		} elseif ($Attributes.$Attribute.Length -gt 0) {
			$Account.$Attribute = $Attributes.$Attribute
		}	
	}

	$Account.identifiers = @($Identifiers)
	$Body.accounts = @($Account)
	
	if ($WhatIf)
	{
		return $true
	}
	
	try 
	{
		# API Call to add the collaborator
		$Response = Invoke-RestMethod -method POST -uri $Url -headers $Headers -Body ($Body | ConvertTo-Json -Depth 5)
	}
	catch 
	{
		try {
			$reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
			$reader.BaseStream.Position = 0
			$reader.DiscardBufferedData()
			$responseBody = $reader.ReadToEnd()
		
			$ApiError = " (URL: $Url, status code " + $_.Exception.Response.StatusCode.value__ + ', description: ' + $_.Exception.Response.StatusDescription + ', body: ' + $responseBody + ')'
		} catch {
			$ApiError = " (URL: $Url, error unknown)"
		}
		$Message = "ERROR: Failed to call API to Add Identity '$firstName $lastName ($displayIdentifier)'" + $ApiError
		write-host $Message
		return $null
	}
	
	if ($Response -and $Response.Count -gt 0)
	{
		return $Response[0].identityId
	} else {
		return $null
	}
}


function Add-LRIdentifierToIdentity
{
	param(
		[string] [Parameter(Mandatory=$true)] $ApiUrl,
		[string] [Parameter(Mandatory=$true)] $ApiKey,
		[string] [Parameter(Mandatory=$true)] $IdentityId,
		[string] $IdentifierType = "Login",
		[string] [Parameter(Mandatory=$true)] $IdentifierValue
	)
	
	$Url = $ApiUrl + "identities/" + $IdentityId + "/identifiers" 
		
	$Headers = @{
		"Authorization" = ("Bearer " + $ApiKey); 
	}

	$Body = '{"value":  "' + $IdentifierValue + '", "identifierType":  "' + $IdentifierType + '"}'
	
	try 
	{
		# API Call to add the collaborator
		$Response = Invoke-RestMethod -method POST -uri $Url -headers $Headers -Body $Body
	}
	catch 
	{
		try {
			$reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
			$reader.BaseStream.Position = 0
			$reader.DiscardBufferedData()
			$responseBody = $reader.ReadToEnd()
		
			$ApiError = " (URL: $Url, status code " + $_.Exception.Response.StatusCode.value__ + ', description: ' + $_.Exception.Response.StatusDescription + ', body: ' + $responseBody + ')'
		} catch {
			$ApiError = " (URL: $Url, error unknown)"
		}
		$Message = "ERROR: Failed to call API to Add Identifier '$IdentifierValue' type '$IdentifierType' to Identity ID $IdentityId" + $ApiError
		write-host $Message
		return $null
	}
	
	return $true
}



Function Get-StringHash
{
	param(
		[String] $String,
		$HashName = "SHA1"
	)
	$StringBuilder = New-Object System.Text.StringBuilder
	[System.Security.Cryptography.HashAlgorithm]::Create($HashName).ComputeHash([System.Text.Encoding]::UTF8.GetBytes($String))|%{
		[Void]$StringBuilder.Append($_.ToString("x2"))
	}
	return $StringBuilder.ToString()
}


<#
.NAME
	Get-LRVersion
.DESCRIPTION
	Checks the installed version of a service (e.g. the ARM)
.PARAMETER
	Service: The service to check the version of
		Default "LogRhythm Alarming Manager"
.OUTPUTS
	Array of ints $(Major, Minor, Patch)
	$null if it cannot find the installed service
	
#>
function Get-LRVersion
{
	param(
		# By default, check the ARM
		[string] $Service = "LogRhythm Alarming Manager"
	)

	# e.g. 7.3.3.8000 
	$VersionPattern = '(?<major>[6-8])\.(?<minor>[\d]{1,2})\.(?<patch>[\d]{1,2})\.[\d]{1,5}'

	try {
		$RegLoc = (Get-ChildItem HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall)
		$lr = $RegLoc | ForEach-Object {Get-ItemProperty $_.PSPath } | Where-Object { $_.DisplayName -eq $Service -and $_.Publisher -eq "LogRhythm" } 
		if (($lr -eq $null) -or (-not $lr.DisplayVersion))
		{
			# Service not found
			return $null
		}
		
		$VersionMatch = $lr.DisplayVersion -match $VersionPattern
		if (-not $VersionMatch)
		{
			# Don't recognize the version
			return $null
		}
		
		return $([convert]::ToInt32($Matches.major), [convert]::ToInt32($Matches.minor), [convert]::ToInt32($Matches.patch))
	}
	catch {
		return $null
	}

}

<#
.SYNOPSIS
	Check-LRVersion
.DESCRIPTION
	Ensures the installed LR Version is greater than or equal to the Major/Minor/Path provided
.PARAMETER Major
	Major (int): Major version. 7 in LR 7.3.4 
.PARAMETER Minor
	Minor (int): Minor version. 3 in LR 7.3.4
.PARAMETER Patch
	Patch (int): Patch version. 4 in LR 7.3.4
.OUTPUTS
	$True if the installed LR Version is greater than or equal to the Major/Minor/Path provided
	$False if the installed LR Version is less than the Major/Minor/Path provided
	$Null if the version can't be determined
#>
function Check-LRVersion
{
	param(
		[int] [Parameter(Mandatory=$true)] $Major,
		[int] [Parameter(Mandatory=$true)] $Minor,
		[int] [Parameter(Mandatory=$true)] $Patch
	)
	
	$CurrentVersion = Get-LRVersion
	if ($CurrentVersion -eq $null)
	{
		# Couldn't find the ARM service on this machine (i.e. it's not the Platform Manager)
		return $null
	}
	
	# Consider a version "Long" like 7.3.3 as 070303
	$CurrentVersionLong = ($CurrentVersion[0] * [math]::pow(10,4)) + ($CurrentVersion[1] * [math]::pow(10,2)) + ($CurrentVersion[2] * [math]::pow(10,0))
	$RequiredVersionLong = ($Major * [math]::pow(10,4)) + ($Minor * [math]::pow(10,2)) + ($Patch * [math]::pow(10,0))
	
	if ($CurrentVersionLong -ge $RequiredVersionLong)
	{
		return $true
	} else {
		return $false
	}
}

function Get-LRIdentityDisplay
{
	param(
		[Parameter(Mandatory=$true)] $Identity
	)
	return "'$($Identity.nameFirst) $($Identity.nameLast) ($($Identity.displayIdentifier))'"
}

Function Get-LRIdentifierConflics
{
	param(
		[string] [Parameter(Mandatory=$true)] $ApiUrl,
		[string] [Parameter(Mandatory=$true)] $ApiKey,
		[string] $Filter,
		[long] $EntityId,
		[bool] $ShowRetired
	)
	
	$Identifiers = @{}
	# Simple array - will contain the Identifier/Type combo of any conflicts
	$Conflicts = @()
	
	$SearchingIdententities = $True
	$Page = 1
	$Count = 100
	
	$Headers = @{
		"Authorization" = ("Bearer " + $ApiKey); 
	}
	
	while ($SearchingIdententities -eq $True) {
		$Offset = ($Page - 1) * $Count
		$Url = $ApiUrl + "identities?count=" + $Count + "&offset=" + $Offset
		if ($ShowRetired) { $Url += "&showRetired=true" }
		if ($Filter) { $Url += "&$Filter" }
		
		try 
		{
			# API Call to add the collaborator
			$Response = Invoke-RestMethod -method GET -uri $Url -headers $Headers
		}
		catch 
		{
			try {
				$reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
				$reader.BaseStream.Position = 0
				$reader.DiscardBufferedData()
				$responseBody = $reader.ReadToEnd()
			
				$ApiError = " (URL: $Url, status code " + $_.Exception.Response.StatusCode.value__ + ', description: ' + $_.Exception.Response.StatusDescription + ', body: ' + $responseBody + ')'
			} catch {
				$ApiError = " (URL: $Url, error unknown)"
			}
			$Message = "ERROR: Failed to call API to get Identities." + $ApiError
			write-host $Message
			$SearchingIdententities = $False
			break;
		}
		
		if ($Response.Count -eq 0) {
			$SearchingIdententities = $False
			break;
		} elseif ($Response.Count -lt $Count) {
			$SearchingIdententities = $False
		}
		
		foreach ($Identity in $Response)
		{
			if ($EntityId -and $Identity.entity.entityId -ne $EntityId)
			{
				# This Identity is not in our Entity, ignore it
				# Unfortunately, we couldn't filter by Entity as the filter in the API query params is the Entity name, not ID
				continue;
			}
			
			foreach ($Identifier in $Identity.Identifiers)
			{
				# Filter inactive
				if ($Identifier.recordStatus -eq "Retired") 
				{
					continue;
				}
				
				# Form the Value/Type key
				$IdentifierKey = $Identifier.value + '|' + $Identifier.identifierType
				$IdentifierMetadata = @{ "IdentityId" = $Identity.identityId; "IdentifierId" = $Identifier.identifierID; "Source" = $Identifier.source.IAMName }
				
				
				
				# See if the Identifier record exists
				if ($Identifiers[$IdentifierKey] -eq $null)
				{
					# If not, create it
					$Identifiers[$IdentifierKey] = @()
				} elseif ($Conflicts -notcontains $IdentifierKey)
				{
					# The Identifier already had a record
					# But there's no record of a conflict
					# We need to check if the other records contain a different IdentityId
					$HasConflict = (@($Identifiers[$IdentifierKey] | ? { $_.IdentityId -ne $Identity.identityId }).Count -gt 0)
					if ($HasConflict)
					{
						$Conflicts += $IdentifierKey
					}
				}
				
				$Identifiers[$IdentifierKey] += $IdentifierMetadata			
			}
		
		}
		
		$Page = $Page + 1
	}
	
	$IdentifiersWithConflicts = $Identifiers.GetEnumerator() | ? { $Conflicts -contains $_.Name }
	return $IdentifiersWithConflicts
}

$Is74 = Check-LRVersion -Major 7 -Minor 4 -Patch 0
if ($Is74 -eq $False)
{
	$Version = Get-LRVersion
	write-error "LogRhythm Version 7.4+ is required. '$($Version -join ".")' detected"
	Exit 1
}
