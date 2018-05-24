function Publish-LabRDSApp
{
    [CmdletBinding()]
    param 
    (
        # The RDS App Name (only for Logging)
        [Parameter(Mandatory)]
        [ValidateScript(
            {               
                if ($_ -match "[$([Regex]::Escape('/\[:;|=,+*?<>') + '\]' + '\"')]")
                {
                    return $false
                }
                else
                {
                    return $true
                }
            }
        )]
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

        [Parameter(Mandatory)]
        [string[]]
        $RDSSessionHostServer
    )

    #region Install Software

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
            $AppObject = Get-LabInternetFile -Uri $RDSAppDownloadUri -Path $RDSAppPath -PassThru

            foreach ($RDSSHS in $RDSSessionHostServer)
            {                
                Install-LabSoftwarePackage -ComputerName $RDSSHS -Path $AppObject.FullName -CommandLine $RDSAppPathArguments       
            }
        }
        else
        {
            Write-Error "You do not provide a Download Uri. Please use the RDSAppDownloadUri parameter."
        }
    }
    #endregion Install Software
    
    #region create AD Group and add it to DL_RDSUsers

    #endregion create AD Group and add it to DL_RDSUsers
}