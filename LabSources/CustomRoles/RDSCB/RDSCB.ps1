param
(
    [Parameter(Mandatory)]
    [String]
    $RDSStructureName,

    [Parameter(Mandatory)]
    [String]
    $ADServer
)

$isInstalled_rsat = (Get-WindowsFeature -Name "RSAT-AD-PowerShell").InstallState

if ($isInstalled_rsat -eq "Installed") 
{
    Write-Output -InputObject "Feature RSAT PowerShell is already installed."
}
else 
{
    Write-Verbose -Message "Installing Feature for "
    # TODO: Replace with Install-LabWindowsFeature
    $null = Install-WindowsFeature -Name "RSAT-AD-PowerShell" -IncludeAllSubFeature -IncludeManagementTools
}

$null = Install-WindowsFeature -Name "RSAT-AD-PowerShell"
$dn = (Get-ADDomain).DistinguishedName
$computerName = $env:COMPUTERNAME
$pc_path = (Get-ADComputer -Identity $computerName).DistinguishedName
$targetpath = [String]::Concat("OU=RDSCB,OU=$RDSStructureName,",$dn)

if($pc_path.Contains($RDSStructureName))
{
    Write-Output "Computer $computerName is already in the right OU ($targetpath)."
}
else
{
    Write-Output "Moving Computer $computername to the path $targetpath."
    Move-ADObject -Identity $pc_path -TargetPath $targetpath -Server $ADServer
}

# TODO: Replace with Get-LabWindowsFeature
$isInstalled = (Get-WindowsFeature -Name "RDS-Connection-Broker").InstallState

if ($isInstalled -eq "Installed") 
{
    Write-Output -InputObject "Feature RDS Connection Broker is already installed."
}
else 
{
    Write-Verbose -Message "Installing Feature for RDS Connection Broker"
    # TODO: Replace with Install-LabWindowsFeature
    $null = Install-WindowsFeature -Name "RDS-Connection-Broker" -IncludeAllSubFeature -IncludeManagementTools
}
