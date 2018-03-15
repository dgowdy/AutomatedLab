param
(
    [Parameter(Mandatory)]
    [String]
    $RDSStructureName,

    [Parameter(Mandatory)]
    [String]
    $ADServer,

    [Parameter(Mandatory)]
    [bool]
    $IsSessionBasedDesktop
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

if($IsSessionBasedDesktop)
{
    $targetpath = [String]::Concat("OU=RDSBD,OU=$RDSStructureName,",$dn)
}
else
{
    $targetpath = [String]::Concat("OU=RDSSH,OU=$RDSStructureName,",$dn)
}

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
$isInstalled = (Get-WindowsFeature -Name "RDS-RD-Server").InstallState

if ($isInstalled -eq "Installed") 
{
    Write-Output -InputObject "Feature RDS Session Host is already installed."
}
else 
{
    Write-Verbose -Message "Installing Feature for RDS Session Host"
    # TODO: Replace with Install-LabWindowsFeature
    $null = Install-WindowsFeature -Name "RDS-RD-Server" -IncludeAllSubFeature -IncludeManagementTools
}
