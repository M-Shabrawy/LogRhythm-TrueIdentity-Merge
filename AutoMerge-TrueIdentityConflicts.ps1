<#
.SYNOPSIS
	Get a list of Identifier Conflicts LR 7.4 
	Optionally output them to a file for further investigation
.DESCRIPTION
	A TrueIdentity "Conflict" is when two TrueIdentities share the same Identifier
	This is common if multiple Active Directory domains are synced; any user with an account in both Domains will likely create a Conflict
.PARAMETER ApiUrl
	Optional. The Admin API URL (including trailing /)
	Default: "http://localhost:8505/lr-admin-api/"
	Alternatives: "https://PM_IP:8501/lr-admin-api/" (ensure you have a trusted cert relationship between this machine and the PM)
.PARAMETER ApiKey
	Required. The API Key, obtained from the Client Console "Third Party Applications" tab
	Example: "eyJhbGciO...DT7bPKrhg"
.PARAMETER EntityId
	Optional long
	Only search for conflicts within this Root EntityId
	Recommended when IdentityEntitySegregation has been enabled in the Data Processor(s)
.PARAMETER WhatIf
	Optional switch. Enabling "WhatIf" (Preview Mode) will check for errors but not make any changes to the TrueIdentities
	Recommended before the initial run
.EXAMPLE
	.\Get-TrueIdentityConflicts.ps1 -ApiKey "ey..." 
	Get all TrueIdentity Conflicts
	Prints a summary
.EXAMPLE
	.\Get-TrueIdentityConflicts.ps1 -ApiKey "ey..." -EntityId 7
	Get TrueIdentity Conflicts in the Root Entity with ID 7
	Prints a summary and a list of all conflicts
#>
	
[CmdLetBinding()]
param( 
	[string] $ApiUrl = "http://localhost:8505/lr-admin-api/",
	[string] $ApiKey = "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1aWQiOi0xMDAsImp0aSI6IjVhZWQ1MmYxLWFlYzYtNGY0Ni1iMTUzLWI1ZTU0NDk0OTcyMCIsImNpZCI6IkM5NkZDNzYyLTIxMDAtNERGRC1BNEUzLTQ4NTZGRjc3NEQ3MSIsImlzcyI6ImxyLWF1dGgiLCJyaWQiOiJnbG9iYWxBZG1pbiIsInBpZCI6LTEwMCwic3ViIjoiTG9nUmh5dGhtQWRtaW4iLCJleHAiOjE1Nzk5NjYyNTMsImRlaWQiOjEsImlhdCI6MTU0ODQzMDI1M30.BEOZ5YrvgaivM7WMymF_MyHKMwXRDEX9CDLJB79qxA4P_iQIJ_Rz_g4GMDVBeb9Y0r1uB3tLhoT4xlZ7EcZNWl1J0XIEbwfGMWjlsDb6L8FUJReSHmCHHL7lcPKdjoI76xVLG255S3loAhUCxCUlPub-gUSrSueCP3CIDpEdPGarqbgtAJN-pkHVkL9L9YS4HlcrRMlpBsKlgFcwzX4O_GLSePOSC0EbN2YC2ccibiA-WzLUXFeuSIM1UC9F_7dTvcmgW32u8OamWMPiwvpXV8nHIQpGSpL31z2_01lYLW45rEgK_Z_uEV2nBviZBkWpGwgCY3fHc5bKrr4XjuOn6w",
	[long] $EntityId,
    [long] $Sessionid = (Get-Random),	
    [switch] $WhatIf,
    [string] $OutputFile = "C:\LogRhythm\TrueIdentity-Toolkit\Logs\TrueIdentity_conflicts.txt",
    [string] $OutputFileRand = ("C:\LogRhythm\TrueIdentity-Toolkit\Logs\TrueIdentity_conflicts_" + (Get-Date -format "dd-MMM-yyyy") + ".txt"),
	$MaxLogFileSizeBytes = 10*1000*1000     
)
	
# Common Components and Version Check
. .\TrueIdentity-Common.ps1

function Write-Log {
     [CmdletBinding()]
     param(
         [Parameter()]
         [ValidateNotNullOrEmpty()]
         [ValidateSet('Information','Warning','Error')]
         [string]$Severity = 'Information',
         
         [Parameter()]
         [ValidateNotNullOrEmpty()]
         [string]$Message
     )
 
     [pscustomobject]@{
         Time = (Get-Date -format "dd-MMM-yyyy HH:mm:ss.fff")
         SessionID = $Sessionid
         Severity = $Severity
         Message = $Message
     } | Export-Csv -Path $OutputFile -Append -NoTypeInformation
 }

# Check if OutputFile file exists
if (Test-Path $OutputFile)
    {
    # Check if the OutputFile is larger than the Max allowable log file size
    if ((Get-Item $OutputFile).Length -ge $MaxLogFileSizeBytes) {
        
        # If so, rotate the OutputFile to start fresh
        Write-Host ("Rotating logfile " + $OutputFile + " to " + $OutputFileRand) -ForegroundColor Yellow
        Rename-Item -Path $OutputFile -NewName $OutputFileRand
    }
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
	$Count = 25
	
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
			Write-Host $Message
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
	

$Conflicts = Get-LRIdentifierConflics -ApiUrl $ApiUrl -ApiKey $ApiKey
$Identities = @{}
$ConflictsWith = @{}

foreach ($Conflict in $Conflicts)
{
	$IdentifierDisplay = "'" + ($Conflict.Name -replace "\|", "', type '") + "'"
	foreach ($ConflictIdentity in $Conflict.Value)
	{
		$Id = $ConflictIdentity.IdentityId
		if (-not $Identities[$Id])
		{
			# Build a table that contains info about each Identity
			$Identities[$Id] = Get-LRIdentityById -ApiUrl $ApiUrl -ApiKey $ApiKey -IdentityId $Id
		}
		
		# Our goal is to output a complete list of conflicts
		# If an identifier is shared by more than 2 Identities, each conflicts with the other
		# E.g. if Identities a,b,c,d conflict with eachother, then we have a,b a,c a,d b,c c,d
		
		# So we build a list of every Identity an Identity conflicts with
		if (-not $ConflictsWith[$Id])
		{
			$ConflictsWith[$Id] = @()
		}
		foreach ($ConflictIdentityPair in $Conflict.Value) {
			
			$PairId = $ConflictIdentityPair.IdentityId
			if ($Id -eq $PairId)
			{
				continue;
			} 
			if ($ConflictsWith[$Id] -notcontains $PairId)
			{
				$ConflictsWith[$Id] += $PairId
			}
		}
	}
}
   if ($WhatIf)
   {
    Write-Host ("`r" + "`n" + "Running in WhatIf mode. No changes will be made.") -ForegroundColor Yellow
    Write-Log -Message ("Running in WhatIf mode. No changes will be made.") -Severity Information
   }
   if (!$Conflicts)
 {
    Write-Host ("`r" + "`n" + "No conflicts found.") -ForegroundColor Green
    Write-Log -Message ("No conflicts found.") -Severity Information
 }

# Let's show the conflicts in the console, write them to the OutputFile and build our merge command
# For reference, here's the Merge-TureIdentities format:
# Merge-TrueIdentities.ps1 -PrimaryIdentityId 6 -SecondaryIdentityId 7

foreach ($Conflict in $ConflictsWith.GetEnumerator())
{
	Write-Host "`n" (Get-LRIdentityDisplay $Identities[$Conflict.Name]) ("(ID '" + $Conflict.Name + "')") "Conflicts with:"
    Write-Log -Message ("" + (Get-LRIdentityDisplay $Identities[$Conflict.Name]) + ("(ID '" + $Conflict.Name + "')") + " Conflicts with:") -Severity Information


# This gets a bit funky. I swapped the logic round so that it would merge into the lowest PrimaryIdentityID instead of the highest.
# It can be swapped back if needed by swapping the commented lines and removing the second 'if (WhatIf)' statement.
 if ($WhatIf) 
 {
#    $Command1 = (".\Merge-TrueIdentities_v2.ps1 -whatif -PrimaryIdentityId" + " " + $Conflict.Name + " ")
     $Command2 = ("-SecondaryIdentityId" + " " + $Conflict.Name)
    } else {
#    $Command1 = (".\Merge-TrueIdentities_v2.ps1 -PrimaryIdentityId" + " " + $Conflict.Name + " ")
     $Command2 = ("-SecondaryIdentityId" + " " + $Conflict.Name)
 }
 	
    foreach ($ConflictId in $Conflict.Value) 
	{
     Write-Host "" (Get-LRIdentityDisplay $Identities[$ConflictId]) ("(ID '" + $ConflictId + "')")
     Write-Log -Message ("" + (Get-LRIdentityDisplay $Identities[$ConflictId]) + ("(ID '" + $ConflictId + "')")) -Severity Information

 if ($WhatIf) 
 {    
#    $Command2 = ("-SecondaryIdentityId" + " " + $ConflictId)
     $Command1 = (".\Merge-TrueIdentities_v2.ps1 -whatif -PrimaryIdentityId" + " " + $ConflictId  + " ")
    } else {
#    $Command2 = ("-SecondaryIdentityId" + " " + $ConflictId)
     $Command1 = (".\Merge-TrueIdentities_v2.ps1 -PrimaryIdentityId" + " " + $ConflictId  + " ")
 }

     # Run the Merge-TrueIdentities.ps1 script to merge our identities
     $Command = $Command1 + $Command2
  
     Write-Host ("`r" + "`n" + "Running script to merge conflicts:" + "`r" + "`n" + $Command + "`n") -ForegroundColor Yellow
     Write-Log -Message (("Running script to merge conflicts:" + $Command)) -Severity Information
 
     Invoke-Expression $Command
     
        
     Write-Host ("`r" + "`n" + "Merge complete.") -ForegroundColor Green
     Write-Log -Message ("Merge complete.") -Severity Information
    }
 }