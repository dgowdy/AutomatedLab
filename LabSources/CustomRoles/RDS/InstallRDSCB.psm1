function Install-RSATADTools
{
    param
    (
        [Parameter(Mandatory)]
        [String]
        $ComputerName
    )

    $isInstalled_rsat = (Get-LabWindowsFeature -FeatureName "RSAT-AD-PowerShell" -ComputerName $ComputerName).State

    if ($isInstalled_rsat -eq "Installed") 
    {
        Write-ScreenInfo -Message 'RSAT-AD-PowerShell is already installed.'
    }
    else 
    {
        Write-Verbose -Message "Installing Feature RSAT-AD-PowerShell"
        Install-LabWindowsFeature -FeatureName "RSAT-AD-PowerShell" -IncludeAllSubFeature -IncludeManagementTools -ComputerName $ComputerName -ProgressIndicator
    }
}