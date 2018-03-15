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
                $ADModulePath = Join-Path $PSScriptRoot -ChildPath 'RDSAD'
                Import-Module $ADModulePath\RDSAD.psm1

                switch ($ConnectionBrokerHighAvailabilty)
                {
                    'Yes'
                    {
                        New-ADStructure -RDSStructureName $RDSStructureName -ConnectionBrokerHighAvailabilty $true
                    }

                    'No'
                    {
                        New-ADStructure -RDSStructureName $RDSStructureName -ConnectionBrokerHighAvailabilty $false
                    }
                }
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