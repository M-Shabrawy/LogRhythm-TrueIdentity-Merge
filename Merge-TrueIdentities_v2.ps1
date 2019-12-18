<#
.SYNOPSIS
	Merge two TrueIdentities in LR 7.4 
.DESCRIPTION
	Mergeg TrueIdentities in LR 7.4 
	Given a Primary and Secondary IdentityId, moves all Identifiers from the Secondard into the Primary
		Note: Only "Active" Identifiers on the Secondary will be used
	Retires the Secondary
	
.PARAMETER ApiUrl
	Optional. The Admin API URL (including trailing /)
	Default: "http://localhost:8505/lr-admin-api/"
	Alternatives: "https://PM_IP:8501/lr-admin-api/" (ensure you have a trusted cert relationship between this machine and the PM)
.PARAMETER ApiKey
	Required. The API Key, obtained from the Client Console "Third Party Applications" tab
	Example: "eyJhbGciO...DT7bPKrhg"
.PARAMETER PrimaryIdentityId
	Required integer
	The IdentityId of the TrueIdentity which will remain after merging
	Example: 
		https://WebConsole:8443/admin/identity/3208/identifiers
		-PrimaryIdentityId 3208
.PARAMETER SecondaryIdentityId
	Required integer
	The IdentityId of the TrueIdentity which will be retired after merging
	All Identifiers will be moved from the Secondary TrueIdentity to the Primary TrueIdentity
.PARAMETER LeadingWhitespace
	Optional Integer
	Adds the specified number of additional tabs before all output
	Used by Resolve-TrueIdentityConflicts for more readable output
.PARAMETER WhatIf
	Optional switch. Enabling "WhatIf" (Preview Mode) will check for errors but not make any changes to the TrueIdentities
	Recommended before the initial run 
.EXAMPLE
	.\Merge-TrueIdentities.ps1 -ApiKey "ey..." -PrimaryIdentityId 3208 -SecondaryIdentityId 3222
	Move all the Identifiers from Identity 3222 to Identity 3208
#>
	
# $ApiUrl = "http://localhost:8505/lr-admin-api/"
 
# Test Cases
# Primary not found
# Primary Retired
# Secondary not found
# Secordary with disabled identifiers
# Whatif
	
[CmdLetBinding()]
param( 
	[string] $ApiUrl = "http://localhost:8505/lr-admin-api/",
	[string] $ApiKey = "",
	[long] $PrimaryIdentityId,
	[long] $SecondaryIdentityId,
	[int] $LeadingWhitespace = 0,
	[switch] $WhatIf
)

$LeadingWhitespaceString = "`t" * $LeadingWhitespace	

# Common Components and Version Check
. .\TrueIdentity-Common.ps1

if ($WhatIf) {
	write-host ($LeadingWhitespaceString + "Running in Preview mode; no changes to TrueIdentities will be made") -ForegroundColor Yellow
}

$Primary = Get-LRIdentityById -ApiUrl $ApiUrl -ApiKey $ApiKey -IdentityId $PrimaryIdentityId
if (-not $Primary -or $Primary.recordStatus -eq "Retired")
{
	write-host ($LeadingWhitespaceString + "The Primary Identity (ID '$PrimaryIdentityId') was not found or the record status was Retired")
	Exit 1
}

$Secondary = Get-LRIdentityById -ApiUrl $ApiUrl -ApiKey $ApiKey -IdentityId $SecondaryIdentityId
if (-not $Secondary)
{
	write-host ($LeadingWhitespaceString + "The Secondary Identity (ID '$SecondaryIdentityId') was not found")
	Exit 1
}

$PrimaryDisplay = Get-LRIdentityDisplay -Identity $Primary
$SecondaryDisplay = Get-LRIdentityDisplay -Identity $Secondary

write-host ($LeadingWhitespaceString + "Primary Identity: $PrimaryDisplay")
write-host ($LeadingWhitespaceString + "Secondary Identity: $SecondaryDisplay")

write-host ($LeadingWhitespaceString + "Moving Identifiers:")

$Identifiers = $Secondary.identifiers 
foreach ($Identifier in $Identifiers)
{
	if ($Identifier.recordStatus -eq "Retired")
	{
		write-host ($LeadingWhitespaceString + "`tIdentifier '$($Identifier.value)' type '$($Identifier.identifierType)' is disabled and will not be moved")
		continue
	}
	
	# Check to see if this Identifier already exists in the Primary Identity
	$PrimaryHasIdentifier = (@($Primary.identifiers | ? { $_.value -eq $Identifier.value -and $_.identifierType -eq $Identifier.identifierType }).Count -gt 0)
	if ($PrimaryHasIdentifier)
	{
		write-host ($LeadingWhitespaceString + "`tIdentifier '$($Identifier.value)' type '$($Identifier.identifierType)' already exists in the Primrary Identity")
		continue
	}
	
	if ($WhatIf) 
	{
		$MoveStatus = $True
	} else {
		$MoveStatus = Add-LRIdentifierToIdentity -ApiUrl $ApiUrl -ApiKey $ApiKey -IdentityId $PrimaryIdentityId -IdentifierType $Identifier.identifierType -IdentifierValue $Identifier.value
	}
	
	if ($MoveStatus -eq $True)
	{
		write-host ($LeadingWhitespaceString + "`tSuccessfully moved Identifier '$($Identifier.value)' type '$($Identifier.identifierType)'")
	} else {
		write-host ($LeadingWhitespaceString + "`tFailed to move Identifier '$($Identifier.value)' type '$($Identifier.identifierType)'")
	}
}

if ($WhatIf) {
	.\Retire-TrueIdentities -ApiUrl $ApiUrl -ApiKey $ApiKey -ByIdentityId $SecondaryIdentityId -WhatIf -LeadingWhitespace $LeadingWhitespace | Out-File -filepath ($OutputFile) -Append -NoClobber
} else {
	.\Retire-TrueIdentities -ApiUrl $ApiUrl -ApiKey $ApiKey -ByIdentityId $SecondaryIdentityId -LeadingWhitespace $LeadingWhitespace | Out-File -filepath ($OutputFile) -Append -NoClobber
}

# Check record status
	
