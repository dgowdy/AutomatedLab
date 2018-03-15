# TODO: Replace with Get-LabWindowsFeature
$isInstalled = (Get-WindowsFeature -Name "RDS-Web-Access").InstallState

if ($isInstalled -eq "Available") 
{
    Write-Warning -Message "Feature RDS Connection Broker is already installed."
}
else 
{
    Write-Verbose -Message "Installing Feature for "
    # TODO: Replace with Install-LabWindowsFeature
    Install-WindowsFeature -Name "RDS-Web-Access" -IncludeAllSubFeature -IncludeManagementTools
}