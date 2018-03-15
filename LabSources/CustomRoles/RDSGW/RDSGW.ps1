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
    Write-Verbose -Message "Installing Feature PowerShell Tools for ActiveDirectory"
    # TODO: Replace with Install-LabWindowsFeature
    $null = Install-WindowsFeature -Name "RSAT-AD-PowerShell" -IncludeAllSubFeature -IncludeManagementTools
}

$dn = (Get-ADDomain).DistinguishedName
$computerName = $env:COMPUTERNAME
$pc_path = (Get-ADComputer -Identity $computerName).DistinguishedName
$targetpath = [String]::Concat("OU=RDSGW,OU=$RDSStructureName,",$dn)

if($pc_path.Contains("OU=$RDSStructureName"))
{
    Write-Output "Computer $computerName is already in the right OU ($targetpath)."
}
else
{
    Write-Output "Moving Computer $computername to the path $targetpath."
    Move-ADObject -Identity $pc_path -TargetPath $targetpath -Server $ADServer
}

# TODO: Replace with Get-LabWindowsFeature
$isInstalled = (Get-WindowsFeature -Name "RDS-Gateway").InstallState

if ($isInstalled -eq "Installed") 
{
    Write-Output -InputObject "Feature RDS Gateway is already installed."
}
else 
{
    Write-Verbose -Message "Installing Feature for RDS Gateway"
    # TODO: Replace with Install-LabWindowsFeature
    $null = Install-WindowsFeature -Name "RDS-Gateway" -IncludeAllSubFeature -IncludeManagementTools
}
