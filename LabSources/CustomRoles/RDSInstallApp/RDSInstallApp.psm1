
function Install-LabRDSApp
{
    [CmdletBinding()]
    param 
    (
        # The RDS App Name (only for Logging)
        [Parameter(Mandatory)]
        [String]
        $RDSAppName,
        
        # The path where the app is
        [Parameter()]
        [string]
        $RDSAppPath = (Join-Path -Path (Get-LabSourcesLocation) -ChildPath "SoftwarePackages"),

        # the name of the executable
        [Parameter(Mandatory)]
        [string]
        $RDSAppExecutableName,

        # install arguments of the app
        [Parameter(Mandatory)]
        [string]
        $RDSAppPathArguments,

        # install arguments of the app
        [Parameter()]
        [string]
        $RDSAppDownloadUri,

        # The name of one DC in the lab
        [Parameter(Mandatory)]
        [string[]]
        $RDSSessionHostServer
    )

    Write-ScreenInfo -Message "Check if $RDSAppExecutableName is in $RDSAppPath"
    
    $AppPath = (Join-Path -Path $RDSAppPath -ChildPath $RDSAppExecutableName)
    
    if (Test-Path -Path $AppPath)
    {
        foreach ($RDSSHS in $RDSSessionHostServer)
        {
            Write-ScreenInfo -Message "Install $RDSAppName on Session Host Server $RDSSessionHostServer"
            Install-LabSoftwarePackage -ComputerName $RDSSHS -Path $AppPath -CommandLine $RDSAppPathArguments   
        }        
    }
    else
    {
        Write-ScreenInfo -Message "The file $RDSAppExecutableName in path $RDSAppPath is not available. Check if you provided a Download Uri."
        if ($PSBoundParameters.ContainsKey('RDSAppDownloadUri'))
        {
            Write-ScreenInfo -Message "Downloading $RDSAppName from the following URL: $RDSAppDownloadUri"
            $AppObject = Get-LabInternetFile -Uri $RDSAppDownloadUri -Path $RDSAppPath

            foreach ($RDSSHS in $RDSSessionHostServer)
            {
                Write-ScreenInfo -Message "Install $RDSAppName on Session Host Server $RDSSessionHostServer"
                Install-LabSoftwarePackage -ComputerName $RDSSHS -Path $AppObject.FullName -CommandLine $RDSAppPathArguments   
            }
        }
        else
        {
            Write-Error "You do not provide a Download Uri. Please use the RDSAppDownloadUri parameter."
        }
    }    
}