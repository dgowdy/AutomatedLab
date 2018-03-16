param
(
    [Parameter(ParameterSetName = 'AdvancedRDSDeployment')]
    [String]
    [ValidateSet('Yes', 'No')]
    $IsAdvancedRDSDeployment,
    
    [Parameter(ParameterSetName = 'AdvancedRDSDeployment')]
    [String]
    [ValidateSet('Yes', 'No')]
    $ConnectionBrokerHighAvailabilty,

    [Parameter(ParameterSetName = 'AdvancedRDSDeployment')]
    [String]
    $RDSStructureName,

    [Parameter(ParameterSetName = 'AdvancedRDSDeployment')]
    [String]
    $ADServer,

    [Parameter(ParameterSetName = 'AdvancedRDSDeployment')]
    [String]
    [ValidateSet('Yes', 'No')]
    $IsSessionBasedDesktop,

    [Parameter(ParameterSetName = 'AdvancedRDSDeployment')]
    [String[]]
    [ValidateSet('RDSAD', 'RDSCB', 'RDSGW', 'RDSLIC', 'RDSSH', 'RDSWA')]
    $Roles
)

switch ($IsAdvancedRDSDeployment)
{
    'Yes'
    {
        switch ($Roles)
        {
            'RDSAD'
            {                
                $script = Get-Command -Name $PSScriptRoot\InstallRDSAD.ps1

		$param = Sync-Parameter -Command $script -Parameters $PSBoundParameters

		& $PSScriptRoot\InstallRDSAD.ps1 @param
            }

            'RDSCB'
            {

            }

            'RDSGW'
            {

            }

            'RDSLIC'
            {

            }

            'RDSSH'
            {

            }

            'RDSWA'
            {

            }
        }
    }

    'No'
    {

    }
}